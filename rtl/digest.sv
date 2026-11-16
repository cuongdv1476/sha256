module digest #(
    parameter int DATA_WIDTH = 32
)(
    input  logic                   i_clk,
    input  logic                   i_rst_n,
    input  logic                   i_load,
    input  logic [255:0]           i_digest,
    output logic                   o_valid,
    output logic                   o_done,
    output logic [DATA_WIDTH-1:0]  o_data
);
    localparam int WORD_COUNT = 256 / DATA_WIDTH;
    localparam int COUNT_WIDTH = (WORD_COUNT > 1) ? $clog2(WORD_COUNT) : 1;

    logic [255:0] digest_reg;
    logic [COUNT_WIDTH-1:0] count;
    logic active;
    logic done_r;

    assign o_valid = active;
    assign o_done  = done_r;
    assign o_data  = digest_reg[255 - int'(count) * DATA_WIDTH -: DATA_WIDTH];

    always_ff @(posedge i_clk) begin
        if (!i_rst_n) begin
            digest_reg <= '0;
            count <= '0;
            active     <= 1'b0;
            done_r     <= 1'b0;
        end else begin
            done_r <= 1'b0;

            if (i_load && !active) begin
                digest_reg <= i_digest;
                count <= '0;
                active     <= 1'b1;
            end else if (active) begin
                if (count == WORD_COUNT - 1) begin
                    active <= 1'b0;
                    done_r <= 1'b1;
                end else begin
                    count <= count + 1'b1;
                end
            end
        end
    end
endmodule
