class tb_transaction extends uvm_sequence_item;

    // ---------------- Input stimulus ----------------
    rand bit          i_start;
    rand bit          i_enable;
    rand bit [63:0]   bit_length;
    rand bit [31:0]   i_data;
    bit               i_start_accepted;
    bit               i_word_accepted;
    bit               rst_n;

    // Message gồm nhiều word 32-bit
    rand bit [31:0]   data_q[$];

    // Số chu kỳ chờ giữa các word
    rand int unsigned gap_q[$];

    // ---------------- DUT status ----------------
    bit               o_ready;
    bit               o_busy;
    bit               o_done;
    bit               o_valid;
    bit               o_error;

    // ---------------- SHA-256 digest ----------------
    bit [255:0]       o_digest;
    bit [31:0]        o_data;
    bit [255:0]       exp_digest;

    // ---------------- UVM factory / field macros ----------------
    // Dat sau cac field de Questa resolve duoc ten field trong macro.
    `uvm_object_utils_begin(tb_transaction)
        `uvm_field_int       (i_start,    UVM_ALL_ON)
        `uvm_field_int       (i_enable,   UVM_ALL_ON)
        `uvm_field_int       (bit_length, UVM_ALL_ON)
        `uvm_field_int       (i_data,     UVM_ALL_ON)
        `uvm_field_int       (i_start_accepted, UVM_ALL_ON | UVM_NOCOMPARE)
        `uvm_field_int       (i_word_accepted, UVM_ALL_ON | UVM_NOCOMPARE)
        `uvm_field_int       (rst_n, UVM_ALL_ON | UVM_NOCOMPARE)
        `uvm_field_queue_int (data_q,     UVM_ALL_ON)
        `uvm_field_queue_int (gap_q,      UVM_ALL_ON | UVM_NOCOMPARE)

        `uvm_field_int       (o_digest,   UVM_ALL_ON)
        `uvm_field_int       (o_data,     UVM_ALL_ON | UVM_NOCOMPARE)
        `uvm_field_int       (exp_digest, UVM_ALL_ON)

        `uvm_field_int       (o_valid,    UVM_ALL_ON | UVM_NOCOMPARE)
        `uvm_field_int       (o_ready,    UVM_ALL_ON | UVM_NOCOMPARE)
        `uvm_field_int       (o_busy,     UVM_ALL_ON | UVM_NOCOMPARE)
        `uvm_field_int       (o_done,     UVM_ALL_ON | UVM_NOCOMPARE)
        `uvm_field_int       (o_error,    UVM_ALL_ON | UVM_NOCOMPARE)
    `uvm_object_utils_end

    // ---------------- Constructor ----------------
    function new(string name = "tb_transaction");
        super.new(name);
    endfunction

endclass : tb_transaction
