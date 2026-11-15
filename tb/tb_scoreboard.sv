// =============================================================
// tb_scoreboard
//   1. Thu cac word i_data (khi i_enable = 1) -> tao message
//   2. Tinh EXPECTED digest bang reference model SHA-256 (bit-level)
//   3. Khi DUT bao o_valid (canh len) -> so sanh o_digest voi expected
//        - Giong nhau  -> PASS
//        - Khac nhau   -> FAIL (uvm_error)
//
// GIA DINH GIAO THUC (sua trong write() neu DUT khac):
//   - Message bat dau o chu ky i_enable = 1 dau tien; bit_length lay o chu ky do.
//   - Moi chu ky i_enable = 1 dua vao 1 word 32-bit i_data (word dau la
//     phan dau cua message, bit MSB di truoc / big-endian).
//   - Word cuoi neu khong du 32 bit: cac bit hop le nam o phan MSB (can trai).
//   - DUT tu padding SHA-256 theo bit_length.
//   - bit_length = 0: chi can mot xung i_enable de bat dau (khong co word du lieu).
//   - Digest duoc so sanh tai canh len cua o_valid.
// =============================================================
class tb_scoreboard extends uvm_scoreboard;

    `uvm_component_utils(tb_scoreboard)

    // =========================================================
    // ANALYSIS IMP (noi voi tb_monitor.ap)
    // =========================================================
    uvm_analysis_imp #(tb_transaction, tb_scoreboard) ap_imp;

    // =========================================================
    // CONFIG
    // =========================================================
    int unsigned MAX_MSG_WORDS = 1 << 20;   // chan bit_length rac

    // =========================================================
    // TRANG THAI THU MESSAGE
    // =========================================================
    bit             collecting;             // dang gom word cua 1 message
    bit [63:0]      cur_bit_length;
    bit [31:0]      cur_words[$];
    int unsigned    needed_words;
    bit             prev_valid;
    bit             prev_stall;
    bit [31:0]       stalled_data;
    int unsigned    stall_cycles;
    int unsigned    max_stall_cycles;
    int unsigned    stall_events;

    // =========================================================
    // THONG KE
    // =========================================================
    int unsigned    msg_count   = 0;
    int unsigned    pass_count  = 0;
    int unsigned    fail_count  = 0;
    int unsigned    err_count   = 0;        // loi giao thuc (valid bat ngo, thieu word...)
    int unsigned    messages_started;
    int unsigned    messages_completed;
    int unsigned    messages_aborted;
    int unsigned    messages_digest_compared;
    int unsigned    messages_pending;
    int unsigned    active_message_id;

    // Hang so SHA-256
    bit [31:0] K [64];
    bit [31:0] H_INIT [8];


    // =========================================================
    // CONSTRUCTOR
    // =========================================================
    function new(string name, uvm_component parent);
        super.new(name, parent);
        ap_imp = new("ap_imp", this);
        init_constants();
    endfunction


    // =========================================================
    // REFERENCE MODEL: HANG SO
    // =========================================================
    function void init_constants();
        K = '{
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
        H_INIT = '{
            32'h6a09e667, 32'hbb67ae85, 32'h3c6ef372, 32'ha54ff53a,
            32'h510e527f, 32'h9b05688c, 32'h1f83d9ab, 32'h5be0cd19
        };
    endfunction


    // =========================================================
    // REFERENCE MODEL: HAM PHU
    // =========================================================
    function automatic bit [31:0] rotr(bit [31:0] x, int unsigned n);
        return (x >> n) | (x << (32 - n));
    endfunction

    // Tinh SHA-256 cho message co do dai bang dung so bit trong queue
    // (padding o muc bit -> ho tro ca bit_length khong chia het cho 8)
    function bit [255:0] sha256_bits(bit msg_bits[$]);

        bit          padded[$];
        bit [63:0]   len_bits;
        bit [31:0]   H [8];
        bit [31:0]   W [64];
        bit [31:0]   a, b, c, d, e, f, g, h;
        bit [31:0]   s0, s1, S0, S1, ch, maj, t1, t2;
        int unsigned num_blocks;

        len_bits = msg_bits.size();

        // ---- Padding: message | 1 | 0...0 | length (64 bit) ----
        padded = msg_bits;
        padded.push_back(1'b1);
        while ((padded.size() % 512) != 448)
            padded.push_back(1'b0);
        for (int i = 63; i >= 0; i--)
            padded.push_back(len_bits[i]);

        num_blocks = padded.size() / 512;
        H = H_INIT;

        // ---- Xu ly tung block 512 bit ----
        for (int blk = 0; blk < num_blocks; blk++) begin

            // Message schedule
            for (int t = 0; t < 16; t++) begin
                for (int i = 31; i >= 0; i--)
                    W[t][i] = padded[blk*512 + t*32 + (31 - i)];
            end
            for (int t = 16; t < 64; t++) begin
                s0   = rotr(W[t-15], 7) ^ rotr(W[t-15], 18) ^ (W[t-15] >> 3);
                s1   = rotr(W[t-2], 17) ^ rotr(W[t-2], 19)  ^ (W[t-2]  >> 10);
                W[t] = W[t-16] + s0 + W[t-7] + s1;
            end

            {a, b, c, d, e, f, g, h} = {H[0], H[1], H[2], H[3],
                                        H[4], H[5], H[6], H[7]};

            // 64 vong nen
            for (int t = 0; t < 64; t++) begin
                S1  = rotr(e, 6) ^ rotr(e, 11) ^ rotr(e, 25);
                ch  = (e & f) ^ (~e & g);
                t1  = h + S1 + ch + K[t] + W[t];
                S0  = rotr(a, 2) ^ rotr(a, 13) ^ rotr(a, 22);
                maj = (a & b) ^ (a & c) ^ (b & c);
                t2  = S0 + maj;

                h = g;
                g = f;
                f = e;
                e = d + t1;
                d = c;
                c = b;
                b = a;
                a = t1 + t2;
            end

            H[0] = H[0] + a;  H[1] = H[1] + b;
            H[2] = H[2] + c;  H[3] = H[3] + d;
            H[4] = H[4] + e;  H[5] = H[5] + f;
            H[6] = H[6] + g;  H[7] = H[7] + h;
        end

        return {H[0], H[1], H[2], H[3], H[4], H[5], H[6], H[7]};

    endfunction


    // =========================================================
    // EXPECTED DATA: tu cac word thu duoc + bit_length -> digest
    // =========================================================
    function bit [255:0] compute_expected(
        bit [63:0] bit_length,
        bit [31:0] words[$]
    );
        bit msg_bits[$];
        bit [63:0] n;

        n = 0;
        foreach (words[w]) begin
            for (int i = 31; i >= 0; i--) begin
                if (n < bit_length) begin
                    msg_bits.push_back(words[w][i]);
                    n++;
                end
            end
        end

        return sha256_bits(msg_bits);
    endfunction


    // =========================================================
    // TU KIEM TRA REFERENCE MODEL (vector chuan NIST)
    // =========================================================
    function void start_of_simulation_phase(uvm_phase phase);

        bit msg_bits[$];
        bit [255:0] exp_empty, exp_abc, got, exp;
        bit [7:0]   abc [3];

        super.start_of_simulation_phase(phase);

        exp_empty = 256'he3b0c442_98fc1c14_9afbf4c8_996fb924_27ae41e4_649b934c_a495991b_7852b855;
        exp_abc   = 256'hba7816bf_8f01cfea_414140de_5dae2223_b00361a3_96177a9c_b410ff61_f20015ad;

        // "" (message rong)
        msg_bits.delete();
        got = sha256_bits(msg_bits);
        if (got !== exp_empty)
            `uvm_fatal("SCB_REF", $sformatf(
                "Reference model SAI voi message rong: got=%064h exp=%064h", got, exp_empty))

        // "abc"
        abc = '{8'h61, 8'h62, 8'h63};
        msg_bits.delete();
        foreach (abc[k])
            for (int i = 7; i >= 0; i--)
                msg_bits.push_back(abc[k][i]);
        got = sha256_bits(msg_bits);
        if (got !== exp_abc)
            `uvm_fatal("SCB_REF", $sformatf(
                "Reference model SAI voi \"abc\": got=%064h exp=%064h", got, exp_abc))

        // KATs generated by verification/sha256_independent_oracle.py.
        // The independent Python implementation cross-checks byte-aligned
        // cases against hashlib; these constants exercise bit-level padding.
        msg_bits = '{1'b1};
        exp = 256'hb9debf7d52f36e6468a54817c1fa071166c3a63d384850e1575b42f702dc5aa1;
        got = sha256_bits(msg_bits);
        if (got !== exp)
            `uvm_fatal("SCB_REF", $sformatf("1-bit KAT mismatch: got=%064h exp=%064h", got, exp))

        msg_bits = '{1'b1,1'b0,1'b1,1'b1,1'b0,1'b1,1'b0,1'b0,1'b1};
        exp = 256'h8b85c2f30c45a412b2b5a0ee7ecdf4bf260946956a46caa5435fa586b3dbf39a;
        got = sha256_bits(msg_bits);
        if (got !== exp)
            `uvm_fatal("SCB_REF", $sformatf("9-bit KAT mismatch: got=%064h exp=%064h", got, exp))

        for (int n = 447; n <= 449; n++) begin
            msg_bits.delete();
            for (int i = 0; i < n; i++)
                msg_bits.push_back(((i*17 + (i>>3)*5) ^ (i>>1)) & 1);
            case (n)
                447: exp = 256'hadb5a40bc91d819c33173e1b67f259ce38c483dfa581fe210f6f4b3508d67c6e;
                448: exp = 256'hfd93eac6f7f6d1336114a3bb1ff25a81fb768da7efa3aa5c5b1c720828fed782;
                default: exp = 256'h768d97e234734ff332b305f1ea5a3888024f932f722afe07934f96592548ff48;
            endcase
            got = sha256_bits(msg_bits);
            if (got !== exp)
                `uvm_fatal("SCB_REF", $sformatf(
                    "%0d-bit padding KAT mismatch: got=%064h exp=%064h", n, got, exp))
        end

        msg_bits.delete();
        for (int i = 0; i < 1024; i++)
            msg_bits.push_back(((i*17 + (i>>3)*5) ^ (i>>1)) & 1);
        exp = 256'hf973b8c60f03f7040d52adc10c4a464d919211a2a2c146cc5f0b3f6a6196eae3;
        got = sha256_bits(msg_bits);
        if (got !== exp)
            `uvm_fatal("SCB_REF", $sformatf("1024-bit chaining KAT mismatch: got=%064h exp=%064h", got, exp))

        `uvm_info("SCB_REF", "Reference model PASS: empty, abc, 1/9-bit, 447/448/449-bit padding and 1024-bit chaining KATs", UVM_LOW)

    endfunction


    // =========================================================
    // WRITE: nhan transaction tu monitor moi chu ky
    // =========================================================
    function void write(tb_transaction tr);

        bit [255:0] expected;

        if (!tr.rst_n) begin
            if (collecting) begin
                messages_aborted++;
                if (messages_pending == 0)
                    begin
                    `uvm_error("SCB_ACCOUNT", $sformatf(
                        "Pending count underflow while aborting message id=%0d", active_message_id))
                    err_count++;
                    end
                else
                    messages_pending--;
                `uvm_info("SCB_ABORT", $sformatf(
                    "Message id=%0d aborted by reset after %0d/%0d words",
                    active_message_id, cur_words.size(), needed_words), UVM_LOW)
            end
            collecting = 0;
            cur_words.delete();
            prev_valid = 0;
            prev_stall = 0;
            stall_cycles = 0;
            return;
        end

        // ---------- 1. Thu input ----------
        if (tr.i_start && !tr.i_start_accepted) begin
            `uvm_error("SCB_PROTO", "i_start asserted outside sha_top IDLE/ready state")
            err_count++;
        end

        if (prev_stall && (!tr.i_enable || tr.i_data !== stalled_data)) begin
            `uvm_error("SCB_PROTO", "i_enable/i_data changed before stalled word was accepted")
            err_count++;
        end
        // A simultaneous enable on a zero-length start is intentionally
        // ignored by the block buffer and is not a stalled payload word.
        prev_stall = tr.i_enable && !tr.i_word_accepted
                   && !(tr.i_start_accepted && (tr.bit_length == 0));
        if (prev_stall) begin
            stalled_data = tr.i_data;
            stall_cycles++;
        end
        else begin
            if (stall_cycles != 0) begin
                stall_events++;
                if (stall_cycles > max_stall_cycles)
                    max_stall_cycles = stall_cycles;
            end
            stall_cycles = 0;
        end

        if (tr.o_valid !== tr.o_done) begin
            `uvm_error("SCB_PROTO", $sformatf(
                "RTL status mismatch: o_valid=%0b o_done=%0b", tr.o_valid, tr.o_done))
            err_count++;
        end
        if (tr.o_error) begin
            `uvm_error("SCB_PROTO", "sha_top asserted o_error")
            err_count++;
        end

        if (tr.i_start_accepted) begin
            if (collecting) begin
                `uvm_error("SCB_ACCOUNT", $sformatf(
                    "New message start while message id=%0d is pending", active_message_id))
                err_count++;
                messages_aborted++;
                if (messages_pending != 0)
                    messages_pending--;
            end
            collecting     = 1;
            cur_bit_length = tr.bit_length;
            cur_words.delete();
            needed_words   = (tr.bit_length + 31) / 32;
            messages_started++;
            active_message_id = messages_started;
            messages_pending++;
            `uvm_info("SCB_START", $sformatf(
                "Message id=%0d started bit_length=%0d", active_message_id, cur_bit_length), UVM_LOW)
        end

        if (tr.i_word_accepted && collecting) begin
            if (cur_words.size() < needed_words)
                cur_words.push_back(tr.i_data);
            else
                `uvm_warning("SCB_PROTO", $sformatf(
                    "Nhan them word i_data=%08h khi message da du %0d word (bo qua)",
                    tr.i_data, needed_words))
        end

        // ---------- 2. Kiem tra output tai canh len o_valid ----------
        if (tr.o_valid && !prev_valid) begin

            if (!collecting) begin
                // o_valid ma khong co message nao dang xu ly
                `uvm_error("SCB_FAIL", $sformatf(
                    "FAIL: o_valid len bat ngo (khong co message), o_digest=%064h",
                    tr.o_digest))
                err_count++;
                fail_count++;
            end
            else if (cur_words.size() < needed_words) begin
                // DUT bao xong khi chua nhan du du lieu
                `uvm_error("SCB_FAIL", $sformatf(
                    "FAIL: o_valid len khi moi nhan %0d/%0d word (bit_length=%0d)",
                    cur_words.size(), needed_words, cur_bit_length))
                err_count++;
                fail_count++;
                messages_completed++;
                if (messages_pending == 0)
                    begin
                    `uvm_error("SCB_ACCOUNT", $sformatf(
                        "Pending count underflow completing incomplete message id=%0d", active_message_id))
                    err_count++;
                    end
                else
                    messages_pending--;
                collecting = 0;
            end
            else begin
                messages_completed++;
                if (messages_pending == 0)
                    begin
                    `uvm_error("SCB_ACCOUNT", $sformatf(
                        "Pending count underflow completing message id=%0d", active_message_id))
                    err_count++;
                    end
                else
                    messages_pending--;

                msg_count++;

                // Expected data
                expected = compute_expected(cur_bit_length, cur_words);

                // So sanh
                messages_digest_compared++;
                if (tr.o_digest === expected) begin
                    pass_count++;
                    `uvm_info("SCB_PASS", $sformatf(
                        "PASS id=%0d msg#%0d bit_length=%0d\n  EXPECTED = %064h\n  ACTUAL   = %064h",
                        active_message_id, msg_count, cur_bit_length, expected, tr.o_digest), UVM_LOW)
                end
                else begin
                    fail_count++;
                    `uvm_error("SCB_FAIL", $sformatf(
                        "FAIL id=%0d msg#%0d bit_length=%0d\n  EXPECTED = %064h\n  ACTUAL   = %064h",
                        active_message_id, msg_count, cur_bit_length, expected, tr.o_digest))
                end

                collecting = 0;
                cur_words.delete();
            end

        end

        prev_valid = tr.o_valid;

    endfunction


    // =========================================================
    // CHECK PHASE: message dang do khi ket thuc test
    // =========================================================
    function void check_phase(uvm_phase phase);
        super.check_phase(phase);

        if (collecting) begin
            `uvm_error("SCB_FAIL", $sformatf(
                "FAIL: ket thuc test nhung message (bit_length=%0d, nhan %0d/%0d word) chua co o_valid",
                cur_bit_length, cur_words.size(), needed_words))
            err_count++;
        end

        if (messages_started != messages_completed + messages_aborted + messages_pending) begin
            `uvm_error("SCB_ACCOUNT", $sformatf(
                "Message accounting mismatch: started=%0d completed=%0d aborted=%0d pending=%0d",
                messages_started, messages_completed, messages_aborted, messages_pending))
            err_count++;
        end
        if (messages_pending != 0) begin
            `uvm_error("SCB_ACCOUNT", $sformatf(
                "%0d message(s) remain pending at end of test", messages_pending))
            err_count++;
        end
        if (messages_completed != messages_digest_compared) begin
            `uvm_error("SCB_ACCOUNT", $sformatf(
                "Completed/compared mismatch: completed=%0d compared=%0d",
                messages_completed, messages_digest_compared))
            err_count++;
        end
    endfunction


    // =========================================================
    // REPORT PHASE
    // =========================================================
    function void report_phase(uvm_phase phase);
        super.report_phase(phase);

        `uvm_info("SCB", "================ SCOREBOARD SUMMARY ================", UVM_NONE)
        `uvm_info("SCB", $sformatf("Messages checked : %0d", msg_count),  UVM_NONE)
        `uvm_info("SCB", $sformatf(
            "Message accounting: started=%0d completed=%0d aborted=%0d digest_compared=%0d pending=%0d",
            messages_started, messages_completed, messages_aborted,
            messages_digest_compared, messages_pending), UVM_NONE)
        `uvm_info("SCB", $sformatf("PASS             : %0d", pass_count), UVM_NONE)
        `uvm_info("SCB", $sformatf("FAIL             : %0d", fail_count), UVM_NONE)
        `uvm_info("SCB", $sformatf("Protocol errors  : %0d", err_count),  UVM_NONE)
        `uvm_info("SCB", $sformatf("Input stalls     : %0d (max=%0d cycles)",
                                    stall_events, max_stall_cycles), UVM_NONE)

        if (fail_count == 0 && err_count == 0 && pass_count > 0)
            `uvm_info("SCB", "*** TEST PASSED ***", UVM_NONE)
        else if (pass_count == 0 && fail_count == 0 && err_count == 0)
            `uvm_error("SCB", "*** TEST FAILED *** (khong co digest nao duoc kiem tra)")
        else
            `uvm_error("SCB", "*** TEST FAILED ***")
    endfunction

endclass : tb_scoreboard
