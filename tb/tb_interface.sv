interface sha256_if;
    logic         clk;
    logic         rst_n;
    logic         start;
    logic         enable;
    logic [63:0]  bit_length;
    logic [31:0]  data;
    logic [3:0]   cov_reset_scenario;
    logic         cov_expect_error;
    logic [2:0]   cov_controller_state;
    logic [1:0]   cov_buffer_state;
    logic [1:0]   cov_schedule_state;

    logic         busy;
    logic         ready;
    logic         done;
    logic         valid;
    logic         error;
    logic [31:0]  o_data;
endinterface
