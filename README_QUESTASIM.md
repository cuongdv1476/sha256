# Running the SHA-256 UVM testbench with QuestaSim

The RTL and UVM testbench are kept in separate `rtl/` and `tb/` directories.
`compile.f` uses paths relative to this project, and the runner resolves them
from the project root. You can start it from any current directory.

## Requirements

- QuestaSim/ModelSim with `vlib`, `vlog`, `vsim`, and `vcover` on `PATH`.
- Questa's built-in UVM 1.1d library, or an installation configured to provide
  `uvm_pkg` and `uvm_macros.svh`.
- Bash, `sha256sum`, and standard Unix tools.

## Run UVM

From a shell with Questa configured:

```sh
cd /path/to/sha256
./sim/run_regression.sh
```

This compiles the separate RTL and testbench sources into a temporary Questa
work library, runs the default UVM suite, checks the scoreboard and internal
checker PASS markers, then removes the temporary library. The transcript is
written to `sim/regression.log`.

Examples:

```sh
# Directed smoke suite
SEQ_MODE=dir ./sim/run_regression.sh

# Full suite with 55,000 random messages
SEQ_MODE=all NUM_RAND=55000 SEED=1 ./sim/run_regression.sh

# Save functional and code coverage
SEQ_MODE=all NUM_RAND=55000 SEED=1 CODE_COVERAGE=1 \
  UCDB_FILE=sim/coverage/sha256.ucdb ./sim/run_regression.sh
```

The coverage run creates code-coverage summary/detail reports and functional
coverage detail/HTML next to the requested UCDB. To run from another working
directory, use the runner's absolute path; relative `UCDB_FILE` and `LOG_FILE`
paths are interpreted relative to the calling shell's current directory.

## Compile and run manually in a Questa shell

From the project root, with Questa commands available:

```tcl
vlib work
vlog +incdir+rtl +incdir+tb -f compile.f
vsim -c tb_sha256 -sv_seed 1 -do "run -all; quit -f"
```

The manual sequence leaves `work/` in the current directory. The runner is
preferred for isolated builds, captured logs, deterministic checks, and
coverage report generation.
