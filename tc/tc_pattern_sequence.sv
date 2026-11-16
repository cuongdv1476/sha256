class sha256_pattern_sequence extends sha256_base_sequence;
    `uvm_object_utils(sha256_pattern_sequence)

    function new(string name = "sha256_pattern_sequence");
        super.new(name);
    endfunction

    task body();
        setup_vif();
        reset_dut();

        run_generated_case("DATA_01_ALL_ZERO", 64'd512, PATTERN_ZERO);
        run_generated_case("DATA_02_ALL_ONE", 64'd512, PATTERN_ONE);
        run_generated_case("DATA_03_AAAAAAAA", 64'd512, PATTERN_AA);
        run_generated_case("DATA_04_55555555", 64'd512, PATTERN_55);
        run_generated_case("DATA_05_WALKING_1", 64'd512, PATTERN_WALKING_1);
        run_generated_case("DATA_06_WALKING_0", 64'd512, PATTERN_WALKING_0);
        run_generated_case("DATA_07_INCREASING_WORDS", 64'd1024,
                           PATTERN_INCREASING);
        run_generated_case("DATA_08_DECREASING_WORDS", 64'd1024,
                           PATTERN_DECREASING);
        run_generated_case("DATA_09_REPEAT_BLOCK_PATTERN", 64'd1024,
                           PATTERN_SAME_BLOCK);
        run_generated_case("DATA_10_DIFFERENT_BLOCK_PATTERNS", 64'd2048,
                           PATTERN_BLOCK_ID);
        run_generated_case("DATA_11_RANDOM_512_BITS", 64'd512,
                        PATTERN_RANDOM);

        run_generated_case("DATA_12_RANDOM_MULTI_BLOCK", 64'd4096,
                        PATTERN_RANDOM);

        // Exercise each data family at medium and long message sizes so the
        // pattern x size cross does not depend on random selection.
        run_generated_case("DATA_13_ZERO_MEDIUM", 64'd1024, PATTERN_ZERO);
        run_generated_case("DATA_14_ALTERNATING_MEDIUM", 64'd1024, PATTERN_AA);
        run_generated_case("DATA_15_WALKING_MEDIUM", 64'd1024, PATTERN_WALKING_1);
        run_generated_case("DATA_16_RANDOM_MEDIUM", 64'd1024, PATTERN_RANDOM);
        run_generated_case("DATA_17_ZERO_LONG", 64'd4096, PATTERN_ZERO);
        run_generated_case("DATA_18_ALTERNATING_LONG", 64'd4096, PATTERN_AA);
        run_generated_case("DATA_19_WALKING_LONG", 64'd4096, PATTERN_WALKING_0);
        run_generated_case("DATA_20_RANDOM_LONG", 64'd4096, PATTERN_RANDOM);
    endtask
endclass
