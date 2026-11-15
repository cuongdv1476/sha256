module digest #(
    parameter int DATA_WIDTH = 32
    )(
    input  logic         i_clk,
    input  logic         i_rst_n,
    input  logic [255:0] i_data,
    output logic [DATA_WIDTH-1:0]  o_data
);

    logic [2:0] count;

    always_ff @(posedge i_clk) begin
        if (!i_rst_n) begin
            count <= 3'd0;
            o_data     <= {DATA_WIDTH{1'b0}};
        end
        else begin
            o_data     <= i_data[255 - count*DATA_WIDTH -: DATA_WIDTH  ];
            count <= count + 1'b1;
        end
    end

endmodule
