`timescale 1ns/1ps

module tb_sha256;
    import uvm_pkg::*;
    import sha256_pkg::*;

    sha256_if vif();

    sha_top dut (
        .i_clk        (vif.clk),
        .i_rst_n      (vif.rst_n),
        .i_start      (vif.start),
        .i_enable     (vif.enable),
        .i_bit_length (vif.bit_length),
        .i_data       (vif.data),
        .o_busy       (vif.busy),
        .o_ready      (vif.ready),
        .o_done       (vif.done),
        .o_valid      (vif.valid),
        .o_error      (vif.error),
        .o_data       (vif.o_data)
    );

    // Testbench-only visibility for directed reset/coverage scenarios.
    assign vif.cov_controller_state = dut.u_sha256_controller.state;
    assign vif.cov_buffer_state = dut.u_sha256_controller.u_block_buffer.state;
    assign vif.cov_schedule_state = dut.u_sha256_controller.u_msg_sch.state;

    tb_assertions #(
        .DATA_WIDTH (32),
        .MAX_MESSAGE_BITS (64'hffff_ffff_ffff_ffff),
        .MAX_LATENCY_CYCLES (20000)
    ) assertions (
        .i_clk        (vif.clk),
        .i_rst_n      (vif.rst_n),
        .i_start      (vif.start),
        .i_enable     (vif.enable),
        .i_bit_length (vif.bit_length),
        .i_data       (vif.data),
        .o_busy       (vif.busy),
        .o_ready      (vif.ready),
        .o_done       (vif.done),
        .o_valid      (vif.valid),
        .o_error      (vif.error),
        .o_data       (vif.o_data)
    );

    initial vif.clk = 1'b0;
    always #5ns vif.clk = ~vif.clk;

    initial begin
        uvm_config_db#(virtual sha256_if)::set(null, "*", "vif", vif);
        run_test("sha256_test");
    end
endmodule
