// Shared UVM sequence utilities. Test scenarios live in ../tc.
class sha256_base_sequence extends uvm_sequence #(sha256_transaction);
    `uvm_object_utils(sha256_base_sequence)

    localparam int PATTERN_ZERO       = 0;
    localparam int PATTERN_ONE        = 1;
    localparam int PATTERN_AA         = 2;
    localparam int PATTERN_55         = 3;
    localparam int PATTERN_WALKING_1  = 4;
    localparam int PATTERN_WALKING_0  = 5;
    localparam int PATTERN_INCREASING = 6;
    localparam int PATTERN_DECREASING = 7;
    localparam int PATTERN_SAME_BLOCK = 8;
    localparam int PATTERN_BLOCK_ID   = 9;
    localparam int PATTERN_RANDOM     = 10;
    localparam int MAX_WAIT_CYCLES    = 20000;

    virtual sha256_if vif;

    function new(string name = "sha256_base_sequence");
        super.new(name);
    endfunction

    task automatic setup_vif();
        if (!uvm_config_db#(virtual sha256_if)::get(
                m_sequencer, "", "vif", vif)) begin
            `uvm_fatal("SEQ", "Cannot get SHA-256 virtual interface")
        end
    endtask

    task automatic send_cycle(
        bit rst_n,
        bit start,
        bit enable,
        bit [63:0] bit_length,
        bit [31:0] data,
        bit [3:0] cov_reset_scenario = 0,
        bit cov_expect_error = 0
    );
        sha256_transaction tr;
        tr = sha256_transaction::type_id::create("tr");
        start_item(tr);
        tr.i_rst_n      = rst_n;
        tr.i_start      = start;
        tr.i_enable     = enable;
        tr.i_bit_length = bit_length;
        tr.i_data       = data;
        tr.cov_reset_scenario = cov_reset_scenario;
        tr.cov_expect_error = cov_expect_error;
        finish_item(tr);
    endtask

    task automatic wait_idle();
        for (int unsigned cycle = 0; cycle < MAX_WAIT_CYCLES; cycle++) begin
            send_cycle(1, 0, 0, 0, 0);
            #1ps;
            if (vif.ready && !vif.busy)
                return;
        end
        `uvm_fatal("SEQ_TIMEOUT", "Timed out waiting for DUT idle/ready")
    endtask

    task automatic wait_done(input string case_id);
        for (int unsigned cycle = 0; cycle < MAX_WAIT_CYCLES; cycle++) begin
            send_cycle(1, 0, 0, 0, 0);
            #1ps;
            if (vif.done)
                return;
        end
        `uvm_fatal("SEQ_TIMEOUT", $sformatf(
            "%s timed out waiting for digest done", case_id))
    endtask

    task automatic wait_valid(input string case_id);
        for (int unsigned cycle = 0; cycle < MAX_WAIT_CYCLES; cycle++) begin
            send_cycle(1, 0, 0, 0, 0);
            #1ps;
            if (vif.valid)
                return;
        end
        `uvm_fatal("SEQ_TIMEOUT", $sformatf(
            "%s timed out waiting for digest valid", case_id))
    endtask

    function automatic bit [31:0] make_pattern_word(
        input int pattern,
        input int unsigned word_index
    );
        int unsigned bit_position;
        int unsigned block_index;
        bit [31:0] walking_bit;

        bit_position = word_index % 32;
        block_index = word_index / 16;
        walking_bit = 32'h0000_0001 << bit_position;

        case (pattern)
            PATTERN_ZERO:       return 32'h0000_0000;
            PATTERN_ONE:        return 32'hffff_ffff;
            PATTERN_AA:         return 32'haaaa_aaaa;
            PATTERN_55:         return 32'h5555_5555;
            PATTERN_WALKING_1:  return walking_bit;
            PATTERN_WALKING_0:  return ~walking_bit;
            PATTERN_INCREASING: return 32'h0102_0304 + word_index;
            PATTERN_DECREASING: return 32'hf0e0_d0c0 - word_index;
            PATTERN_SAME_BLOCK: return 32'ha5a5_5a5a;
            PATTERN_BLOCK_ID:   return 32'h9e37_79b9 * (block_index + 1)
                                      + 32'h0101_0101 * (word_index % 16);
            default:            return $urandom();
        endcase
    endfunction

    task automatic run_message(
        input string case_id,
        input longint unsigned bit_length,
        input bit [31:0] message_words[$],
        input bit insert_gaps = 0
    );
        int unsigned gap_cycles;

        `uvm_info("TESTCASE", $sformatf(
            "START %s: %0d message bits, %0d input words%s",
            case_id, bit_length, message_words.size(),
            insert_gaps ? ", input gaps enabled" : ""), UVM_LOW)

        wait_idle();

        if (message_words.size() == 0) begin
            send_cycle(1, 1, 0, bit_length, '0);
        end else begin
            send_cycle(1, 1, 1, bit_length, message_words[0]);

            for (int unsigned word_index = 1;
                 word_index < message_words.size();
                 word_index++) begin
                if (insert_gaps) begin
                    gap_cycles = $urandom_range(0, 2);
                    repeat (gap_cycles)
                        send_cycle(1, 0, 0, bit_length, '0);
                end

                send_cycle(1, 0, 1, bit_length, message_words[word_index]);
            end
        end

        wait_done(case_id);
        `uvm_info("TESTCASE", $sformatf("PASS %s", case_id), UVM_LOW)
    endtask

    task automatic run_generated_case(
        input string case_id,
        input longint unsigned bit_length,
        input int pattern,
        input bit insert_gaps = 0
    );
        bit [31:0] words[$];
        int unsigned word_count;

        word_count = (bit_length + 31) / 32;
        for (int unsigned word_index = 0; word_index < word_count; word_index++)
            words.push_back(make_pattern_word(pattern, word_index));

        run_message(case_id, bit_length, words, insert_gaps);
    endtask

    task automatic reset_dut(
        input int unsigned cycles = 2,
        input bit [3:0] cov_reset_scenario = 0
    );
        repeat (cycles)
            send_cycle(0, 0, 0, 0, 0, cov_reset_scenario);
        send_cycle(1, 0, 0, 0, 0);
        wait_idle();
    endtask
endclass
