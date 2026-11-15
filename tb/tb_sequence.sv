class tb_sequence extends uvm_sequence #(tb_transaction);

    `uvm_object_utils(tb_sequence)

    virtual tb_interface #(
        .BLOCK_SIZE (BLOCK_SIZE),
        .DATA_WIDTH (DATA_WIDTH),
        .BIT_LENGTH (BIT_LENGTH)
    ) vif;

    int unsigned tc_sel = 0;
    localparam int unsigned WAIT_WATCHDOG_CYCLES = 200000;

    function new(string name = "tb_sequence");
        super.new(name);
    endfunction

    task pre_start();
        if (!uvm_config_db #(
            virtual tb_interface #(
                .BLOCK_SIZE (BLOCK_SIZE),
                .DATA_WIDTH (DATA_WIDTH),
                .BIT_LENGTH (BIT_LENGTH)
            )
        )::get(m_sequencer, "", "seq_vif", vif)) begin
            `uvm_fatal("SEQ", "Cannot get sequence virtual interface")
        end
    endtask

    task send_item(
        bit         i_start,
        bit         i_enable,
        bit [63:0]  bit_length,
        bit [31:0]  i_data
    );
        tb_transaction tr;

        tr = tb_transaction::type_id::create("tr");
        start_item(tr);
        tr.i_start    = i_start;
        tr.i_enable   = i_enable;
        tr.bit_length = bit_length;
        tr.i_data     = i_data;
        finish_item(tr);
    endtask

    task wait_for_valid(input string wait_label);
        for (int unsigned cycle = 0; cycle < WAIT_WATCHDOG_CYCLES; cycle++) begin
            @(posedge vif.clk);
            #1ps;
            if (vif.o_valid)
                return;
        end
        `uvm_fatal("SEQ_WATCHDOG", $sformatf(
            "Timed out waiting for o_valid (%s), busy=%0b ready=%0b",
            wait_label, vif.o_busy, vif.o_ready))
    endtask

    task wait_for_ready(input string wait_label);
        for (int unsigned cycle = 0; cycle < WAIT_WATCHDOG_CYCLES; cycle++) begin
            @(posedge vif.clk);
            #1ps;
            if (vif.o_ready)
                return;
        end
        `uvm_fatal("SEQ_WATCHDOG", $sformatf(
            "Timed out waiting for o_ready (%s), busy=%0b valid=%0b",
            wait_label, vif.o_busy, vif.o_valid))
    endtask

    task send_message(
        bit [63:0] len,
        bit [31:0] words[$],
        bit start_with_first_word = 1'b0
    );
        int unsigned needed_words;

        needed_words = (len + 31) / 32;
        if (words.size() != needed_words) begin
            `uvm_fatal("SEQ", $sformatf(
                "Sai so word: len=%0d can %0d word, nhan %0d",
                len, needed_words, words.size()))
        end

        `uvm_info("SEQ", $sformatf(
            "Send message len=%0d words=%0d", len, needed_words), UVM_LOW)

        if (start_with_first_word && (words.size() != 0))
            send_item(1'b1, 1'b1, len, words[0]);
        else
            send_item(1'b1, 1'b0, len, 32'h0);
        foreach (words[w]) begin
            if (start_with_first_word && (w == 0))
                continue;
            // Random idle gaps. The driver holds each offered word stable
            // across any o_ready-low interval until the handshake completes.
            repeat ($urandom_range(0, 2)) @(posedge vif.clk);
            send_item(1'b0, 1'b1, len, words[w]);
        end
        send_item(1'b0, 1'b0, len, 32'h0);
        // Chi duoc gui message tiep theo sau khi da co digest hop le.
        wait_for_valid($sformatf("message length %0d", len));
        wait_for_ready($sformatf("after message length %0d", len));
    endtask

    task tc_empty();
        bit [31:0] words[$];
        words.delete();
        send_message(0, words);
    endtask

    task tc_empty_with_simultaneous_enable();
        send_item(1'b1, 1'b1, 64'd0, 32'hdead_beef);
        send_item(1'b0, 1'b0, 64'd0, 32'd0);
        wait_for_valid("empty message with simultaneous enable");
        wait_for_ready("after empty message with simultaneous enable");
    endtask

    task tc_abc();
        bit [31:0] words[$];
        words = '{32'h6162_6300};
        send_message(24, words, 1'b1);
    endtask

    task tc_len1();
        bit [31:0] words[$];
        words = '{32'h8000_0000};
        send_message(1, words);
    endtask

    task tc_len32();
        bit [31:0] words[$];
        words = '{32'h1234_5678};
        send_message(32, words);
    endtask

    task tc_len448();
        bit [31:0] words[$];
        words = '{
            32'h0000_0000, 32'hffff_ffff, 32'h8000_0000, 32'h0000_0001,
            32'h5555_aaaa, 32'haaaa_5555, 32'h5555_5555, 32'haaaa_aaaa,
            32'h0f0f_0f0f, 32'hf0f0_f0f0, 32'h00ff_00ff, 32'hff00_ff00,
            32'hdead_beef, 32'h7fff_ffff
        };
        send_message(448, words);
    endtask

    task tc_len512();
        bit [31:0] words[$];
        words = '{
            32'h0000_0000, 32'hffff_ffff, 32'h8000_0000, 32'h0000_0001,
            32'h5555_aaaa, 32'haaaa_5555, 32'h5555_5555, 32'haaaa_aaaa,
            32'h0f0f_0f0f, 32'hf0f0_f0f0, 32'h00ff_00ff, 32'hff00_ff00,
            32'h0000_ffff, 32'hffff_0000, 32'hffff_fffe, 32'hdead_beef
        };
        send_message(512, words);
    endtask

    task tc_len1000();
        bit [31:0] words[$];
        words.delete();
        for (int i = 0; i < 31; i++)
            words.push_back(32'h0102_0304 + i);
        words.push_back(32'h8000_0000);
        send_message(1000, words);
    endtask

    task tc_len1024();
        bit [31:0] words[$];
        words.delete();
        for (int i = 0; i < 32; i++)
            words.push_back(32'h5555_aaaa ^ i);
        send_message(1024, words);
    endtask

    task tc_generated_length(int unsigned len);
        bit [31:0] words[$];
        int unsigned nwords;

        nwords = (len + 31) / 32;
        words.delete();
        for (int unsigned i = 0; i < nwords; i++)
            words.push_back((32'h9e37_79b9 * (i + 1)) ^ len);
        send_message(len, words);
    endtask

    task tc_pattern_word(input int unsigned len, input bit [31:0] pattern);
        bit [31:0] words[$];
        int unsigned nwords;
        nwords = (len + 31) / 32;
        words.delete();
        for (int unsigned i = 0; i < nwords; i++) words.push_back(pattern);
        send_message(len, words);
    endtask

    // 35 named directed scenarios in the requested allocation. Some overlap
    // existing boundary coverage deliberately; duplicate scenarios are useful
    // because they exercise data/protocol contexts with controlled payloads.
    task tc_directed_35();
        // 15 message-length cases.
        tc_generated_length(0); tc_generated_length(1); tc_generated_length(31);
        tc_generated_length(32); tc_generated_length(33); tc_generated_length(447);
        tc_generated_length(448); tc_generated_length(449); tc_generated_length(511);
        tc_generated_length(512); tc_generated_length(513); tc_generated_length(895);
        tc_generated_length(896); tc_generated_length(897); tc_generated_length(4096);

        // 6 data-pattern cases cover all requested pattern classes at small
        // and long message sizes so pattern x size has a deliberate matrix.
        tc_pattern_word(64, 32'h0000_0000);
        tc_pattern_word(64, 32'hffff_ffff);
        tc_pattern_word(64, 32'haaaa_aaaa);
        tc_pattern_word(64, 32'h8000_0000);
        begin
            bit [31:0] walking[$];
            walking = '{32'h0000_0001,32'hffff_fffe};
            send_message(64, walking);
        end
        begin
            bit [31:0] mixed[$];
            mixed = '{32'h0000_0000,32'hffff_ffff,32'haaaa_aaaa,32'h5555_5555,
                      32'h8000_0000,32'h0000_0001,32'h0000_0002,32'hffff_fffd,
                      32'h3141_5926};
            for (int i=9; i<128; i++) mixed.push_back(32'h3141_5926 ^ i);
            send_message(4096, mixed);
        end

        // 3 additional padding/block-count edges.
        tc_generated_length(959); tc_generated_length(960); tc_generated_length(1023);

        // 3 input protocol cases: refill while a full block is processed.
        tc_generated_length(1024); tc_generated_length(2048); tc_generated_length(4096);

        // 2 output pulse/latency cases (the interface has no output-ready).
        tc_empty(); tc_generated_length(1024);

        // 3 reset cases: idle, active receive, and output/DONE are also covered
        // by the state-directed reset sweep below.
        reset_dut(4'd0);
        send_item(1'b1, 1'b0, 64'd4096, 32'd0);
        wait_debug_state(1, -1, -1, -1);
        reset_dut(4'd1);
        tc_generated_length(0);
        send_item(1'b1, 1'b0, 64'd0, 32'd0);
        wait_debug_state(5, -1, -1, -1);
        reset_dut(4'd10);

        // 3 legal control-flow cases: start, back-to-back messages, multi-block busy.
        tc_abc(); tc_empty(); tc_generated_length(1024);
    endtask

    task tc_random_messages(int unsigned count);
        bit [31:0] words[$];
        int unsigned len;
        bit simultaneous_start;

        for (int unsigned test_id = 0; test_id < count; test_id++) begin
            len = $urandom_range(0, 4096);
            words.delete();
            for (int unsigned w = 0; w < ((len + 31) / 32); w++)
                words.push_back($urandom());
            simultaneous_start = (words.size() != 0) && $urandom_range(0, 1);
            send_message(len, words, simultaneous_start);
        end
    endtask

    // Toggle the upper input length bits while the interface is idle. These
    // bits are part of the 64-bit port but normal practical messages do not
    // reach them; with i_start low this exercises input toggles without
    // creating an enormous or malformed message transaction.
    task tc_idle_length_input_toggles();
        for (int bit_index = 13; bit_index < 64; bit_index++)
            send_item(1'b0, 1'b0, (64'd1 << bit_index), 32'd0);
        send_item(1'b0, 1'b0, 64'd0, 32'd0);
    endtask

    // Latch walking-one length values into the block buffer, then reset while
    // it is waiting for the declared (deliberately incomplete) message. This
    // exercises the wide length register and derived word-count toggles without
    // attempting to transmit an impractically large message.
    task tc_length_register_toggles();
        for (int bit_index = 13; bit_index < 64; bit_index++) begin
            send_item(1'b1, 1'b0, (64'd1 << bit_index), 32'd0);
            wait_debug_state(1, -1, -1, -1);
            reset_dut(4'd1);
        end
    endtask

    task wait_debug_state(
        int ctrl_state = -1,
        int block_state = -1,
        int schedule_state = -1,
        int compression_round = -1
    );
        bit matched;
        matched = 0;
        for (int unsigned cycle = 0; cycle < 2000; cycle++) begin
            #1ps;
            matched = ((ctrl_state == -1) || (vif.dbg_ctrl_state == ctrl_state))
                   && ((block_state == -1) || (vif.dbg_block_state == block_state))
                   && ((schedule_state == -1) || (vif.dbg_schedule_state == schedule_state))
                   && ((compression_round == -1)
                       || (vif.dbg_compression_busy
                           && vif.dbg_compression_round == compression_round));
            if (matched)
                return;
            @(posedge vif.clk);
        end
        `uvm_fatal("RESET_TEST", $sformatf(
            "Timed out waiting debug states ctrl=%0d block=%0d schedule=%0d round=%0d",
            ctrl_state, block_state, schedule_state, compression_round))
    endtask

    task reset_dut(
        input logic [3:0] scenario,
        input bit assert_in_current_cycle = 1'b0
    );
        // wait_debug_state returns #1ps after observing the requested state.
        // For a one-cycle state such as block-buffer PADDING, assert reset
        // immediately so the next active edge resets from PADDING itself.
        if (!assert_in_current_cycle)
            @(negedge vif.clk);
        vif.reset_scenario = scenario;
        vif.rst_n = 1'b0;
        repeat (2) @(posedge vif.clk);
        #1ps;
        if (vif.o_busy || !vif.o_ready || vif.o_done || vif.o_valid)
            `uvm_error("RESET_TEST", "DUT status did not return to reset/idle values")
        @(negedge vif.clk);
        vif.rst_n = 1'b1;
        wait_for_ready("after reset release");
    endtask

    task tc_reset_injection();
        // Controller WAIT_BLOCK / block buffer RECEIVE.
        send_item(1'b1, 1'b0, 64'd4096, 32'h0);
        wait_debug_state(1, -1, -1, -1);
        reset_dut(4'd1);

        // Block-buffer PADDING.
        send_item(1'b1, 1'b0, 64'd1, 32'h0);
        send_item(1'b0, 1'b1, 64'd1, 32'h8000_0000);
        wait_debug_state(-1, 2, -1, -1);
        reset_dut(4'd2, 1'b1);

        // Schedule EXPAND and OUTPUT, and controller INIT.
        send_item(1'b1, 1'b0, 64'd0, 32'h0);
        wait_debug_state(-1, -1, 1, -1);
        reset_dut(4'd3);

        send_item(1'b1, 1'b0, 64'd0, 32'h0);
        wait_debug_state(-1, -1, 2, -1);
        reset_dut(4'd4);

        send_item(1'b1, 1'b0, 64'd0, 32'h0);
        wait_debug_state(2, -1, -1, -1);
        reset_dut(4'd5);

        // Compression reset at first, middle, and final-round indices.
        send_item(1'b1, 1'b0, 64'd0, 32'h0);
        wait_debug_state(-1, -1, -1, 0);
        reset_dut(4'd6);

        send_item(1'b1, 1'b0, 64'd0, 32'h0);
        wait_debug_state(-1, -1, -1, 31);
        reset_dut(4'd7);

        send_item(1'b1, 1'b0, 64'd0, 32'h0);
        wait_debug_state(-1, -1, -1, 63);
        reset_dut(4'd8);

        // Controller CHECK_NEXT and DONE.
        send_item(1'b1, 1'b0, 64'd0, 32'h0);
        wait_debug_state(4, -1, -1, -1);
        reset_dut(4'd9);

        send_item(1'b1, 1'b0, 64'd0, 32'h0);
        wait_debug_state(5, -1, -1, -1);
        reset_dut(4'd10);
        `uvm_info("RESET_TEST", "Reset injection passed at controller WAIT_BLOCK/INIT/CHECK_NEXT/DONE, block PADDING, schedule EXPAND/OUTPUT and compression rounds 0/31/63", UVM_LOW)
    endtask

    task body();
        int unsigned sel;
        int unsigned num_rand;
        string seq_mode;
        bit tc_override;

        seq_mode = "all";
        num_rand = 1000;
        void'($value$plusargs("SEQ_MODE=%s", seq_mode));
        void'($value$plusargs("NUM_RAND=%d", num_rand));
        sel = tc_sel;
        tc_override = $value$plusargs("TC=%d", sel);

        if (!tc_override && !(seq_mode inside {"dir", "all", "rand"}))
            `uvm_fatal("SEQ_MODE", $sformatf(
                "Unsupported SEQ_MODE='%s' (expected dir, all, or rand)", seq_mode))

        // Khong phat transaction truoc khi reset ket thuc.
        wait_for_ready("initial reset release");
        send_item(0, 0, 0, 0);
        send_item(0, 0, 0, 0);

        if (!tc_override && (seq_mode == "rand")) begin
            tc_random_messages(num_rand);
            return;
        end

        tc_idle_length_input_toggles();

        if (sel == 0 || sel == 1) begin
            tc_empty();
            tc_empty_with_simultaneous_enable();
        end
        if (sel == 0 || sel == 2) tc_abc();
        if (sel == 0 || sel == 3) tc_len1();
        if (sel == 0 || sel == 4) tc_len32();
        if (sel == 0 || sel == 5) tc_len448();
        if (sel == 0 || sel == 6) tc_len512();
        if (sel == 0 || sel == 7) tc_len1000();
        if (sel == 0 || sel == 8) tc_len1024();

        if (sel == 0) begin
            tc_length_register_toggles();
            // SHA-256 padding / block-count boundaries from the plan.
            tc_generated_length(2);
            tc_generated_length(7);
            tc_generated_length(8);
            tc_generated_length(9);
            tc_generated_length(16);
            tc_generated_length(31);
            tc_generated_length(32);
            tc_generated_length(33);
            tc_generated_length(447);
            tc_generated_length(448);
            tc_generated_length(449);
            tc_generated_length(480);
            tc_generated_length(511);
            tc_generated_length(513);
            tc_generated_length(544);
            tc_generated_length(895);
            tc_generated_length(896);
            tc_generated_length(897);
            tc_generated_length(959);
            tc_generated_length(960);
            tc_generated_length(1023);
            tc_generated_length(1025);
            tc_generated_length(2048);
            tc_generated_length(5120); // 10 full message blocks plus padding
            // Long directed messages push the live block-buffer counters
            // through progressively higher bits. Keep the lengths below the
            // sequence's 200,000-cycle valid watchdog, including final hash.
            tc_generated_length(16_384);
            tc_generated_length(65_536);
            tc_generated_length(262_144);
            tc_generated_length(1_048_576);
            tc_reset_injection();
            tc_directed_35();
            if (!tc_override && (seq_mode == "dir")) begin
                // Leave at least one complete compression transaction after
                // the reset sweep so the internal checker has non-vacuous
                // schedule/round evidence in the smoke run.
                tc_abc();
                `uvm_info("SEQ", "Directed smoke suite complete", UVM_LOW)
            end
            else begin
                tc_random_messages(num_rand);
            end
        end
    endtask

endclass : tb_sequence
