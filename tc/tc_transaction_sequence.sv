class sha256_transaction_sequence extends sha256_base_sequence;
    `uvm_object_utils(sha256_transaction_sequence)

    function new(string name = "sha256_transaction_sequence");
        super.new(name);
    endfunction

    task body();
        bit [31:0] abc_words[$];

        setup_vif();
        reset_dut();

        // Message: "abc"
        abc_words.push_back(32'h6162_6300);

        // Repeat the same message.
        run_message("TRANS_01_REPEAT_ABC_A", 64'd24, abc_words);
        run_message("TRANS_02_REPEAT_ABC_B", 64'd24, abc_words);

        // Long message followed by short message.
        run_generated_case("TRANS_03_LONG_THEN_SHORT",
                           64'd2048, PATTERN_INCREASING);

        run_generated_case("TRANS_04_SHORT_AFTER_LONG",
                           64'd32, PATTERN_WALKING_1);

        // Short message followed by another short message.
        run_generated_case("TRANS_05_SHORT_AFTER_SHORT",
                           64'd32, PATTERN_WALKING_0);

        // Short message followed by long message.
        run_generated_case("TRANS_06_LONG_AFTER_SHORT",
                           64'd1024, PATTERN_DECREASING);

        // Empty message after a long message.
        run_generated_case("TRANS_07_EMPTY_AFTER_LONG",
                           64'd0, PATTERN_ZERO);
    endtask

endclass