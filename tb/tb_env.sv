class tb_env extends uvm_env;

    `uvm_component_utils(tb_env)

    // =========================================================
    // COMPONENTS
    // =========================================================
    tb_sequencer  seqr;
    tb_driver     drv;
    tb_monitor    mon;     // chua tb_coverage ben trong
    tb_scoreboard scb;


    // =========================================================
    // CONSTRUCTOR
    // =========================================================
    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction


    // =========================================================
    // BUILD PHASE
    // =========================================================
    function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        seqr = tb_sequencer::type_id::create("seqr", this);
        drv  = tb_driver::type_id::create("drv", this);
        mon  = tb_monitor::type_id::create("mon", this);
        scb  = tb_scoreboard::type_id::create("scb", this);
    endfunction


    // =========================================================
    // CONNECT PHASE
    // =========================================================
    function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);

        // sequencer -> driver
        drv.seq_item_port.connect(seqr.seq_item_export);

        // monitor -> scoreboard
        mon.ap.connect(scb.ap_imp);
    endfunction


    // =========================================================
    // END OF ELABORATION: in cau truc testbench de debug
    // =========================================================
    function void end_of_elaboration_phase(uvm_phase phase);
        super.end_of_elaboration_phase(phase);
        uvm_top.print_topology();
    endfunction

endclass : tb_env