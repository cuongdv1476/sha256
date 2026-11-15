// Functional coverage is sampled from accepted message starts/words and
// externally visible protocol events. Bins represent SHA-256 requirements;
// no implementation state encodings or catch-all digest bins are used.
class tb_coverage extends uvm_component;

    `uvm_component_utils(tb_coverage)

    int unsigned sample_count;
    int unsigned current_length;
    int unsigned previous_length;
    int unsigned word_index;
    int unsigned input_stall_cycles;
    bit message_active;
    bit previous_reset_n;
    bit previous_valid;
    int unsigned cycles_since_start;

    // Encodings are intentionally small and protocol based, not DUT state encodings.
    localparam int SIZE_EMPTY=0, SIZE_SHORT=1, SIZE_WORD=2,
                   SIZE_SINGLE=3, SIZE_MULTI=4, SIZE_LONG=5;
    localparam int PAT_ZERO=0, PAT_ONES=1, PAT_A=2, PAT_B=3,
                   PAT_MSB=4, PAT_LSB=5, PAT_W1=6, PAT_W0=7, PAT_OTHER=8;
    localparam int POS_START=0, POS_MIDDLE=1, POS_FINAL=2;

    function automatic int size_class(input bit [63:0] n);
        if (n == 0) return SIZE_EMPTY;
        if (n <= 30) return SIZE_SHORT;
        if (n <= 33) return SIZE_WORD;
        if (n <= 512) return SIZE_SINGLE;
        if (n <= 2048) return SIZE_MULTI;
        return SIZE_LONG;
    endfunction

    function automatic int data_pattern(input bit [31:0] d);
        if (d == 32'h0000_0000) return PAT_ZERO;
        if (d == 32'hffff_ffff) return PAT_ONES;
        // Keep the two bit-alternating phases separate: A = 1010..., B = 0101...
        if (d == 32'haaaa_aaaa) return PAT_A;
        if (d == 32'h5555_5555) return PAT_B;
        if (d == 32'h8000_0000) return PAT_MSB;
        if (d == 32'h0000_0001) return PAT_LSB;
        if ((d != 0) && ((d & (d-1)) == 0)) return PAT_W1;
        if (((~d) != 0) && (((~d) & ((~d)-1)) == 0)) return PAT_W0;
        return PAT_OTHER;
    endfunction

    function automatic int stall_position(input int unsigned index, input int unsigned words);
        if (index == 0) return POS_START;
        if (index + 1 >= words) return POS_FINAL;
        return POS_MIDDLE;
    endfunction

    function automatic int pattern_family(input int p);
        if (p inside {PAT_ZERO,PAT_ONES}) return 0;
        if (p inside {PAT_A,PAT_B}) return 1;
        if (p inside {PAT_MSB,PAT_LSB}) return 2;
        if (p inside {PAT_W1,PAT_W0}) return 3;
        return 4;
    endfunction

    covergroup sha256_cg with function sample(
        bit         rst_n,
        bit         i_enable,
        bit [63:0]  bit_length,
        bit [31:0]  i_data,
        bit         o_ready,
        bit         o_busy,
        bit         o_valid,
        bit         i_start_accepted,
        bit         i_word_accepted,
        bit [3:0]   reset_scenario,
        bit         input_stalled,
        int unsigned stall_run_length
    );
        option.per_instance = 1;
        option.goal = 100;

        cp_reset: coverpoint rst_n {
            bins in_reset = {0};
            bins released = {1};
            bins release_edge = (0 => 1);
        }

        cp_reset_scenario: coverpoint reset_scenario iff (!rst_n) {
            bins power_up_idle = {0};
            bins wait_block_receive = {1};
            bins block_padding = {2};
            bins schedule_expand = {3};
            bins schedule_output = {4};
            bins controller_init = {5};
            bins compression_round0 = {6};
            bins compression_round31 = {7};
            bins compression_round63 = {8};
            bins controller_check_next = {9};
            bins controller_done = {10};
        }

        cp_start_accepted: coverpoint i_start_accepted iff (rst_n) {
            bins accepted = {1};
        }

        cp_word_accept: coverpoint i_word_accepted iff (rst_n && i_enable) {
            bins accepted = {1};
            bins stalled = {0};
        }

        cp_stall_run: coverpoint stall_run_length iff (rst_n && input_stalled) {
            bins one_cycle = {1};
            bins short_stall = {[2:4]};
            bins medium_stall = {[5:16]};
            bins long_stall = {[17:$]};
        }

        // Sample the active message length during a stall so this cross
        // measures backpressure against real message sizes (not just starts).
        cp_stalled_message_size: coverpoint bit_length
            iff (rst_n && input_stalled) {
            // Backpressure on message data only occurs after the input block
            // fills and the engine processes it. Short messages have no later
            // word to stall, so they are not meaningful members of this cross.
            bins two_padded_blocks = {[513:960]};
            bins three_or_more_padded_blocks = {[961:$]};
        }
        cx_stall_size: cross cp_stalled_message_size, cp_stall_run;

        cp_status: coverpoint {o_ready, o_busy, o_valid} iff (rst_n) {
            bins idle_ready = {3'b100};
            bins busy_waiting_for_input = {3'b110};
            bins processing = {3'b010};
            bins valid_result = {3'b011};
            bins idle_to_receive = (3'b100 => 3'b110);
            bins receive_to_process = (3'b110 => 3'b010);
            bins process_to_valid = (3'b010 => 3'b011);
            bins valid_to_idle = (3'b011 => 3'b100);
        }

        cp_valid_done: coverpoint {o_valid, o_ready, o_busy}
            iff (rst_n) {
            // Actual externally visible controller combinations:
            // DONE = valid, !ready, busy; IDLE = !valid, ready, !busy.
            bins result_valid_busy = {3'b101};
            bins idle_ready = {3'b010};
        }

        cp_length: coverpoint bit_length iff (rst_n && i_start_accepted) {
            bins empty = {0};
            bins one_bit = {1};
            bins short_2_6 = {[2:6]};
            bins seven_bits = {7};
            bins byte_boundary_8 = {8};
            bins nine_bits = {9};
            bins short_10_30 = {[10:30]};
            bins word_tail_31 = {31};
            bins exact_word_32 = {32};
            bins next_word_33 = {33};
            bins word_aligned_body = {[34:446]};
            bins pad_boundary_before_448 = {447};
            bins pad_boundary_448 = {448};
            bins pad_boundary_after_448 = {449};
            bins one_block_tail = {511};
            bins exact_block = {512};
            bins next_block_bit = {513};
            bins two_block_padding_before = {895};
            bins two_block_padding_at = {896};
            bins two_block_padding_after = {897};
            bins two_block_tail = {959};
            bins two_block_boundary = {960};
            bins three_block_tail = {1023};
            bins exact_two_blocks = {1024};
            bins next_two_block_bit = {1025};
            bins multi_block_other = {[514:894], [898:958], [961:1022], [1026:$]};
        }

        cp_bit_alignment: coverpoint bit_length[2:0] iff (rst_n && i_start_accepted) {
            bins aligned_byte = {3'd0};
            bins offset_1 = {3'd1};
            bins offset_2 = {3'd2};
            bins offset_3 = {3'd3};
            bins offset_4 = {3'd4};
            bins offset_5 = {3'd5};
            bins offset_6 = {3'd6};
            bins offset_7 = {3'd7};
        }

        cp_padded_block_count: coverpoint ((bit_length + 64'd576) / 64'd512)
            iff (rst_n && i_start_accepted) {
            bins one_padded_block = {1};
            bins two_padded_blocks = {2};
            bins three_padded_blocks = {3};
            bins four_or_more = {[4:$]};
        }

        cp_padding_remainder: coverpoint (bit_length % 64'd512)
            iff (rst_n && i_start_accepted) {
            bins remainder_zero = {0};
            bins remainder_one = {1};
            bins before_length_field = {447};
            bins at_length_field_boundary = {448};
            bins after_length_field_boundary = {449};
            bins final_block_bit = {511};
            bins other_remainder = {[2:446], [450:510]};
        }

        cx_alignment_blocks: cross cp_bit_alignment, cp_padded_block_count;

        cp_data: coverpoint i_data iff (rst_n && i_word_accepted) {
            bins zero = {32'h0000_0000};
            bins ones = {32'hffff_ffff};
            bins msb_only = {32'h8000_0000};
            bins lsb_only = {32'h0000_0001};
            bins alternating_a = {32'h5555_aaaa};
            bins alternating_b = {32'haaaa_5555};
            bins structured = {
                32'h5555_5555, 32'haaaa_aaaa, 32'h0f0f_0f0f,
                32'hf0f0_f0f0, 32'h00ff_00ff, 32'hff00_ff00,
                32'hdead_beef, 32'h7fff_ffff
            };
        }

        cp_data_edges: coverpoint {i_data[31], i_data[0]}
            iff (rst_n && i_word_accepted) {
            bins b00 = {2'b00};
            bins b01 = {2'b01};
            bins b10 = {2'b10};
            bins b11 = {2'b11};
        }

        cp_valid: coverpoint o_valid iff (rst_n) {
            bins no_result = {0};
            bins result_valid = {1};
        }
    endgroup

    // Six additional groups bring the model to seven groups total. Existing
    // sha256_cg points/crosses above remain intact for historical comparability.
    covergroup message_cg with function sample(bit [63:0] len, int unsigned blocks);
        option.per_instance = 1; option.goal = 100;
        cp_size_class: coverpoint size_class(len) { bins empty={SIZE_EMPTY}; bins short_msg={SIZE_SHORT}; bins word_oriented={SIZE_WORD}; bins single_block={SIZE_SINGLE}; bins multi_block={SIZE_MULTI}; bins long_msg={SIZE_LONG}; }
        cp_padded_blocks: coverpoint blocks { bins one={1}; bins two={2}; bins three={3}; bins four_plus={[4:$]}; }
        cx_length_blocks: cross cp_size_class, cp_padded_blocks {
            ignore_bins small_multi = binsof(cp_size_class) intersect {SIZE_EMPTY,SIZE_SHORT,SIZE_WORD} && binsof(cp_padded_blocks) intersect {2,3,4};
            ignore_bins single_large = binsof(cp_size_class) intersect {SIZE_SINGLE} && binsof(cp_padded_blocks) intersect {3,4};
            ignore_bins multi_one = binsof(cp_size_class) intersect {SIZE_MULTI} && binsof(cp_padded_blocks) intersect {1};
            ignore_bins long_under_four = binsof(cp_size_class) intersect {SIZE_LONG} && binsof(cp_padded_blocks) intersect {1,2,3};
        }
    endgroup

    covergroup padding_cg with function sample(bit [63:0] len);
        option.per_instance = 1; option.goal = 100;
        cp_pad_mode: coverpoint (len % 512 >= 448) { bins one_block={0}; bins two_block={1}; }
        cp_pad_tail: coverpoint (len % 512) { bins rem_0={0}; bins rem_1_31={[1:31]}; bins rem_32_447={[32:447]}; bins rem_448_510={[448:510]}; bins rem_511={511}; }
        cp_block_edge: coverpoint (len % 512) { bins before_448={447}; bins at_448={448}; bins after_448={449}; bins before_512={511}; bins at_512={0}; bins after_512={1}; }
        cp_alignment: coverpoint (len % 8) { bins aligned={0}; bins offset1={1}; bins offset2={2}; bins offset3={3}; bins offset4={4}; bins offset5={5}; bins offset6={6}; bins offset7={7}; }
        cx_alignment_remainder: cross cp_alignment, cp_pad_tail {
            ignore_bins rem0_nonzero = binsof(cp_pad_tail.rem_0) && !binsof(cp_alignment.aligned);
            ignore_bins rem511_nonseven = binsof(cp_pad_tail.rem_511) && !binsof(cp_alignment.offset7);
        }
    endgroup

    covergroup input_data_cg with function sample(int pattern, int size, int position, bit accepted);
        option.per_instance = 1; option.goal = 100;
        cp_pattern: coverpoint pattern iff (accepted) { bins zero={PAT_ZERO}; bins ones={PAT_ONES}; bins alternating_a={PAT_A}; bins alternating_b={PAT_B}; bins msb_only={PAT_MSB}; bins lsb_only={PAT_LSB}; bins walking_one={PAT_W1}; bins walking_zero={PAT_W0}; bins random_other={PAT_OTHER}; }
        cp_data_position: coverpoint position iff (accepted) { bins first={POS_START}; bins middle={POS_MIDDLE}; bins last={POS_FINAL}; }
        cp_pattern_family: coverpoint pattern_family(pattern) iff (accepted) { bins constants={0}; bins alternating={1}; bins edge_bits={2}; bins walking={3}; bins random_data={4}; }
        cp_data_size: coverpoint size iff (accepted) { bins small_data={[SIZE_EMPTY:SIZE_SINGLE]}; bins long_message={[SIZE_MULTI:SIZE_LONG]}; }
        cx_pattern_size: cross cp_pattern_family, cp_data_size;
    endgroup

    covergroup input_protocol_cg with function sample(bit valid, bit ready, int stall_len, int position, int size);
        option.per_instance = 1; option.goal = 100;
        cp_handshake: coverpoint {valid,ready} { bins valid_ready={2'b11}; bins valid_wait={2'b10}; bins ready_idle={2'b01}; bins neither={2'b00}; }
        cp_stall_length: coverpoint stall_len iff (valid && !ready) { bins one={1}; bins multiple={[2:4]}; bins long={[5:$]}; }
        cp_stall_position: coverpoint position iff (valid && !ready) { ignore_bins start_stall_unreachable={POS_START}; bins middle={POS_MIDDLE}; bins last_word={POS_FINAL}; }
        cp_stall_size: coverpoint size iff (valid && !ready) { ignore_bins one_block_stall_unreachable={SIZE_SINGLE}; bins multi_block={SIZE_MULTI}; bins long_msg={SIZE_LONG}; }
        cx_size_stall: cross cp_stall_size, cp_stall_length;
    endgroup

    // The DUT has no output-ready input. These are pulse/latency observations;
    // output backpressure and acceptance-after-stall cannot occur on this port.
    covergroup output_protocol_cg with function sample(bit valid, bit done, int latency);
        option.per_instance = 1; option.goal = 100;
        cp_valid_done: coverpoint {valid,done} { bins inactive={2'b00}; bins pulse={2'b11}; ignore_bins mismatch={2'b01,2'b10}; }
        cp_result_latency: coverpoint latency iff (valid && done) { bins one_block_result={[1:255]}; bins multi_block_result={[256:1023]}; bins long_result={[1024:$]}; }
    endgroup

    covergroup reset_control_cg with function sample(bit rst_n, int scenario, int ctx, bit start, bit busy, bit ready, bit valid);
        option.per_instance = 1; option.goal = 100;
        cp_reset_context: coverpoint ctx iff (!rst_n) { bins idle={0}; bins input_receive={1}; bins processing={2}; bins output_pulse={3}; }
        cp_start_relation: coverpoint {start,busy,ready} iff (rst_n) {
            bins accepted_idle={3'b101};
            bins idle_no_start={3'b001};
            bins busy_no_start={3'b010,3'b011};
            ignore_bins idle_not_ready={3'b000};
            illegal_bins start_while_busy={3'b110,3'b111};
        }
        cp_control_validity: coverpoint {busy,ready,valid} iff (rst_n) { bins idle={3'b010}; bins receive={3'b110}; bins process={3'b100}; bins result={3'b101}; }
        cp_reset_phase: coverpoint scenario iff (!rst_n) { bins powerup={0}; bins receive={1}; bins processing={[2:9]}; bins done={10}; }
        cx_reset_context: cross cp_reset_phase, cp_reset_context {
            ignore_bins powerup_other = binsof(cp_reset_phase.powerup) && !binsof(cp_reset_context.idle);
            ignore_bins receive_other = binsof(cp_reset_phase.receive) && !binsof(cp_reset_context.input_receive);
            ignore_bins processing_other = binsof(cp_reset_phase.processing) && !binsof(cp_reset_context.processing);
            ignore_bins done_other = binsof(cp_reset_phase.done) && !binsof(cp_reset_context.output_pulse);
        }
    endgroup

    function new(string name, uvm_component parent);
        super.new(name, parent);
        sha256_cg = new();
        message_cg = new(); padding_cg = new(); input_data_cg = new();
        input_protocol_cg = new(); output_protocol_cg = new(); reset_control_cg = new();
    endfunction

    function void sample_cov(
        bit         rst_n,
        bit         i_enable,
        bit [63:0]  bit_length,
        bit [31:0]  i_data,
        bit         o_ready,
        bit         o_busy,
        bit         o_valid,
        bit         i_start_accepted,
        bit         i_word_accepted,
        bit [3:0]   reset_scenario,
        bit         input_stalled,
        int unsigned stall_run_length
    );
        sha256_cg.sample(
            rst_n, i_enable, bit_length, i_data,
            o_ready, o_busy, o_valid, i_start_accepted, i_word_accepted,
            reset_scenario, input_stalled, stall_run_length
        );
        sample_count++;
    endfunction

    function void sample_extended(bit rst_n, bit valid_in, bit ready_in,
        bit [63:0] len, bit [31:0] data, bit start, bit busy, bit ready,
        bit valid, bit done, bit start_accept, bit word_accept,
        bit [3:0] scenario, int unsigned stall_cycles, int unsigned latency);
        int unsigned words, blocks;
        int position, size, ctx;
        words = (len + 31) / 32;
        blocks = (len + 576) / 512;
        size = size_class(len);
        if (len > 33 && len <= 512) size = SIZE_SINGLE;
        ctx = !message_active ? 0 : (busy && ready ? 1 : (busy && !valid ? 2 : 1));
        if (valid) ctx = 3;
        position = stall_position(word_index, words);

        message_cg.sample(len, blocks);
        padding_cg.sample(len);
        input_protocol_cg.sample(valid_in, ready_in, stall_cycles, position, size);
        output_protocol_cg.sample(valid, done, latency);
        reset_control_cg.sample(rst_n, scenario, ctx, start, busy, ready, valid);
        input_data_cg.sample(data_pattern(data), size, position, word_accept);

        if (start_accept) begin
            current_length = len;
            word_index = 0;
            message_active = 1;
            cycles_since_start = 0;
        end
        else if (message_active) cycles_since_start++;
        if (word_accept) begin
            position = stall_position(word_index, words);
            word_index++;
        end
        if (rst_n && previous_reset_n && (valid && !previous_valid)) begin
            message_active = 0;
        end
        if (!rst_n) begin message_active = 0; word_index = 0; end
        previous_reset_n = rst_n;
        previous_valid = valid;
    endfunction

    function void report_phase(uvm_phase phase);
        super.report_phase(phase);
        `uvm_info("COVERAGE", $sformatf(
            "SHA-256 functional coverage = %.2f%% (samples=%0d)",
            sha256_cg.get_inst_coverage(), sample_count), UVM_NONE)
        `uvm_info("COV_DETAIL", $sformatf(
            "length=%.2f alignment=%.2f padded_blocks=%.2f remainder=%.2f align_x_blocks=%.2f reset_phase=%.2f stall_run=%.2f stall_x_size=%.2f status=%.2f valid_ready_busy=%.2f data=%.2f",
            sha256_cg.cp_length.get_coverage(),
            sha256_cg.cp_bit_alignment.get_coverage(),
            sha256_cg.cp_padded_block_count.get_coverage(),
            sha256_cg.cp_padding_remainder.get_coverage(),
            sha256_cg.cx_alignment_blocks.get_coverage(),
            sha256_cg.cp_reset_scenario.get_coverage(),
            sha256_cg.cp_stall_run.get_coverage(),
            sha256_cg.cx_stall_size.get_coverage(),
            sha256_cg.cp_status.get_coverage(),
            sha256_cg.cp_valid_done.get_coverage(),
            sha256_cg.cp_data.get_coverage()), UVM_NONE)
        `uvm_info("COV_EXT", $sformatf(
            "message=%.2f padding=%.2f data_pattern=%.2f input_protocol=%.2f output_pulse_latency=%.2f reset_control=%.2f",
            message_cg.get_inst_coverage(), padding_cg.get_inst_coverage(),
            input_data_cg.get_inst_coverage(), input_protocol_cg.get_inst_coverage(),
            output_protocol_cg.get_inst_coverage(), reset_control_cg.get_inst_coverage()), UVM_NONE)
    endfunction

endclass : tb_coverage
