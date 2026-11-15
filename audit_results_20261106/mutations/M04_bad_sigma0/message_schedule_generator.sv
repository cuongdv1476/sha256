module message_schedule_generator #(
    parameter int BLOCK_SIZE = 512,
    parameter int DATA_WIDTH = 32
) (
    input  logic                    i_clk,
    input  logic                    i_rst_n,
    input  logic                    i_enable,
    input  logic [BLOCK_SIZE-1:0]   i_data,

    output logic                    o_done,
    output logic                    o_busy,
    output logic                    o_valid,
    output logic [DATA_WIDTH-1:0]   o_data
);

    localparam int WORD_COUNT = BLOCK_SIZE / DATA_WIDTH;
    localparam int SCHEDULE = 64;

    typedef enum logic [1:0] {
        IDLE,
        EXPAND,
        OUTPUT,
        DONE
    } state_t;

    state_t state;

    logic [DATA_WIDTH-1:0] W [0:63];
    logic [5:0] count;

    function automatic logic [DATA_WIDTH-1:0] rotr(
        input logic [DATA_WIDTH-1:0] x,
        input int n
    );
        rotr = (x >> n) | (x << (DATA_WIDTH - n));
    endfunction

    function automatic logic [DATA_WIDTH-1:0] sigma0(
        input logic [DATA_WIDTH-1:0] x
    );
        sigma0 = rotr(x, 7) ^ rotr(x, 18) ^ (x >> 3);
    endfunction

    function automatic logic [DATA_WIDTH-1:0] sigma1(
        input logic [DATA_WIDTH-1:0] x
    );
        sigma1 = rotr(x, 17) ^ rotr(x, 19) ^ (x >> 10);
    endfunction

    assign o_busy  = (state != IDLE);
    assign o_done  = (state == DONE);
    assign o_valid = (state == OUTPUT);
    assign o_data  = o_valid ? W[count] : '0;

    always_ff @(posedge i_clk) begin
        if (!i_rst_n) begin
            state <= IDLE;
            count <= 6'd0;

            for (int i = 0; i < SCHEDULE; i++)
                W[i] <= '0;
        end
        else begin
            case (state)
                IDLE: begin
                    if (i_enable) begin
                        // Load the initial 16 words (MSB-first).
                        for (int i = 0; i < WORD_COUNT; i++) begin
                            W[i] <= i_data[BLOCK_SIZE-1-i*DATA_WIDTH -: DATA_WIDTH];
                        end

                        count <= 6'd16;
                        state <= EXPAND;
                    end
                end

                EXPAND: begin
                    // Generate W[16] through W[63].
                    W[count] <= W[count-16] + sigma0(W[count-15]) + W[count-7] + sigma1(W[count-2]);

                    if (count == 6'd63) begin
                        count <= 6'd0;
                        state <= OUTPUT;
                    end
                    else begin
                        count <= count + 6'd1;
                    end
                end

                OUTPUT: begin
                    if (count == 6'd63) begin
                        state <= DONE;
                        count <= 6'd0;
                    end
                    else begin
                        count <= count + 6'd1;
                    end
                end

                DONE: begin
                    state <= IDLE;
                end

                default: begin
                    state <= IDLE;
                    count <= 6'd0;
                end

            endcase
        end
    end

endmodule
