interface tb_interface #(
    parameter int BLOCK_SIZE = 512,
    parameter int DATA_WIDTH = 32,
    parameter int BIT_LENGTH = 64
);
    logic                         clk;
    logic                         rst_n;
    // i_start latches message length; words are accepted when i_enable && o_ready.
    logic                         i_start;
    logic                         i_enable;
    logic [BIT_LENGTH-1:0]        bit_length;
    logic [DATA_WIDTH-1:0]        i_data;
    logic                         o_busy;
    logic                         o_ready;
    logic                         o_done;
    logic                         o_valid;
    logic                         o_error;
    logic [255:0]                 o_digest;
    logic [DATA_WIDTH-1:0]        o_data;

    // Testbench-owned reset injection tag: 0=power-up, 1..10=test phases.
    logic [3:0]                   reset_scenario;

    // Verification-only state taps; these are not DUT interface signals.
    logic [2:0]                   dbg_ctrl_state;
    logic [1:0]                   dbg_block_state;
    logic [1:0]                   dbg_schedule_state;
    logic [5:0]                   dbg_compression_round;
    logic                         dbg_compression_busy;
endinterface
