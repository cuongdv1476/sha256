class sha256_test extends uvm_test;
    `uvm_component_utils(sha256_test)

    sha256_env env;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        env = sha256_env::type_id::create("env", this);
    endfunction

    task run_phase(uvm_phase phase);
        sha256_base_sequence seq;
        string testcase;

        phase.raise_objection(this);

        testcase = "regression";
        void'($value$plusargs("TC=%s", testcase));
        case (testcase)
            "reset":       seq = sha256_reset_sequence::type_id::create("seq");
            "basic":       seq = sha256_basic_sequence::type_id::create("seq");
            "boundary":    seq = sha256_boundary_padding_sequence::type_id::create("seq");
            "multiblock":  seq = sha256_multiblock_sequence::type_id::create("seq");
            "pattern":     seq = sha256_pattern_sequence::type_id::create("seq");
            "protocol":    seq = sha256_protocol_sequence::type_id::create("seq");
            "transaction": seq = sha256_transaction_sequence::type_id::create("seq");
            "random":      seq = sha256_random_sequence::type_id::create("seq");
            "regression":  seq = sha256_sequence::type_id::create("seq");
            default: `uvm_fatal("TEST", $sformatf(
                "Unknown TC=%s. Choose reset/basic/boundary/multiblock/pattern/protocol/transaction/random/regression",
                testcase))
        endcase

        seq.start(env.agent.seqr);
        phase.drop_objection(this);
    endtask
endclass
