class sha256_scoreboard extends uvm_scoreboard;
    `uvm_component_utils(sha256_scoreboard)

    uvm_analysis_imp #(sha256_transaction, sha256_scoreboard) analysis_export;

    tb_reference_model reference_model;
    bit [31:0] input_words[$];
    longint unsigned message_bit_length;
    bit [255:0] collected_digest;
    bit result_seen;
    int error_count;
    int unsigned word_count;

    function new(string name, uvm_component parent);
        super.new(name, parent);
        analysis_export = new("analysis_export", this);
        reference_model = new();
        message_bit_length = 0;
        collected_digest = '0;
        result_seen = 0;
        error_count = 0;
        word_count = 0;
    endfunction

    function void write(sha256_transaction tr);
        bit start_accepted;
        bit input_word_accepted;
        bit [255:0] expected_digest;

        if (!tr.i_rst_n) begin
            input_words.delete();
            message_bit_length = 0;
            collected_digest = '0;
            word_count = 0;
            result_seen = 0;
            return;
        end

        if (tr.o_error && !tr.cov_expect_error) begin
            `uvm_error("SCO", "DUT asserted o_error during the valid test")
            error_count++;
        end

        start_accepted = tr.i_start && tr.o_ready_pre && !tr.o_busy_pre;
        input_word_accepted = tr.i_enable && tr.o_ready_pre
                            && !(start_accepted && (tr.i_bit_length == 0));

        if (start_accepted) begin
            input_words.delete();
            message_bit_length = tr.i_bit_length;
            collected_digest = '0;
            word_count = 0;
            result_seen = 0;
        end

        if (input_word_accepted)
            input_words.push_back(tr.i_data);

        if (tr.o_valid) begin
            if (word_count >= 8) begin
                `uvm_error("SCO", "Received more than eight digest words")
                error_count++;
            end else begin
                collected_digest[255 - word_count*32 -: 32] = tr.o_data;
                word_count++;
            end
        end

        if (tr.o_done) begin
            if (result_seen) begin
                `uvm_error("SCO", "DUT asserted o_done more than once")
                error_count++;
            end
            result_seen = 1;

            if (tr.o_valid) begin
                `uvm_error("SCO", "o_done must assert after the final valid digest word")
                error_count++;
            end
            if (word_count != 8) begin
                `uvm_error("SCO", $sformatf("Expected 8 digest words, received %0d", word_count))
                error_count++;
            end

            expected_digest = reference_model.compute(input_words, message_bit_length);
            if (collected_digest !== expected_digest) begin
                `uvm_error("SCO", $sformatf(
                    "SHA-256 mismatch: expected=%064h actual=%064h",
                    expected_digest, collected_digest
                ))
                error_count++;
            end else begin
                `uvm_info("SCO", $sformatf(
                    "SHA-256 PASS (%0d input bits): %064h",
                    message_bit_length, collected_digest
                ), UVM_LOW)
            end
        end
    endfunction

    function void check_phase(uvm_phase phase);
        super.check_phase(phase);
        if (!result_seen)
            `uvm_error("SCO", "No SHA-256 result was observed")
        if (error_count != 0)
            `uvm_error("SCO", $sformatf("Scoreboard found %0d error(s)", error_count))
    endfunction
endclass
