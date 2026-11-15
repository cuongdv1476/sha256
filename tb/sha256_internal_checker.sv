module sha256_internal_checker (
    input logic         clk,
    input logic         rst_n,
    input logic         input_start,
    input logic         input_enable,
    input logic [31:0]  input_data,
    input logic         schedule_start,
    input logic [511:0] schedule_block,
    input logic         schedule_valid,
    input logic [31:0]  schedule_data,
    input logic         schedule_done,
    input logic         compression_busy,
    input logic         compression_done,
    input logic [5:0]   compression_round,
    input logic [31:0]  compression_data,
    input logic         block_done,
    input logic         block_ack,
    input logic [511:0] block_data,
    input logic         top_busy,
    input logic         top_ready,
    input logic         top_done,
    input logic         top_valid,
    input logic         top_error,
    input logic [255:0] top_digest
);
    logic [31:0] expected_w [0:63];
    logic [511:0] held_block;
    int unsigned schedule_index;
    int unsigned total_schedule_words;
    int unsigned total_compression_rounds;
    int unsigned schedule_jobs;
    int unsigned compression_jobs;
    int unsigned expected_round_index;
    bit schedule_active;
    bit compression_active;
    bit held_block_valid;

    property p_sync_reset_returns_idle;
        @(posedge clk) !rst_n |=> (!top_busy && top_ready && !top_done && !top_valid);
    endproperty
    assert property (p_sync_reset_returns_idle)
        else $fatal(1, "Reset did not return sha_top to IDLE");

    property p_done_is_one_cycle;
        @(posedge clk) disable iff (!rst_n) top_done |=> !top_done;
    endproperty
    assert property (p_done_is_one_cycle)
        else $fatal(1, "sha_top o_done is wider than one cycle");

    property p_valid_matches_done;
        @(posedge clk) disable iff (!rst_n) top_valid == top_done;
    endproperty
    assert property (p_valid_matches_done)
        else $fatal(1, "sha_top o_valid and o_done differ");

    property p_no_error;
        @(posedge clk) disable iff (!rst_n) !top_error;
    endproperty
    assert property (p_no_error)
        else $fatal(1, "sha_top asserted o_error");

    property p_digest_stable_when_valid;
        @(posedge clk) disable iff (!rst_n) top_valid |-> $stable(top_digest);
    endproperty
    assert property (p_digest_stable_when_valid)
        else $fatal(1, "Digest changed while o_valid was asserted");

    property p_start_only_when_idle_ready;
        @(posedge clk) disable iff (!rst_n)
            input_start |-> (top_ready && !top_busy);
    endproperty
    assert property (p_start_only_when_idle_ready)
        else $fatal(1, "i_start asserted while sha_top was not idle and ready");

    property p_start_is_one_cycle;
        @(posedge clk) disable iff (!rst_n) input_start |=> !input_start;
    endproperty
    assert property (p_start_is_one_cycle)
        else $fatal(1, "i_start was held for more than one cycle");

    property p_input_held_during_backpressure;
        @(posedge clk) disable iff (!rst_n)
            (input_enable && !top_ready) |=> (input_enable && $stable(input_data));
    endproperty
    assert property (p_input_held_during_backpressure)
        else $fatal(1, "Input valid/data changed before ready accepted the word");

    function automatic logic [31:0] rotr(input logic [31:0] x, input int n);
        return (x >> n) | (x << (32-n));
    endfunction

    task automatic make_schedule(input logic [511:0] block_value);
        for (int t = 0; t < 16; t++)
            expected_w[t] = block_value[511-t*32 -: 32];
        for (int t = 16; t < 64; t++) begin
            logic [31:0] x, y;
            x = expected_w[t-15];
            y = expected_w[t-2];
            expected_w[t] = expected_w[t-16]
                          + (rotr(x,7) ^ rotr(x,18) ^ (x >> 3))
                          + expected_w[t-7]
                          + (rotr(y,17) ^ rotr(y,19) ^ (y >> 10));
        end
    endtask

    always @(posedge clk) begin
        if (!rst_n) begin
            schedule_index          <= 0;
            total_schedule_words    <= 0;
            total_compression_rounds<= 0;
            schedule_jobs           <= 0;
            compression_jobs       <= 0;
            schedule_active         <= 0;
            compression_active     <= 0;
            expected_round_index    <= 0;
            held_block_valid        <= 0;
        end
        else begin
            if (schedule_start) begin
                make_schedule(schedule_block);
                schedule_index <= 0;
                schedule_active <= 1;
                schedule_jobs <= schedule_jobs + 1;
            end

            if (schedule_valid) begin
                if (!schedule_active || schedule_index >= 64)
                    $fatal(1, "Schedule valid outside active 64-word transaction");
                if (schedule_data !== expected_w[schedule_index])
                    $fatal(1, "W[%0d] mismatch: expected=%08h actual=%08h",
                           schedule_index, expected_w[schedule_index], schedule_data);
                schedule_index <= schedule_index + 1;
                total_schedule_words <= total_schedule_words + 1;
            end

            if (schedule_done) begin
                if (!schedule_active || schedule_index != 64)
                    $fatal(1, "Schedule completed after %0d/64 words", schedule_index);
                schedule_active <= 0;
            end

            if (compression_busy) begin
                if (!schedule_active && !schedule_done)
                    $fatal(1, "Compression active without a current message schedule");
                if (expected_round_index >= 64)
                    $fatal(1, "Compression executed more than 64 rounds");
                if (compression_round !== expected_round_index[5:0])
                    $fatal(1, "Compression round out of order: observed=%0d expected=%0d",
                           compression_round, expected_round_index);
                if (compression_data !== expected_w[compression_round])
                    $fatal(1, "Compression round %0d used W=%08h, expected %08h",
                           compression_round, compression_data, expected_w[compression_round]);
                expected_round_index <= expected_round_index + 1;
                total_compression_rounds <= total_compression_rounds + 1;
                compression_active <= 1;
            end

            if (compression_done) begin
                if (!compression_active || expected_round_index != 64)
                    $fatal(1, "Compression ended after %0d/64 ordered rounds",
                           expected_round_index);
                compression_jobs <= compression_jobs + 1;
                compression_active <= 0;
                expected_round_index <= 0;
            end

            if (held_block_valid && block_done && (block_data !== held_block))
                $fatal(1, "Block buffer changed data while DONE was not acknowledged");
            held_block_valid <= block_done && !block_ack;
            if (block_done && !block_ack)
                held_block <= block_data;
        end
    end

    final begin
        if (schedule_active || compression_active)
            $fatal(1, "Simulation ended with internal datapath operation still active");
        if (total_schedule_words != total_compression_rounds)
            $fatal(1, "Schedule/compression count mismatch: schedule_words=%0d rounds=%0d",
                   total_schedule_words, total_compression_rounds);
        if (schedule_jobs != compression_jobs)
            $fatal(1, "Schedule/compression job mismatch: schedule=%0d compression=%0d",
                   schedule_jobs, compression_jobs);
        $display("INTERNAL CHECKER PASS: jobs=%0d schedule_words=%0d compression_rounds=%0d",
                 schedule_jobs, total_schedule_words, total_compression_rounds);
    end
endmodule
