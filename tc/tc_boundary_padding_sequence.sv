class sha256_boundary_padding_sequence extends sha256_base_sequence;
    `uvm_object_utils(sha256_boundary_padding_sequence)

    function new(string name = "sha256_boundary_padding_sequence");
        super.new(name);
    endfunction

    task body();
        string case_id;
        setup_vif();
        reset_dut();

        run_generated_case("BOUNDARY_01_EMPTY", 64'd0, PATTERN_ZERO);
        run_generated_case("BOUNDARY_02_1_BIT", 64'd1, PATTERN_AA);
        run_generated_case("BOUNDARY_03_31_BITS", 64'd31, PATTERN_WALKING_1);
        run_generated_case("BOUNDARY_04_32_BITS", 64'd32, PATTERN_WALKING_0);
        run_generated_case("PAD_01_447_BITS", 64'd447, PATTERN_INCREASING);
        run_generated_case("PAD_02_448_BITS", 64'd448, PATTERN_DECREASING);
        run_generated_case("PAD_03_449_BITS", 64'd449, PATTERN_AA);
        run_generated_case("PAD_04_511_BITS", 64'd511, PATTERN_55);
        run_generated_case("PAD_05_512_BITS", 64'd512, PATTERN_BLOCK_ID);
        run_generated_case("BOUNDARY_10_513_BITS", 64'd513, PATTERN_BLOCK_ID);
        run_generated_case("PAD_06_960_BITS", 64'd960, PATTERN_INCREASING);
        run_generated_case("BOUNDARY_05_63_BITS", 64'd63, PATTERN_AA);
        run_generated_case("BOUNDARY_06_64_BITS", 64'd64, PATTERN_55);
        run_generated_case("BOUNDARY_07_2_BITS", 64'd2, PATTERN_WALKING_1);
        run_generated_case("BOUNDARY_08_7_BITS", 64'd7, PATTERN_WALKING_1);
        run_generated_case("BOUNDARY_09_8_BITS", 64'd8, PATTERN_WALKING_0);
        run_generated_case("BOUNDARY_11_9_BITS", 64'd9, PATTERN_AA);
        run_generated_case("BOUNDARY_12_10_BITS", 64'd10, PATTERN_55);
        run_generated_case("BOUNDARY_13_33_BITS", 64'd33, PATTERN_WALKING_1);
        run_generated_case("BOUNDARY_14_34_BITS", 64'd34, PATTERN_WALKING_0);
        run_generated_case("PAD_07_895_BITS", 64'd895, PATTERN_INCREASING);
        run_generated_case("PAD_08_896_BITS", 64'd896, PATTERN_DECREASING);
        run_generated_case("PAD_09_897_BITS", 64'd897, PATTERN_BLOCK_ID);
        run_generated_case("PAD_10_959_BITS", 64'd959, PATTERN_INCREASING);
        run_generated_case("PAD_11_1023_BITS", 64'd1023, PATTERN_DECREASING);
        run_generated_case("PAD_12_1024_BITS", 64'd1024, PATTERN_AA);
        run_generated_case("PAD_13_1025_BITS", 64'd1025, PATTERN_55);

        // Fill every feasible alignment x padded-block-count combination.
        for (int unsigned residue = 0; residue < 8; residue++) begin
            case_id = $sformatf("CROSS_1BLOCK_ALIGN_%0d", residue);
            run_generated_case(case_id, 64'(100 + residue), PATTERN_BLOCK_ID);
            case_id = $sformatf("CROSS_2BLOCK_ALIGN_%0d", residue);
            run_generated_case(case_id, 64'(600 + residue), PATTERN_BLOCK_ID);
            case_id = $sformatf("CROSS_3BLOCK_ALIGN_%0d", residue);
            run_generated_case(case_id, 64'(1100 + residue), PATTERN_BLOCK_ID);
            case_id = $sformatf("CROSS_4PLUS_BLOCK_ALIGN_%0d", residue);
            run_generated_case(case_id, 64'(1700 + residue), PATTERN_BLOCK_ID);
        end

        // Cover every length-remainder class at all eight bit alignments.
        for (int unsigned residue = 1; residue <= 8; residue++) begin
            case_id = $sformatf("PAD_REMAINDER_1_31_ALIGN_%0d", residue % 8);
            run_generated_case(case_id, 64'(residue), PATTERN_INCREASING);
            case_id = $sformatf("PAD_REMAINDER_32_447_ALIGN_%0d", residue % 8);
            run_generated_case(case_id, 64'(32 + residue), PATTERN_INCREASING);
            case_id = $sformatf("PAD_REMAINDER_448_510_ALIGN_%0d", residue % 8);
            run_generated_case(case_id, 64'(448 + residue), PATTERN_INCREASING);
        end
    endtask
endclass
