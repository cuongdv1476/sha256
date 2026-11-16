class sha256_multiblock_sequence extends sha256_base_sequence;
    `uvm_object_utils(sha256_multiblock_sequence)

    function new(string name = "sha256_multiblock_sequence");
        super.new(name);
    endfunction

    task body();
        longint unsigned message_length;
        string case_id;

        setup_vif();
        reset_dut();

        run_generated_case("MB_01_100_BITS", 64'd100, PATTERN_INCREASING);
        run_generated_case("MB_02_200_BITS", 64'd200, PATTERN_DECREASING);
        run_generated_case("MB_03_300_BITS", 64'd300, PATTERN_AA);
        run_generated_case("MB_04_400_BITS", 64'd400, PATTERN_55);

        // For N padded blocks, L = 512*N - 65 is the largest message length
        // that still fits in exactly N padded blocks. This covers every count
        // from 1 through the block buffer's configured 64-block capacity.
        for (int unsigned padded_blocks = 1;
             padded_blocks <= 64;
             padded_blocks++) begin
            message_length = (padded_blocks * 64'd512) - 64'd65;
            case_id = $sformatf("MB_PADDED_BLOCKS_%02d_LEN_%0d",
                                padded_blocks, message_length);
            run_generated_case(case_id, message_length, PATTERN_BLOCK_ID);
        end
    endtask
endclass
