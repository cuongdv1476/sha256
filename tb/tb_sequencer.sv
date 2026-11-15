class tb_sequencer extends uvm_sequencer #(tb_transaction);

    `uvm_component_utils(tb_sequencer)

    function new(
        string        name,
        uvm_component parent
    );
        super.new(name, parent);
    endfunction

endclass : tb_sequencer