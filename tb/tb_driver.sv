class sha256_driver extends uvm_driver #(sha256_transaction);
    `uvm_component_utils(sha256_driver)

    virtual sha256_if vif;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(virtual sha256_if)::get(this, "", "vif", vif))
            `uvm_fatal("DRV", "Cannot get SHA-256 virtual interface")
    endfunction

    task run_phase(uvm_phase phase);
        sha256_transaction tr;
        vif.rst_n      <= 1'b0;
        vif.start      <= 1'b0;
        vif.enable     <= 1'b0;
        vif.bit_length <= '0;
        vif.data       <= '0;
        vif.cov_reset_scenario <= '0;
        vif.cov_expect_error <= 1'b0;

        forever begin
            seq_item_port.get_next_item(tr);
            @(negedge vif.clk);
            vif.rst_n      <= tr.i_rst_n;
            vif.start      <= tr.i_start;
            vif.enable     <= tr.i_enable;
            vif.bit_length <= tr.i_bit_length;
            vif.data       <= tr.i_data;
            vif.cov_reset_scenario <= tr.cov_reset_scenario;
            vif.cov_expect_error <= tr.cov_expect_error;

            // Keep an enabled word and its data stable until the DUT accepts
            // it. The ready signal can go low while a full block is hashed.
            do begin
                @(posedge vif.clk);
            end while (tr.i_enable && !vif.ready);

            seq_item_port.item_done();
        end
    endtask
endclass
