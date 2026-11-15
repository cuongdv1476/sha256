module compression #(
    parameter int DATA_WIDTH = 32
) (
    input  logic                       i_clk,
    input  logic                       i_rst_n,

    input  logic                       i_init,
    input  logic                       i_enable,
    input  logic [DATA_WIDTH-1:0]      i_data,

    output logic                       o_busy,
    output logic [7:0][DATA_WIDTH-1:0] o_data,
    output logic                       o_done
);

    // =========================================================
    // 2. SHA-256 INITIAL HASH VALUES
    // =========================================================

    localparam logic [31:0] H0 = 32'h6a09e667;
    localparam logic [31:0] H1 = 32'hbb67ae85;
    localparam logic [31:0] H2 = 32'h3c6ef372;
    localparam logic [31:0] H3 = 32'ha54ff53a;
    localparam logic [31:0] H4 = 32'h510e527f;
    localparam logic [31:0] H5 = 32'h9b05688c;
    localparam logic [31:0] H6 = 32'h1f83d9ab;
    localparam logic [31:0] H7 = 32'h5be0cd19;


    // =========================================================
    // 3. SHA-256 ROUND CONSTANTS
    // =========================================================

    localparam logic [31:0] K [0:63] = '{
        32'h428a2f98, 32'h71374491, 32'hb5c0fbcf, 32'he9b5dba5,
        32'h3956c25b, 32'h59f111f1, 32'h923f82a4, 32'hab1c5ed5,
        32'hd807aa98, 32'h12835b01, 32'h243185be, 32'h550c7dc3,
        32'h72be5d74, 32'h80deb1fe, 32'h9bdc06a7, 32'hc19bf174,
        32'he49b69c1, 32'hefbe4786, 32'h0fc19dc6, 32'h240ca1cc,
        32'h2de92c6f, 32'h4a7484aa, 32'h5cb0a9dc, 32'h76f988da,
        32'h983e5152, 32'ha831c66d, 32'hb00327c8, 32'hbf597fc7,
        32'hc6e00bf3, 32'hd5a79147, 32'h06ca6351, 32'h14292967,
        32'h27b70a85, 32'h2e1b2138, 32'h4d2c6dfc, 32'h53380d13,
        32'h650a7354, 32'h766a0abb, 32'h81c2c92e, 32'h92722c85,
        32'ha2bfe8a1, 32'ha81a664b, 32'hc24b8b70, 32'hc76c51a3,
        32'hd192e819, 32'hd6990624, 32'hf40e3585, 32'h106aa070,
        32'h19a4c116, 32'h1e376c08, 32'h2748774c, 32'h34b0bcb5,
        32'h391c0cb3, 32'h4ed8aa4a, 32'h5b9cca4f, 32'h682e6ff3,
        32'h748f82ee, 32'h78a5636f, 32'h84c87814, 32'h8cc70208,
        32'h90befffa, 32'ha4506ceb, 32'hbef9a3f7, 32'hc67178f2
    };


    // =========================================================
    // 4. FSM
    // =========================================================

    typedef enum logic {
        IDLE  = 1'b0,
        ROUND = 1'b1
    } state_t;

    state_t state;


    // =========================================================
    // 5. REGISTERS
    // =========================================================

    logic [DATA_WIDTH-1:0] H [0:7];

    logic [DATA_WIDTH-1:0] a, b, c, d;
    logic [DATA_WIDTH-1:0] e, f, g, h;

    logic [5:0] round_cnt;

    logic [DATA_WIDTH-1:0] t1, t2;


    // =========================================================
    // 6. SHA-256 FUNCTIONS
    // =========================================================

    // Right Rotate
    function automatic logic [DATA_WIDTH-1:0] rotr(
        input logic [DATA_WIDTH-1:0] x,
        input int n
    );
        return (x >> n) | (x << (DATA_WIDTH - n));
    endfunction


    // Choose
    function automatic logic [DATA_WIDTH-1:0] ch(
        input logic [DATA_WIDTH-1:0] x, y, z
    );
        return (x & y) ^ (~x & z);
    endfunction


    // Majority
    function automatic logic [DATA_WIDTH-1:0] maj(
        input logic [DATA_WIDTH-1:0] x, y, z
    );
        return (x & y) ^ (x & z) ^ (y & z);
    endfunction


    // Big Sigma 0
    function automatic logic [DATA_WIDTH-1:0] sigma0(
        input logic [DATA_WIDTH-1:0] x
    );
        return rotr(x, 2) ^ rotr(x, 13) ^ rotr(x, 22);
    endfunction


    // Big Sigma 1
    function automatic logic [DATA_WIDTH-1:0] sigma1(
        input logic [DATA_WIDTH-1:0] x
    );
        return rotr(x, 6) ^ rotr(x, 11) ^ rotr(x, 25);
    endfunction


    // =========================================================
    // 7. TEMPORARY VARIABLES
    // =========================================================

    assign t1 = h + sigma1(e) + ch(e, f, g) + K[round_cnt] + i_data;

    assign t2 = sigma0(a) + maj(a, b, c);


    // =========================================================
    // 8. STATUS SIGNALS
    // =========================================================

    assign o_busy = (state == ROUND);


    // =========================================================
    // 9. MAIN FSM AND COMPRESSION LOGIC
    // =========================================================

    always_ff @(posedge i_clk) begin

        if (!i_rst_n) begin

            // FSM
            state <= IDLE;

            // Initial Hash Values
            H[0] <= H0;
            H[1] <= H1;
            H[2] <= H2;
            H[3] <= H3;
            H[4] <= H4;
            H[5] <= H5;
            H[6] <= H6;
            H[7] <= H7;

            // Working Variables
            a <= 32'h0;
            b <= 32'h0;
            c <= 32'h0;
            d <= 32'h0;
            e <= 32'h0;
            f <= 32'h0;
            g <= 32'h0;
            h <= 32'h0;

            // Round Counter
            round_cnt <= 6'd0;

            // Output
            o_done <= 1'b0;

        end

        else begin

            // Default: one-cycle done pulse
            o_done <= 1'b0;

            case (state)

                // -------------------------------------------------
                // IDLE
                // -------------------------------------------------

                IDLE: begin

                    // Initialize a new message
                    if (i_init) begin

                        H[0] <= H0;
                        H[1] <= H1;
                        H[2] <= H2;
                        H[3] <= H3;
                        H[4] <= H4;
                        H[5] <= H5;
                        H[6] <= H6;
                        H[7] <= H7;

                    end

                    // Start compression
                    else if (i_enable) begin

                        // Load Hash Values
                        a <= H[0];
                        b <= H[1];
                        c <= H[2];
                        d <= H[3];

                        e <= H[4];
                        f <= H[5];
                        g <= H[6];
                        h <= H[7];

                        // Initialize Round Counter
                        round_cnt <= 6'd0;

                        // Start
                        state <= ROUND;

                    end

                end


                // -------------------------------------------------
                // ROUND
                // -------------------------------------------------

                ROUND: begin

                    // Update Working Variables
                    h <= g;
                    g <= f;
                    f <= e;
                    e <= d + t1;

                    d <= c;
                    c <= b;
                    b <= a;
                    a <= t1 + t2;


                    // -------------------------------------------------
                    // FINAL ROUND
                    // -------------------------------------------------

                    if (round_cnt == 6'd63) begin

                        // Feed-forward
                        H[0] <= H[0] + t1 + t2;
                        H[1] <= H[1] + a;
                        H[2] <= H[2] + b;
                        H[3] <= H[3] + c;

                        H[4] <= H[4] + d + t1;
                        H[5] <= H[5] + e;
                        H[6] <= H[6] + f;
                        H[7] <= H[7] + g;

                        // Return to IDLE
                        state <= IDLE;

                        // Completion Pulse
                        o_done <= 1'b1;

                    end

                    else begin

                        // Next Round
                        round_cnt <= (round_cnt == 6'd10) ? round_cnt : round_cnt + 1'b1;

                    end

                end


                // -------------------------------------------------
                // DEFAULT
                // -------------------------------------------------

                default: begin

                    state <= IDLE;
                    round_cnt <= 6'd0;

                end

            endcase

        end

    end


    // =========================================================
    // 10. OUTPUT HASH VALUES
    // =========================================================

    assign o_data[0] = H[0];
    assign o_data[1] = H[1];
    assign o_data[2] = H[2];
    assign o_data[3] = H[3];

    assign o_data[4] = H[4];
    assign o_data[5] = H[5];
    assign o_data[6] = H[6];
    assign o_data[7] = H[7];

endmodule
