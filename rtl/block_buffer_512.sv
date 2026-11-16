module block_buffer_512 #(
    parameter int DATA_WIDTH = 32,
    parameter int BLOCK_SIZE = 512
)(
    input  logic                   i_clk,
    input  logic                   i_rst_n,
    input  logic                   i_start,      // xung 1 chu kỳ: bắt đầu thông điệp
    input  logic                   i_enable,     // từ đầu vào hợp lệ
    input  logic                   i_block_ready,// bộ tiêu thụ đã xử lý xong o_data
    input  logic [63:0]            i_bit_length,
    input  logic [DATA_WIDTH-1:0]  i_data,

    output logic [BLOCK_SIZE-1:0]  o_data,
    output logic                   o_done,       // o_data là 1 khối hợp lệ
    output logic                   o_busy,
    output logic                   o_ready       // có thể nhận từ tiếp theo
);

    typedef enum logic [1:0] {
        IDLE,
        RECEIVE,
        PADDING,
        DONE
    } state_t;
    state_t state, nextstate;

    logic [BLOCK_SIZE-1:0] block;          // BUFFER DUY NHẤT
    logic [BLOCK_SIZE-1:0] pad_mask;
    logic [BLOCK_SIZE-1:0] pad_blk;
    logic                  pad_length;     // cần thêm khối chứa độ dài
    logic                  len_blk;        // đang ở lần PADDING thứ 2 (khối độ dài)
    logic                  last_done;      // khối đang ở DONE là khối cuối
    logic [8:0]            last_bits;
    logic [63:0]           reg_bit_length;
    logic [63:0]           total_words;
    logic [63:0]           word_cnt;
    logic [3:0]            ptr;

    // ---------------- Tham số chốt theo thông điệp ----------------
    assign last_bits   = reg_bit_length % BLOCK_SIZE;
    assign total_words = (reg_bit_length / DATA_WIDTH)
                       + (((reg_bit_length % DATA_WIDTH) != 0) ? 64'd1 : 64'd0);
    assign pad_length  = (last_bits >= (BLOCK_SIZE - 64));          // >= 448

    // word_cnt sau khi nhận đủ dữ liệu = total_words
    //   lần PADDING 1: word_cnt == total_words      -> khối đệm
    //   lần PADDING 2: word_cnt == total_words + 1  -> khối độ dài
    assign len_blk   = (word_cnt > total_words);
    assign last_done = pad_length ? (word_cnt == total_words + 64'd2)
                                  : (word_cnt == total_words + 64'd1);

    assign o_data = block;
    assign o_done = (state == DONE);
    assign o_busy = (state != IDLE);
    assign o_ready = (state == RECEIVE);

    // ---------------- Padding ----------------
    always_comb begin
        pad_mask = '0;
        pad_blk  = '0;
        if (last_bits == '0)
            pad_mask = '0;
        else
            pad_mask = {BLOCK_SIZE{1'b1}} << (BLOCK_SIZE - last_bits);

        pad_blk = (block & pad_mask) |
                  ({{(BLOCK_SIZE-1){1'b0}}, 1'b1} << (BLOCK_SIZE - 1 - last_bits));

        if (!pad_length)
            pad_blk[63:0] = reg_bit_length;
    end

    // ---------------- Máy trạng thái hữu hạn ----------------
    always_comb begin
        nextstate = state;
        case (state)
            IDLE: begin
                if (i_start) begin
                    if (i_bit_length == 64'd0)
                        nextstate = PADDING;
                    else if (i_enable && (i_bit_length <= DATA_WIDTH))
                        nextstate = PADDING;
                    else
                        nextstate = RECEIVE;
                end
            end

            RECEIVE: begin
                if (i_enable) begin
                    if ((word_cnt == total_words - 64'd1) && (last_bits != '0))
                        nextstate = PADDING;          // khối cuối chưa đầy
                    else if (ptr == 15)
                        nextstate = DONE;             // khối đầy
                end
            end

            PADDING: nextstate = DONE;

            DONE: begin
                if (i_block_ready) begin
                    if (last_done)
                        nextstate = IDLE;
                    else if (word_cnt >= total_words) // còn khối đệm / độ dài
                        nextstate = PADDING;
                    else
                        nextstate = RECEIVE;
                end
            end

            default: nextstate = IDLE;
        endcase
    end

    // ---------------- Datapath ----------------
    always_ff @(posedge i_clk) begin
        if (!i_rst_n) begin
            state          <= IDLE;
            block          <= '0;
            word_cnt       <= '0;
            ptr            <= '0;
            reg_bit_length <= '0;
        end
        else begin
            state <= nextstate;

            case (state)
                IDLE: begin
                    if (i_start) begin
                        reg_bit_length <= i_bit_length;
                        if (i_enable && (i_bit_length != 64'd0)) begin
                            // RẢNH advertises o_ready. If start and the first
                            // thì chấp nhận từ đó ngay tại cạnh này.
                            block[(16-1)*DATA_WIDTH +: DATA_WIDTH] <= i_data;
                            word_cnt <= 64'd1;
                            ptr      <= 4'd1;
                        end
                        else begin
                            word_cnt <= '0;
                            ptr      <= '0;
                        end
                    end
                end

                RECEIVE: begin
                    if (i_enable) begin
                        block[(16-1-int'(ptr))*DATA_WIDTH +: DATA_WIDTH] <= i_data;
                        word_cnt <= word_cnt + 64'd1;
                        ptr      <= (ptr == 15) ? '0 : ptr + 1'b1;
                    end
                end

                PADDING: begin
                    if (len_blk)
                        block <= {{(BLOCK_SIZE-64){1'b0}}, reg_bit_length};
                    else
                        block <= pad_blk;
                    word_cnt <= word_cnt + 64'd1;    // đánh dấu đã qua 1 lần PADDING
                end
                DONE: begin
                    // giữ nguyên block, word_cnt, reg_bit_length
                    ptr <= '0;
                end

                default: ;
            endcase
        end
    end

endmodule
