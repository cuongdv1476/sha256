class sha256_env extends uvm_env;
    `uvm_component_utils(sha256_env)

    tb_agent          agent;
    sha256_scoreboard sco;
    tb_coverage       cov;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        agent = tb_agent::type_id::create("agent", this);
        sco  = sha256_scoreboard::type_id::create("sco", this);
        cov  = tb_coverage::type_id::create("cov", this);
    endfunction

    function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        agent.mon.ap.connect(sco.analysis_export);
        agent.mon.ap.connect(cov.analysis_export);
    endfunction
endclass
