module tb_assertions #(
    parameter int DATA_WIDTH = 32,
    parameter longint unsigned MAX_MESSAGE_BITS = 4096,
    parameter int unsigned MAX_LATENCY_CYCLES = 2048
)(
    input logic                   i_clk,
    input logic                   i_rst_n,
    input logic                   i_start,
    input logic                   i_enable,
    input logic [63:0]            i_bit_length,
    input logic [DATA_WIDTH-1:0]  i_data,
    input logic                   o_busy,
    input logic                   o_ready,
    input logic                   o_done,
    input logic                   o_valid,
    input logic                   o_error,
    input logic [DATA_WIDTH-1:0]  o_data
);
    localparam int DIGEST_WORDS = 256 / DATA_WIDTH;
    localparam int WORD_COUNT_WIDTH = $clog2(DIGEST_WORDS + 1);

    logic transaction_active;
    logic latency_watch;
    longint unsigned expected_input_words;
    longint unsigned accepted_input_words;
    int unsigned latency_count;
    logic [WORD_COUNT_WIDTH-1:0] output_word_count;

    wire start_accepted = i_start && o_ready && !o_busy;

    default clocking cb @(posedge i_clk); endclocking

    // A start is accepted only in idle: ready and not busy.
    a_start_protocol: assert property (
        disable iff (!i_rst_n)
        i_start && (o_busy || !o_ready) |=> o_error
    ) else $error("invalid start was not reported by o_error");

    // Idle must be ready. Ready and busy may both be high while accepting input.
    a_idle_ready: assert property (
        disable iff (!i_rst_n) !o_busy |-> o_ready
    ) else $error("DUT is idle but not ready");

    a_valid_has_result: assert property (
        disable iff (!i_rst_n)
        o_valid |-> (transaction_active &&
                     (accepted_input_words == expected_input_words) &&
                     (output_word_count < DIGEST_WORDS) &&
                     o_busy && !o_ready && !$isunknown(o_data))
    ) else $error("valid asserted without an active result or with invalid data");

    // The serialized stream contains exactly DIGEST_WORDS words. done follows
    // the final valid word and is a separate one-cycle completion pulse.
    a_done_after_digest_stream: assert property (
        disable iff (!i_rst_n)
        o_done |-> (transaction_active && !o_valid &&
                    (output_word_count == DIGEST_WORDS) && $past(o_valid))
    ) else $error("done timing or serialized digest word count is incorrect");

    a_done_is_one_cycle: assert property (
        disable iff (!i_rst_n) o_done |=> !o_done
    ) else $error("o_done must be a one-cycle pulse");

    // Invalid starts must also be reported by the DUT on the next cycle.

    // The source must hold a valid input word and its length until accepted.
    a_input_stable_during_stall: assert property (
        disable iff (!i_rst_n)
        i_enable && !o_ready |=> (i_enable && $stable({i_data, i_bit_length}))
    ) else $error("input data changed while stalled");

    // Latency is measured from acceptance of the final input word (or an empty
    // message start) to the first serialized digest word. Bounds are configurable.
    a_latency_bound: assert property (
        disable iff (!i_rst_n)
        latency_watch |-> (latency_count < MAX_LATENCY_CYCLES)
    ) else $error("digest result exceeded MAX_LATENCY_CYCLES");

    a_message_length_bound: assert property (
        disable iff (!i_rst_n)
        start_accepted |-> (i_bit_length <= MAX_MESSAGE_BITS)
    ) else $error("message length exceeds the assertion module's configured bound");

    // Reset is synchronous in this RTL. After a reset edge all visible outputs
    // must be known and return to their idle values.
    a_reset_outputs: assert property (
        !i_rst_n |=> (!o_busy && o_ready && !o_done && !o_valid &&
                      !o_error && (o_data == '0))
    ) else $error("reset did not return the DUT outputs to known idle values");

    always_ff @(posedge i_clk) begin
        if (!i_rst_n) begin
            transaction_active   <= 1'b0;
            latency_watch        <= 1'b0;
            expected_input_words <= 0;
            accepted_input_words <= 0;
            latency_count        <= 0;
            output_word_count    <= '0;
        end else begin
            if (start_accepted) begin
                transaction_active <= 1'b1;
                expected_input_words <= (i_bit_length + 64'd31) / 64'd32;
                accepted_input_words <= (i_enable && (i_bit_length != 0)) ? 1 : 0;
                latency_watch <= (i_bit_length == 0) ||
                    (i_enable && (((i_bit_length + 64'd31) / 64'd32) == 1));
                latency_count <= 0;
            end else if (transaction_active && i_enable && o_ready &&
                         (accepted_input_words < expected_input_words)) begin
                accepted_input_words <= accepted_input_words + 1;
                if (accepted_input_words + 1 == expected_input_words) begin
                    latency_watch <= 1'b1;
                    latency_count <= 0;
                end
            end

            if (latency_watch && !o_valid)
                latency_count <= latency_count + 1;
            if (o_valid)
                latency_watch <= 1'b0;
            if (o_done)
                transaction_active <= 1'b0;

            if (o_valid)
                output_word_count <= output_word_count + 1'b1;
            if (o_done)
                output_word_count <= '0;
        end
    end
endmodule
