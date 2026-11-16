class sha256_monitor extends uvm_monitor;
    `uvm_component_utils(sha256_monitor)

    virtual sha256_if vif;
    uvm_analysis_port #(sha256_transaction) ap;

    function new(string name, uvm_component parent);
        super.new(name, parent);
        ap = new("ap", this);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(virtual sha256_if)::get(this, "", "vif", vif))
            `uvm_fatal("MON", "Cannot get SHA-256 virtual interface")
    endfunction

    task run_phase(uvm_phase phase);
        sha256_transaction tr;
        forever begin
            @(posedge vif.clk);
            tr = sha256_transaction::type_id::create("observed");
            tr.i_rst_n      = vif.rst_n;
            tr.i_start      = vif.start;
            tr.i_enable     = vif.enable;
            tr.i_bit_length = vif.bit_length;
            tr.i_data       = vif.data;
            tr.cov_reset_scenario = vif.cov_reset_scenario;
            tr.cov_expect_error = vif.cov_expect_error;
            tr.o_ready_pre  = vif.ready;
            tr.o_busy_pre   = vif.busy;
            tr.o_valid_pre  = vif.valid;
            #1ps;
            tr.o_busy   = vif.busy;
            tr.o_ready  = vif.ready;
            tr.o_done   = vif.done;
            tr.o_valid  = vif.valid;
            tr.o_error  = vif.error;
            tr.o_data = vif.o_data;
            ap.write(tr);
        end
    endtask
endclass
