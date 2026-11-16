class sha256_basic_sequence extends sha256_base_sequence;
    `uvm_object_utils(sha256_basic_sequence)

    function new(string name = "sha256_basic_sequence");
        super.new(name);
    endfunction

    task body();
        bit [31:0] empty_words[$];
        bit [31:0] abc_words[$];
        bit [31:0] hello_words[$];

        setup_vif();
        reset_dut();

        abc_words.push_back(32'h6162_6300);
        hello_words.push_back(32'h6865_6c6c);
        hello_words.push_back(32'h6f20_776f);
        hello_words.push_back(32'h726c_6400);

        run_message("BASIC_01_EMPTY", 0, empty_words);
        run_message("BASIC_02_ABC", 64'd24, abc_words);
        run_message("BASIC_03_HELLO_WORLD", 64'd88, hello_words);
        run_generated_case("BASIC_04_ALL_ZERO", 64'd512, PATTERN_ZERO);
        run_generated_case("BASIC_05_ALL_ONE", 64'd512, PATTERN_ONE);
    endtask
endclass
