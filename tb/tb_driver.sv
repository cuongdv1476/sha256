class tb_driver extends uvm_driver #(tb_transaction);

    `uvm_component_utils(tb_driver)

    virtual tb_interface #(
        .BLOCK_SIZE (BLOCK_SIZE),
        .DATA_WIDTH (DATA_WIDTH),
        .BIT_LENGTH (BIT_LENGTH)
    ) drv_vif;

    function new(
        string        name,
        uvm_component parent
    );
        super.new(name, parent);
    endfunction


    // ---------------- BUILD PHASE ----------------
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
                "drv_vif",
                drv_vif
            )
        ) begin
            `uvm_fatal("DRV", "Cannot get virtual interface")
        end
    endfunction


    // ---------------- RUN PHASE ----------------
    task run_phase(uvm_phase phase);

        tb_transaction t;
        int unsigned ready_wait_cycles;

        forever begin

            seq_item_port.get_next_item(t);

            // Drive at negedge. For a word, hold valid and data stable until
            // the ready/valid transfer occurs at a rising edge.
            @(negedge drv_vif.clk);

            drv_vif.i_enable   = t.i_enable;
            drv_vif.i_start    = t.i_start;
            drv_vif.bit_length = t.bit_length;
            drv_vif.i_data     = t.i_data;

            if (t.i_enable) begin
                ready_wait_cycles = 0;
                do begin
                    @(posedge drv_vif.clk);
                    if (!drv_vif.o_ready) begin
                        ready_wait_cycles++;
                        if (ready_wait_cycles >= 200000)
                            `uvm_fatal("DRV_WATCHDOG", $sformatf(
                                "Input word %08h was not accepted within %0d cycles",
                                t.i_data, ready_wait_cycles))
                    end
                end while (!drv_vif.o_ready);
            end
            else begin
                @(posedge drv_vif.clk);
            end

            // Clear both controls after the accepted edge. Under backpressure
            // i_enable/data stay asserted/stable until o_ready is observed.
            @(negedge drv_vif.clk);
            drv_vif.i_enable = 1'b0;
            drv_vif.i_start  = 1'b0;
            seq_item_port.item_done();

        end

    endtask

endclass : tb_driver
