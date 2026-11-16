class sha256_reset_sequence extends sha256_base_sequence;
    `uvm_object_utils(sha256_reset_sequence)

    function new(string name = "sha256_reset_sequence");
        super.new(name);
    endfunction

    task automatic reset_when_state(
        input int controller_state,
        input int buffer_state,
        input int schedule_state,
        input bit [3:0] scenario,
        input string label
    );
        for (int unsigned cycle = 0; cycle < 2000; cycle++) begin
            if ((controller_state < 0 || vif.cov_controller_state == controller_state) &&
                (buffer_state < 0 || vif.cov_buffer_state == buffer_state) &&
                (schedule_state < 0 || vif.cov_schedule_state == schedule_state)) begin
                `uvm_info("TESTCASE", $sformatf("Reset in internal phase %s", label), UVM_LOW)
                reset_dut(2, scenario);
                return;
            end
            send_cycle(1, 0, 0, 0, 0);
        end
        `uvm_fatal("RESET_COV", $sformatf("Did not reach phase %s", label))
    endtask

    task automatic send_full_512_message();
        send_cycle(1, 1, 1, 64'd512, 32'hdead_beef);
        for (int unsigned word_index = 1; word_index < 16; word_index++)
            send_cycle(1, 0, 1, 64'd512,
                       32'hdead_beef ^ (32'h0101_0101 * word_index));
    endtask

    task body();
        setup_vif();
        reset_dut(3); // RESET_01: reset while idle, repeated for multiple cycles.

        `uvm_info("TESTCASE", "START RESET_02: reset while receiving", UVM_LOW)
        send_cycle(1, 1, 1, 64'd512, 32'h0123_4567);
        send_cycle(1, 0, 1, 64'd512, 32'h89ab_cdef);
        reset_dut(2, 1); // reset while receiving

        `uvm_info("TESTCASE", "START RESET_03: reset while processing", UVM_LOW)
        send_full_512_message();
        reset_when_state(2, -1, 1, 2, "controller init + schedule expand");

        `uvm_info("TESTCASE", "START RESET_04: reset while outputting digest", UVM_LOW)
        send_cycle(1, 1, 1, 64'd32, 32'h1357_9bdf);
        wait_valid("RESET_04");
        reset_dut(2, 3); // reset while outputting digest

        // Start without the first data word, then provide it in RECEIVE.
        // This covers both false sides of the small-message start conditions.
        wait_idle();
        send_cycle(1, 1, 0, 64'd24, 0);
        send_cycle(1, 0, 1, 64'd24, 32'h1357_9bdf);
        wait_done("RESET_05_START_WITHOUT_DATA");

        // Empty messages may assert enable alongside start; no data word is
        // consumed because the advertised length is zero.
        wait_idle();
        send_cycle(1, 1, 1, 64'd0, 32'hffff_ffff);
        wait_done("RESET_05B_EMPTY_WITH_ENABLE");

        // Reset from PADDING and CHECK_NEXT exercises reset transitions that
        // ordinary completed messages cannot take.
        wait_idle();
        send_cycle(1, 1, 0, 0, 0);
        reset_when_state(-1, 2, -1, 2, "block-buffer padding");

        send_full_512_message();
        reset_when_state(4, -1, -1, 2, "controller check-next");

        // Exercise the complete 64-bit length datapath without attempting an
        // impractically long hash; reset immediately after the accepted start.
        send_cycle(1, 1, 0, 64'hffff_ffff_ffff_ffff, 0);
        reset_dut(2, 2);

        // Negative protocol test: a busy start must set the sticky error flag.
        send_cycle(1, 1, 1, 64'd512, 32'h1234_5678);
        send_cycle(1, 1, 0, 64'd512, 0, 0, 1);
        send_cycle(1, 0, 0, 64'd512, 0, 0, 1);
        reset_dut();

        run_generated_case("RESET_06_AFTER_RESET", 64'd24,
                           PATTERN_INCREASING);
    endtask
endclass
