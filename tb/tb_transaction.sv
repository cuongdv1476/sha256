class sha256_transaction extends uvm_sequence_item;
    bit         i_rst_n;
    bit         i_start;
    bit         i_enable;
    bit [3:0]   cov_reset_scenario;
    bit         cov_expect_error;
    randc bit [63:0]  i_bit_length;
    randc bit [31:0]  i_data;
    bit         o_ready_pre;
    bit         o_busy_pre;
    bit         o_valid_pre;

    bit         o_busy;
    bit         o_ready;
    bit         o_done;
    bit         o_valid;
    bit         o_error;
    bit [31:0]  o_data;

    `uvm_object_utils_begin(sha256_transaction)
        `uvm_field_int(i_rst_n,      UVM_DEFAULT)
        `uvm_field_int(i_start,      UVM_DEFAULT)
        `uvm_field_int(i_enable,     UVM_DEFAULT)
        `uvm_field_int(cov_reset_scenario, UVM_DEFAULT)
        `uvm_field_int(cov_expect_error, UVM_DEFAULT)
        `uvm_field_int(i_bit_length, UVM_DEFAULT)
        `uvm_field_int(i_data,       UVM_DEFAULT)
        `uvm_field_int(o_ready_pre,  UVM_DEFAULT)
        `uvm_field_int(o_busy_pre,   UVM_DEFAULT)
        `uvm_field_int(o_valid_pre,  UVM_DEFAULT)
        `uvm_field_int(o_busy,       UVM_DEFAULT)
        `uvm_field_int(o_ready,      UVM_DEFAULT)
        `uvm_field_int(o_done,       UVM_DEFAULT)
        `uvm_field_int(o_valid,      UVM_DEFAULT)
        `uvm_field_int(o_error,      UVM_DEFAULT)
        `uvm_field_int(o_data,       UVM_DEFAULT)
    `uvm_object_utils_end

    function new(string name = "sha256_transaction");
        super.new(name);
    endfunction
endclass
