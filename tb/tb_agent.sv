class tb_agent extends uvm_agent;
    `uvm_component_utils(tb_agent)

    sha256_sequencer seqr;
    sha256_driver    drv;
    sha256_monitor   mon;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        seqr = sha256_sequencer::type_id::create("seqr", this);
        drv  = sha256_driver::type_id::create("drv", this);
        mon  = sha256_monitor::type_id::create("mon", this);
    endfunction

    function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        drv.seq_item_port.connect(seqr.seq_item_export);
    endfunction
endclass
