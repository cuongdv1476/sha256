`timescale 1ns/1ps

// ================================================================
// SHA-256 UVM simulation top
//
// File nay la top-level duy nhat cua testbench:
//   - tao clock/reset;
//   - tao virtual interface va DUT;
//   - nap virtual interface cho driver/monitor;
//   - include cac UVM class da viet;
//   - khoi dong tb_test.
// ================================================================

package tb_pkg;
    import uvm_pkg::*;
    `include "uvm_macros.svh"

    localparam int BLOCK_SIZE = 512;
    localparam int DATA_WIDTH = 32;
    localparam int BIT_LENGTH = 64;

    `include "tb_transaction.sv"
    `include "tb_sequencer.sv"
    `include "tb_driver.sv"
    `include "tb_coverage.sv"
    `include "tb_monitor.sv"
    `include "tb_scoreboard.sv"
    `include "tb_env.sv"
    `include "tb_sequence.sv"
    `include "tb_test.sv"
endpackage

module tb_sha256;
    import uvm_pkg::*;
    import tb_pkg::*;

    localparam time CLK_PERIOD = 10ns;

    tb_interface #(
        .BLOCK_SIZE (BLOCK_SIZE),
        .DATA_WIDTH (DATA_WIDTH),
        .BIT_LENGTH (BIT_LENGTH)
    ) vif();

    sha_top #(
        .DATA_WIDTH       (DATA_WIDTH),
        .BLOCK_SIZE       (BLOCK_SIZE),
        .BIT_LENGTH_WIDTH (BIT_LENGTH)
    ) dut (
        .i_clk        (vif.clk),
        .i_rst_n      (vif.rst_n),
        .i_start      (vif.i_start),
        .i_enable     (vif.i_enable),
        .i_bit_length (vif.bit_length),
        .i_data       (vif.i_data),
        .o_busy       (vif.o_busy),
        .o_ready      (vif.o_ready),
        .o_done       (vif.o_done),
        .o_valid      (vif.o_valid),
        .o_error      (vif.o_error),
        .o_digest     (vif.o_digest),
        .o_data       (vif.o_data)
    );

    assign vif.dbg_ctrl_state = dut.u_sha256_controller.state;
    assign vif.dbg_block_state = dut.u_sha256_controller.u_block_buffer.state;
    assign vif.dbg_schedule_state = dut.u_sha256_controller.u_msg_sch.state;
    assign vif.dbg_compression_round = dut.u_sha256_controller.u_compression.round_cnt;
    assign vif.dbg_compression_busy = dut.u_sha256_controller.cmp_busy;

    sha256_internal_checker internal_checker (
        .clk                    (vif.clk),
        .rst_n                  (vif.rst_n),
        .input_start            (vif.i_start),
        .input_enable           (vif.i_enable),
        .input_data             (vif.i_data),
        .schedule_start         (dut.u_sha256_controller.msg_enable),
        .schedule_block         (dut.u_sha256_controller.msg_i_data),
        .schedule_valid         (dut.u_sha256_controller.msg_valid),
        .schedule_data          (dut.u_sha256_controller.msg_data),
        .schedule_done          (dut.u_sha256_controller.msg_done),
        .compression_busy       (dut.u_sha256_controller.cmp_busy),
        .compression_done       (dut.u_sha256_controller.cmp_done),
        .compression_round      (dut.u_sha256_controller.u_compression.round_cnt),
        .compression_data       (dut.u_sha256_controller.cmp_i_data),
        .block_done              (dut.u_sha256_controller.bb_done),
        .block_ack               (dut.u_sha256_controller.bb_block_ready),
        .block_data              (dut.u_sha256_controller.bb_data),
        .top_busy                (vif.o_busy),
        .top_ready               (vif.o_ready),
        .top_done                (vif.o_done),
        .top_valid               (vif.o_valid),
        .top_error               (vif.o_error),
        .top_digest              (vif.o_digest)
    );

    initial begin
        vif.clk = 1'b0;
        forever #(CLK_PERIOD / 2) vif.clk = ~vif.clk;
    end

    initial begin
        vif.rst_n      = 1'b0;
        vif.i_enable   = 1'b0;
        vif.i_start    = 1'b0;
        vif.bit_length = '0;
        vif.i_data     = '0;
        vif.reset_scenario = 4'd0;

        repeat (4) @(posedge vif.clk);
        vif.rst_n = 1'b1;
    end

    initial begin
        uvm_config_db #(virtual tb_interface #(
            .BLOCK_SIZE (BLOCK_SIZE),
            .DATA_WIDTH (DATA_WIDTH),
            .BIT_LENGTH (BIT_LENGTH)
        ))::set(null, "*", "drv_vif", vif);

        uvm_config_db #(virtual tb_interface #(
            .BLOCK_SIZE (BLOCK_SIZE),
            .DATA_WIDTH (DATA_WIDTH),
            .BIT_LENGTH (BIT_LENGTH)
        ))::set(null, "*", "mon_vif", vif);

        uvm_config_db #(virtual tb_interface #(
            .BLOCK_SIZE (BLOCK_SIZE),
            .DATA_WIDTH (DATA_WIDTH),
            .BIT_LENGTH (BIT_LENGTH)
        ))::set(null, "*", "seq_vif", vif);

        run_test("tb_test");
    end
endmodule
