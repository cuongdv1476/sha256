class tb_monitor extends uvm_monitor;

    `uvm_component_utils(tb_monitor)

    // =========================================================
    // VIRTUAL INTERFACE
    // =========================================================
    virtual tb_interface #(
        .BLOCK_SIZE (BLOCK_SIZE),
        .DATA_WIDTH (DATA_WIDTH),
        .BIT_LENGTH (BIT_LENGTH)
    ) mon_vif;

    // =========================================================
    // ANALYSIS PORT
    // =========================================================
    uvm_analysis_port #(tb_transaction) ap;

    // =========================================================
    // COVERAGE COMPONENT
    // =========================================================
    tb_coverage cov;


    // =========================================================
    // CONSTRUCTOR
    // =========================================================
    function new(
        string        name,
        uvm_component parent
    );
        super.new(name, parent);

        ap = new("ap", this);
    endfunction


    // =========================================================
    // BUILD PHASE
    // =========================================================
    function void build_phase(uvm_phase phase);

        super.build_phase(phase);

        if (
            !uvm_config_db #(
                virtual tb_interface #(
                    .BLOCK_SIZE (BLOCK_SIZE),
                    .DATA_WIDTH (DATA_WIDTH),
                    .BIT_LENGTH (BIT_LENGTH)
                )
            )::get(
                this,
                "",
                "mon_vif",
                mon_vif
            )
        ) begin
            `uvm_fatal(
                "MON",
                "Cannot get virtual interface"
            )
        end

        cov = tb_coverage::type_id::create("cov", this);

    endfunction


    // =========================================================
    // RUN PHASE
    // =========================================================
    task run_phase(uvm_phase phase);

        tb_transaction tr;
        int unsigned stall_run_length;
        bit input_stalled;
        bit ready_pre, busy_pre, valid_pre, done_pre;

        forever begin

            // Wait for rising edge
            @(posedge mon_vif.clk);

            // Capture transaction
            tr = tb_transaction::type_id::create("tr");

            // Capture input signals
            tr.i_enable   = mon_vif.i_enable;
            tr.i_start    = mon_vif.i_start;
            tr.bit_length = mon_vif.bit_length;
            tr.i_data     = mon_vif.i_data;
            tr.rst_n      = mon_vif.rst_n;
            ready_pre = mon_vif.o_ready;
            busy_pre  = mon_vif.o_busy;
            valid_pre = mon_vif.o_valid;
            done_pre  = mon_vif.o_done;
            tr.i_start_accepted = mon_vif.i_start && mon_vif.o_ready && !mon_vif.o_busy;
            // A zero-bit message may assert start and enable together; the
            // block buffer deliberately ignores that data word.
            tr.i_word_accepted  = mon_vif.i_enable && mon_vif.o_ready
                                && !(tr.i_start_accepted && (mon_vif.bit_length == 0));
            input_stalled = mon_vif.rst_n && mon_vif.i_enable && !tr.i_word_accepted
                          && !(tr.i_start_accepted && (mon_vif.bit_length == 0));
            if (input_stalled)
                stall_run_length++;
            else
                stall_run_length = 0;

            // Wait for DUT outputs to settle
            #1ps;

            // Capture output signals
            tr.o_ready  = mon_vif.o_ready;
            tr.o_busy   = mon_vif.o_busy;
            tr.o_done   = mon_vif.o_done;
            tr.o_valid  = mon_vif.o_valid;
            tr.o_error  = mon_vif.o_error;
            tr.o_digest = mon_vif.o_digest;
            tr.o_data   = mon_vif.o_data;

            // Sample functional coverage
            cov.sample_cov(
                mon_vif.rst_n,
                mon_vif.i_enable,
                mon_vif.bit_length,
                mon_vif.i_data,
                mon_vif.o_ready,
                mon_vif.o_busy,
                mon_vif.o_valid,
                tr.i_start_accepted,
                tr.i_word_accepted,
                mon_vif.reset_scenario,
                input_stalled,
                stall_run_length
            );
            cov.sample_extended(
                mon_vif.rst_n, mon_vif.i_enable, ready_pre,
                mon_vif.bit_length, mon_vif.i_data, mon_vif.i_start,
                busy_pre, ready_pre, valid_pre, done_pre,
                tr.i_start_accepted, tr.i_word_accepted,
                mon_vif.reset_scenario, stall_run_length, cov.cycles_since_start
            );

            // Send transaction to scoreboard
            ap.write(tr);

        end

    endtask

endclass : tb_monitor
