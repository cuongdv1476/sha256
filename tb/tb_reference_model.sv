class tb_reference_model;
    localparam bit [31:0] K [0:63] = '{
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

    function automatic bit [31:0] rotr(input bit [31:0] x, input int n);
        return (x >> n) | (x << (32 - n));
    endfunction

    function automatic bit [31:0] big_sigma0(input bit [31:0] x);
        return rotr(x, 2) ^ rotr(x, 13) ^ rotr(x, 22);
    endfunction

    function automatic bit [31:0] big_sigma1(input bit [31:0] x);
        return rotr(x, 6) ^ rotr(x, 11) ^ rotr(x, 25);
    endfunction

    function automatic bit [31:0] small_sigma0(input bit [31:0] x);
        return rotr(x, 7) ^ rotr(x, 18) ^ (x >> 3);
    endfunction

    function automatic bit [31:0] small_sigma1(input bit [31:0] x);
        return rotr(x, 17) ^ rotr(x, 19) ^ (x >> 10);
    endfunction

    function automatic bit [255:0] compute(
        input bit [31:0] words[$],
        input longint unsigned message_bit_length
    );
        bit [31:0] hash_state[0:7];
        bit [31:0] w[0:63];
        bit [31:0] a, b, c, d, e, f, g, h;
        bit [31:0] t1, t2;
        bit [511:0] padded_block;
        longint unsigned padded_bit_length;
        longint unsigned absolute_bit;
        int unsigned block_index;
        int unsigned word_index;
        int unsigned bit_index;

        if (message_bit_length > (longint'(words.size()) * 32))
            return 'x;

        padded_bit_length = ((message_bit_length + 1 + 64 + 511) / 512) * 512;

        hash_state[0] = 32'h6a09e667;
        hash_state[1] = 32'hbb67ae85;
        hash_state[2] = 32'h3c6ef372;
        hash_state[3] = 32'ha54ff53a;
        hash_state[4] = 32'h510e527f;
        hash_state[5] = 32'h9b05688c;
        hash_state[6] = 32'h1f83d9ab;
        hash_state[7] = 32'h5be0cd19;

        for (block_index = 0; block_index < padded_bit_length / 512; block_index++) begin
            padded_block = '0;

            for (bit_index = 0; bit_index < 512; bit_index++) begin
                absolute_bit = (longint'(block_index) * 512) + bit_index;

                if (absolute_bit < message_bit_length) begin
                    padded_block[511-bit_index] =
                        words[absolute_bit / 32][31 - (absolute_bit % 32)];
                end else if (absolute_bit == message_bit_length) begin
                    padded_block[511-bit_index] = 1'b1;
                end else if (absolute_bit >= padded_bit_length - 64) begin
                    padded_block[511-bit_index] =
                        (message_bit_length >> (63 - int'(absolute_bit - (padded_bit_length - 64)))) & 1'b1;
                end
            end

            for (word_index = 0; word_index < 16; word_index++)
                w[word_index] = padded_block[511 - word_index*32 -: 32];

            for (word_index = 16; word_index < 64; word_index++) begin
                w[word_index] = small_sigma1(w[word_index-2]) + w[word_index-7]
                              + small_sigma0(w[word_index-15]) + w[word_index-16];
            end

            a = hash_state[0]; b = hash_state[1];
            c = hash_state[2]; d = hash_state[3];
            e = hash_state[4]; f = hash_state[5];
            g = hash_state[6]; h = hash_state[7];

            for (int round_index = 0; round_index < 64; round_index++) begin
                t1 = h + big_sigma1(e) + ((e & f) ^ (~e & g))
                   + K[round_index] + w[round_index];
                t2 = big_sigma0(a) + ((a & b) ^ (a & c) ^ (b & c));

                h = g;
                g = f;
                f = e;
                e = d + t1;
                d = c;
                c = b;
                b = a;
                a = t1 + t2;
            end

            hash_state[0] = hash_state[0] + a;
            hash_state[1] = hash_state[1] + b;
            hash_state[2] = hash_state[2] + c;
            hash_state[3] = hash_state[3] + d;
            hash_state[4] = hash_state[4] + e;
            hash_state[5] = hash_state[5] + f;
            hash_state[6] = hash_state[6] + g;
            hash_state[7] = hash_state[7] + h;
        end

        return {hash_state[0], hash_state[1], hash_state[2], hash_state[3],
                hash_state[4], hash_state[5], hash_state[6], hash_state[7]};
    endfunction
endclass
