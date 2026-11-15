module sha_top #(
    parameter int DATA_WIDTH       = 32,
    parameter int BLOCK_SIZE       = 512,
    parameter int BIT_LENGTH_WIDTH = 64
)(
    input  logic                         i_clk,
    input  logic                         i_rst_n,

    // =====================================================
    // INPUT INTERFACE
    // =====================================================

    input  logic                         i_start,
    input  logic                         i_enable,
    input  logic [BIT_LENGTH_WIDTH-1:0]  i_bit_length,
    input  logic [DATA_WIDTH-1:0]        i_data,

    // =====================================================
    // STATUS INTERFACE
    // =====================================================

    output logic                         o_busy,
    output logic                         o_ready,
    output logic                         o_done,
    output logic                         o_valid,
    output logic                         o_error,

    // =====================================================
    // DIGEST OUTPUT
    // =====================================================

    output logic [255:0]                 o_digest,

    // Sequential 32-bit digest output (debug)
    output logic [DATA_WIDTH-1:0]        o_data
);

    // =====================================================
    // 1. INTERNAL SIGNALS
    // =====================================================

    logic ctrl_busy;
    logic ctrl_ready;
    logic ctrl_done;
    logic ctrl_valid;
    logic ctrl_error;

    logic [255:0] ctrl_digest;
    logic [DATA_WIDTH-1:0] ctrl_data;


    // =====================================================
    // 2. SHA-256 CONTROLLER
    // =====================================================

    sha256_controller #(
        .DATA_WIDTH       (DATA_WIDTH),
        .BLOCK_SIZE       (BLOCK_SIZE),
        .BIT_LENGTH_WIDTH (BIT_LENGTH_WIDTH)
    ) u_sha256_controller (

        // Clock and Reset
        .i_clk        (i_clk),
        .i_rst_n      (i_rst_n),

        // Input Interface
        .i_start      (i_start),
        .i_enable     (i_enable),
        .i_bit_length (i_bit_length),
        .i_data       (i_data),

        // Status Interface
        .o_busy       (ctrl_busy),
        .o_ready      (ctrl_ready),
        .o_done       (ctrl_done),
        .o_valid      (ctrl_valid),
        .o_error      (ctrl_error),

        // Digest Output
        .o_digest     (ctrl_digest),
        .o_data       (ctrl_data)
    );


    // =====================================================
    // 3. OUTPUT CONNECTIONS
    // =====================================================

    assign o_busy   = ctrl_busy;
    assign o_ready  = ctrl_ready;
    assign o_done   = ctrl_done;
    assign o_valid  = ctrl_valid;
    assign o_error  = ctrl_error;

    assign o_digest = ctrl_digest;
    assign o_data   = ctrl_data;

endmodule