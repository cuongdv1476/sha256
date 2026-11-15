module sha256_controller #(
    parameter int DATA_WIDTH = 32,
    parameter int BLOCK_SIZE = 512,
    parameter int BIT_LENGTH_WIDTH = 64
)(
    input  logic         i_clk,
    input  logic         i_rst_n,

    // Interface ngoài
    input  logic         i_start,          // 1 chu kỳ bắt đầu message
    input  logic         i_enable,         // i_data hợp lệ khi bằng 1
    input  logic [BIT_LENGTH_WIDTH-1:0]  i_bit_length,
    input  logic [DATA_WIDTH-1:0]  i_data,           // word data từ bên ngoài

    output logic         o_busy,
    output logic         o_ready,
    output logic         o_done,
    output logic         o_valid,
    output logic         o_error,
    output logic [255:0] o_digest,
    output logic [DATA_WIDTH-1:0]  o_data       // word hash tuần tự (debug)
);

    // =========================================================
    // 1. Khai báo wire nội bộ
    // =========================================================

    // ----- block_buffer_512 -----
    logic                bb_start;
    logic [BLOCK_SIZE-1:0]        bb_data;
    logic                bb_done;
    logic                bb_busy;
    logic                bb_ready;
    logic                bb_block_ready;

    // ----- message_schedule_generator -----
    logic                msg_enable;
    logic [BLOCK_SIZE-1:0]        msg_i_data;
    logic                msg_done;
    logic                msg_busy;
    logic                msg_valid;
    logic [DATA_WIDTH-1:0]         msg_data;

    // ----- compression -----
    logic                cmp_init;
    logic                cmp_enable;
    logic [DATA_WIDTH-1:0]         cmp_i_data;
    logic [DATA_WIDTH-1:0]         msg_data_d;
    logic                cmp_busy;
    logic [7:0][DATA_WIDTH-1:0]    cmp_data;
    logic                cmp_done;

    // ----- digest -----
    logic [255:0]        dig_i_data;
    logic [DATA_WIDTH-1:0]         dig_o_data;

    // =========================================================
    // 2. Instantiation các khối
    // =========================================================

    block_buffer_512 #(
        .DATA_WIDTH (DATA_WIDTH),
        .BLOCK_SIZE (BLOCK_SIZE)
    ) u_block_buffer (
        .i_clk        (i_clk),
        .i_rst_n      (i_rst_n),
        .i_start      (bb_start),
        .i_enable     (i_enable && o_ready),
        .i_block_ready(bb_block_ready),
        .i_bit_length (i_bit_length),
        .i_data       (i_data),

        .o_data       (bb_data),
        .o_done       (bb_done),
        .o_busy       (bb_busy),
        .o_ready      (bb_ready)
    );

    message_schedule_generator #(
        .BLOCK_SIZE (BLOCK_SIZE),
        .DATA_WIDTH (DATA_WIDTH)
    ) u_msg_sch (
        .i_clk    (i_clk),
        .i_rst_n  (i_rst_n),
        .i_enable (msg_enable),
        .i_data   (msg_i_data),

        .o_done   (msg_done),
        .o_busy   (msg_busy),
        .o_valid  (msg_valid),
        .o_data   (msg_data)
    );

    compression #(
        .DATA_WIDTH (DATA_WIDTH)
    ) u_compression (
        .i_clk    (i_clk),
        .i_rst_n  (i_rst_n),
        .i_init   (cmp_init),
        .i_enable (cmp_enable),
        .i_data   (cmp_i_data),

        .o_busy   (cmp_busy),
        .o_data   (cmp_data),
        .o_done   (cmp_done)
    );

    digest #(
        .DATA_WIDTH (DATA_WIDTH)
    ) u_digest(
        .i_clk   (i_clk),
        .i_rst_n (i_rst_n),
        .i_data  (dig_i_data),
        .o_data  (dig_o_data)
    );

    // =========================================================
    // 3. Nối datapath
    // =========================================================

    assign msg_i_data = bb_data;
    // Compression starts on i_enable and consumes W[0] one cycle later.
    // Delay the schedule stream so round 0 receives W[0], not W[1].
    assign cmp_i_data = msg_data_d;

    assign dig_i_data = {
        cmp_data[0], cmp_data[1], cmp_data[2], cmp_data[3],
        cmp_data[4], cmp_data[5], cmp_data[6], cmp_data[7]
    };

    assign o_data = dig_o_data;
    assign o_digest = dig_i_data;

    // =========================================================
    // 4. FSM
    // =========================================================

    typedef enum logic [2:0] {
        IDLE,
        WAIT_BLOCK,   // block buffer giữ nguyên block đến khi được acknowledge
        INIT,         // pulse msg_enable + chờ msg_valid
        COMPRESS,         // đang chạy 64 round
        CHECK_NEXT,       // kiểm tra còn block tiếp theo không
        DONE            // xuất hash + done
    } state_t;

    state_t state, nextstate;

    logic first_block;      // =1 → cần assert cmp_init
    logic msg_enable_r;     // để tạo pulse 1 cycle

    // ---------------------------------------------------------
    // Next-state logic
    // ---------------------------------------------------------
    always_comb begin
        nextstate = state;

        case (state)
            IDLE: begin
                if (i_start)
                    nextstate = WAIT_BLOCK;
            end

            WAIT_BLOCK: begin
                if (bb_done)
                    nextstate = INIT;
                else if (!bb_busy)
                    nextstate = DONE;
            end

            INIT: begin
                if (msg_valid)              // message schedule bắt đầu xuất W[0]
                    nextstate = COMPRESS;
            end

            COMPRESS: begin
                if (cmp_done)
                    nextstate = CHECK_NEXT;
            end

            CHECK_NEXT: begin
                nextstate = WAIT_BLOCK;
            end

            DONE: begin
                nextstate = IDLE;
            end

            default: nextstate = IDLE;
        endcase
    end

    // ---------------------------------------------------------
    // Sequential
    // ---------------------------------------------------------
    always_ff @(posedge i_clk) begin
        if (!i_rst_n) begin
            state         <= IDLE;
            first_block   <= 1'b1;
            msg_enable_r  <= 1'b0;
            msg_data_d    <= '0;
        end
        else begin
            state <= nextstate;
            msg_data_d <= msg_data;

            // Ghi nhận đã phát msg_enable cho block hiện tại.
            msg_enable_r <= (state == INIT) && bb_done;

            // Quản lý first_block
            if (state == IDLE && i_start)
                first_block <= 1'b1;
            else if (msg_enable)
                first_block <= 1'b0;
        end
    end

    // ---------------------------------------------------------
    // Control signals
    // ---------------------------------------------------------

    // Block buffer
    assign bb_start       = (state == IDLE) && i_start;
    assign bb_block_ready = (state == CHECK_NEXT);

    // Message schedule: pulse đúng 1 cycle khi block đã sẵn sàng.
    assign msg_enable = (state == INIT) && bb_done && !msg_enable_r;

    // Compression
    assign cmp_init   = msg_enable && first_block;          // chỉ block đầu tiên
    assign cmp_enable = (state == INIT) && msg_valid;  // đúng lúc W[0] xuất hiện

    // Status ra ngoài
    assign o_busy = (state != IDLE);
    assign o_ready = (state == IDLE);
    assign o_done = (state == DONE);
    assign o_valid = (state == DONE);
    assign o_error = 1'b0;

endmodule
