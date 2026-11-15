class tb_test extends uvm_test;

    `uvm_component_utils(tb_test)

    // =========================================================
    // ENVIRONMENT
    // =========================================================
    tb_env env;

    // Thoi gian cho DUT tinh xong va scoreboard nhan het output
    // sau khi sequence ket thuc (tang len neu test co message dai)
    time drain_time = 10us;


    // =========================================================
    // CONSTRUCTOR
    // =========================================================
    function new(
        string        name,
        uvm_component parent
    );
        super.new(name, parent);
    endfunction


    // =========================================================
    // BUILD PHASE
    // =========================================================
    function void build_phase(
        uvm_phase phase
    );
        super.build_phase(phase);

        env = tb_env::type_id::create("env", this);
    endfunction


    // =========================================================
    // RUN PHASE
    // =========================================================
    task run_phase(
        uvm_phase phase
    );
        tb_sequence seq;
        int unsigned watchdog_ms;

        watchdog_ms = 2000;
        void'($value$plusargs("WDOG_MS=%d", watchdog_ms));
        phase.raise_objection(this);

        seq = tb_sequence::type_id::create("seq");
        fork
            begin
                seq.start(env.seqr);
                // Cho DUT hash xong (o_valid) va scoreboard so sanh xong
                #(drain_time);
            end
            begin
                #(watchdog_ms * 1ms);
                `uvm_fatal("TEST_WATCHDOG", $sformatf(
                    "Global test watchdog expired after %0d ms", watchdog_ms))
            end
        join_any
        disable fork;

        phase.drop_objection(this);
    endtask

endclass : tb_test
