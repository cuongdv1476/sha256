class sha256_random_sequence extends sha256_base_sequence;
    `uvm_object_utils(sha256_random_sequence)

    localparam int unsigned MAX_RANDOM_COUNT = 100000;
    localparam int unsigned MAX_RANDOM_LENGTH = 2**64-1;

    function new(string name = "sha256_random_sequence");
        super.new(name);
    endfunction

    // Generate random message length.
    // 70%: Uniform random length from 0 to 4096 bits.
    // 30%: Select important padding/block boundaries.
    function automatic int unsigned generate_random_length();
        int unsigned boundary_index;

        if ($urandom_range(0, 9) < 7) begin
            return $urandom_range(0, MAX_RANDOM_LENGTH);
        end
        else begin
            boundary_index = $urandom_range(0, 11);

            case (boundary_index)
                0:  return 447;
                1:  return 448;
                2:  return 449;
                3:  return 511;
                4:  return 512;
                5:  return 513;
                6:  return 959;
                7:  return 960;
                8:  return 961;
                9:  return 1023;
                10: return 1024;
                11: return 1025;
                default: return 512;
            endcase
        end
    endfunction

    // Generate a random data pattern.
    function automatic int unsigned generate_random_pattern();
        case ($urandom_range(0, 7))
            0: return PATTERN_RANDOM;
            1: return PATTERN_BLOCK_ID;
            2: return PATTERN_ZERO;
            3: return PATTERN_ONE;
            4: return PATTERN_AA;
            5: return PATTERN_55;
            6: return PATTERN_INCREASING;
            7: return PATTERN_DECREASING;
            default: return PATTERN_RANDOM;
        endcase
    endfunction

    task body();
        int unsigned random_count;
        int unsigned random_length;
        int unsigned random_pattern;
        string case_id;

        setup_vif();
        reset_dut();

        // Default number of random testcases.
        random_count = 20;

        // Allow testcase count to be overridden by plusarg.
        void'($value$plusargs("NUM_RAND=%d", random_count));

        // Prevent excessively long regression runs.
        if (random_count > MAX_RANDOM_COUNT) begin
            `uvm_warning("RAND_LIMIT",
                $sformatf(
                    "NUM_RAND=%0d capped at %0d",
                    random_count,
                    MAX_RANDOM_COUNT
                )
            )
            random_count = MAX_RANDOM_COUNT;
        end

        `uvm_info("RAND_START",
            $sformatf("Starting %0d random testcases", random_count),
            UVM_LOW
        )

        for (int unsigned test_index = 0;
             test_index < random_count;
             test_index++) begin

            // Generate random message length.
            random_length = generate_random_length();

            // Generate random data pattern.
            random_pattern = generate_random_pattern();

            // Generate a unique testcase name.
            case_id = $sformatf(
                "RAND_%0d_LEN_%0d_PATTERN_%0d",
                test_index,
                random_length,
                random_pattern
            );

            `uvm_info("RAND_CASE",
                $sformatf(
                    "Test=%0d/%0d Length=%0d bits Pattern=%0d",
                    test_index + 1,
                    random_count,
                    random_length,
                    random_pattern
                ),
                UVM_MEDIUM
            )

            // Run one random testcase with input gaps enabled.
            run_generated_case(
                case_id,
                random_length,
                random_pattern,
                1'b1
            );
        end

        `uvm_info("RAND_DONE",
            $sformatf("Completed %0d random testcases", random_count),
            UVM_LOW
        )
    endtask

endclass