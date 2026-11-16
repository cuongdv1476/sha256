class sha256_sequence extends sha256_base_sequence;
    `uvm_object_utils(sha256_sequence)

    function new(string name = "sha256_sequence");
        super.new(name);
    endfunction

    task body();
        sha256_reset_sequence reset_seq;
        sha256_basic_sequence basic_seq;
        sha256_boundary_padding_sequence boundary_seq;
        sha256_multiblock_sequence multiblock_seq;
        sha256_pattern_sequence pattern_seq;
        sha256_protocol_sequence protocol_seq;
        sha256_transaction_sequence transaction_seq;
        sha256_random_sequence random_seq;

        setup_vif();

        reset_seq = sha256_reset_sequence::type_id::create("reset_seq");
        reset_seq.start(m_sequencer);
        basic_seq = sha256_basic_sequence::type_id::create("basic_seq");
        basic_seq.start(m_sequencer);
        boundary_seq = sha256_boundary_padding_sequence::type_id::create("boundary_seq");
        boundary_seq.start(m_sequencer);
        multiblock_seq = sha256_multiblock_sequence::type_id::create("multiblock_seq");
        multiblock_seq.start(m_sequencer);
        pattern_seq = sha256_pattern_sequence::type_id::create("pattern_seq");
        pattern_seq.start(m_sequencer);
        protocol_seq = sha256_protocol_sequence::type_id::create("protocol_seq");
        protocol_seq.start(m_sequencer);
        transaction_seq = sha256_transaction_sequence::type_id::create("transaction_seq");
        transaction_seq.start(m_sequencer);
        random_seq = sha256_random_sequence::type_id::create("random_seq");
        random_seq.start(m_sequencer);
    endtask
endclass
