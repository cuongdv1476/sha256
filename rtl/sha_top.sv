module sha_top #(
    parameter int DATA_WIDTH       = 32,
    parameter int BLOCK_SIZE       = 512,
    parameter int BIT_LENGTH_WIDTH = 64
)(
    input  logic                         i_clk,
    input  logic                         i_rst_n,

    // =====================================================
    // GIAO DIỆN ĐẦU VÀO
    // =====================================================

    input  logic                         i_start,
    input  logic                         i_enable,
    input  logic [BIT_LENGTH_WIDTH-1:0]  i_bit_length,
    input  logic [DATA_WIDTH-1:0]        i_data,

    // =====================================================
    // GIAO DIỆN TRẠNG THÁI
    // =====================================================

    output logic                         o_busy,
    output logic                         o_ready,
    output logic                         o_done,   // xung sau từ digest cuối cùng
    output logic                         o_valid,  // mức cao ở mỗi từ digest 32 bit hợp lệ
    output logic                         o_error,

    // =====================================================
    // Đầu ra digest tuần tự: mỗi chu kỳ hợp lệ xuất một từ DATA_WIDTH bit
    output logic [DATA_WIDTH-1:0]        o_data
);

    // =====================================================
    // 1. CÁC TÍN HIỆU NỘI BỘ
    // =====================================================

    logic ctrl_busy;
    logic ctrl_ready;
    logic ctrl_done;
    logic ctrl_valid;
    logic ctrl_error;

    logic [DATA_WIDTH-1:0] ctrl_data;


    // =====================================================
    // 2. BỘ ĐIỀU KHIỂN SHA-256
    // =====================================================

    sha256_controller #(
        .DATA_WIDTH       (DATA_WIDTH),
        .BLOCK_SIZE       (BLOCK_SIZE),
        .BIT_LENGTH_WIDTH (BIT_LENGTH_WIDTH)
    ) u_sha256_controller (

        // Xung nhịp và đặt lại
        .i_clk        (i_clk),
        .i_rst_n      (i_rst_n),

        // Giao diện đầu vào
        .i_start      (i_start),
        .i_enable     (i_enable),
        .i_bit_length (i_bit_length),
        .i_data       (i_data),

        // Giao diện trạng thái
        .o_busy       (ctrl_busy),
        .o_ready      (ctrl_ready),
        .o_done       (ctrl_done),
        .o_valid      (ctrl_valid),
        .o_error      (ctrl_error),

        // Serialized digest output
        .o_data       (ctrl_data)
    );


    // =====================================================
    // 3. KẾT NỐI ĐẦU RA
    // =====================================================

    assign o_busy   = ctrl_busy;
    assign o_ready  = ctrl_ready;
    assign o_done   = ctrl_done;
    assign o_valid  = ctrl_valid;
    assign o_error  = ctrl_error;

    assign o_data   = ctrl_data;

endmodule