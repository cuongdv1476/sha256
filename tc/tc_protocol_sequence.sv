class sha256_protocol_sequence extends sha256_base_sequence;
    `uvm_object_utils(sha256_protocol_sequence)

    function new(string name = "sha256_protocol_sequence");
        super.new(name);
    endfunction

    task body();
        setup_vif();
        reset_dut();
        // Input protocol
        run_generated_case("BUF_03_SINGLE_WORD_GAPS", 64'd512,
                        PATTERN_INCREASING, 1'b1);

        run_generated_case("BUF_04_MULTI_BLOCK_GAPS", 64'd4096,
                        PATTERN_BLOCK_ID, 1'b1);

        // Output behavior
        run_generated_case("PROTO_02_BACK_TO_BACK_MESSAGES", 64'd512,
                        PATTERN_INCREASING);

        run_generated_case("PROTO_03_LONG_THEN_SHORT_MESSAGE", 64'd1024,
                        PATTERN_BLOCK_ID);
    endtask
endclass
