# SHA-256 RTL Verification Plan

## 1. Scope and references

This plan verifies the SHA-256 implementation in `rtl/` against NIST FIPS 180-4, Section 5 (preprocessing, padding, parsing, initial hash values) and Section 6.2 (SHA-256 computation). The standard requires appending a `1` bit, the minimum zeros needed to reach 448 modulo 512, and the 64-bit original message length; each 512-bit block is processed in order and chaining carries the prior hash state forward.

- Normative algorithm reference: [NIST FIPS 180-4, Secure Hash Standard](https://nvlpubs.nist.gov/nistpubs/FIPS/NIST.FIPS.180-4.pdf).
- No independent interface specification was present in the workspace at audit time. The interface contract below is **provisional**, inferred from `tb/tb_interface.sv`, RTL comments and current external ports. Interface owner approval is required before sign-off.

## 2. Provisional external interface contract

| Signal/behavior | Rule | Source class | Status / evidence |
|---|---|---|---|
| SHA-256 padding and block processing | Append `1`, zero-pad to 448 modulo 512, append the 64-bit original length; process each 512-bit block in order. | FIPS 180-4 | Normative algorithm requirement; does not specify this module's pin protocol. |
| Reset | Active-low synchronous reset; aborts in-flight operation and returns status idle. | RTL/testbench inference | Provisional. Confirm reset polarity/timing, abort semantics, and digest retention/clearing. |
| Start | One-cycle pulse accepted only while idle/ready; captures `i_bit_length`. | RTL comments/testbench inference | Provisional. Confirm acceptance predicate and pulse requirement. |
| Input word | `i_enable && o_ready` accepts a 32-bit word; `i_data[31]` is earliest bit and unused tail bits are low-positioned/ignored. | RTL/scoreboard inference | Provisional. Confirm word packing, tail-bit rule, and consecutive-word support. |
| Empty message | Length zero produces SHA-256 of the empty bit string and consumes no data words. | Algorithm plus testbench/interface inference | Algorithm digest is normative; how it is initiated on these pins is provisional. |
| Input backpressure | While valid is asserted and ready is low, valid/data remain stable until acceptance. | Ready/valid convention | Provisional until interface owner confirms this contract. |
| Output | `o_valid`/`o_done` indicate a completed digest; no output-ready signal exists. | RTL inference | Provisional. Confirm equivalence, pulse/retention, and digest sampling timing. |
| Error | `o_error` and supported invalid lengths are unspecified. | No normative source found | Open. RTL ties error low; this is not an approved requirement. |

## 3. Requirements and test traceability

| ID | Requirement | Directed/random evidence | Checker / coverage |
|---|---|---|---|
| ALG-01 | SHA-256 constants, rotates, Boolean functions, schedule and all 64 rounds match FIPS 180-4. | Independent Python bit-level KATs; directed empty/abc and mutation suite. | `tb_scoreboard` KAT self-tests; ordered W/round checker; digest comparison. |
| PAD-01 | Padding is `M || 1 || 0^k || len64`, with `len+1+k = 448 mod 512`. | Lengths 0, 1, 7, 8, 9, 31, 32, 33, 447, 448, 449, 511, 512, 513, 895, 896, 897, 959, 960, 1023, 1024, 1025. | Independent bit KATs; scoreboard; `cp_length`, `cp_bit_alignment`, `cp_padding_remainder`. |
| BLK-01 | Padded block count and 512-bit parsing are correct. | One-, two-, three- and four-plus-block messages; 2048 and 5120-bit directed cases; multi-block random cases. | Digest scoreboard; `cp_padded_block_count`; internal schedule checker. |
| CHAIN-01 | The chaining value for block N initializes block N+1 and IV is applied only to the first block. | 512, 1000, 1024, 2048, 5120 bits and independent 1024-bit KAT. | Digest scoreboard; M07 mutation. |
| IF-START | Start acceptance follows the approved interface contract. | Start with first word, start without first word, empty messages. | `p_start_only_when_idle_ready`, `p_start_is_one_cycle`, accepted-start coverage. |
| IF-DATA | No offered word is lost or changed under backpressure. | Multi-block directed messages and seeded random gaps. | `p_input_held_during_backpressure`, scoreboard accepted-word capture, stall coverage. |
| IF-OUTPUT | Exactly one output completion corresponds to each completed, non-aborted start. | Sequential messages; reset injections. | Scoreboard transaction accounting, `p_valid_matches_done`, `p_done_is_one_cycle`. |
| RST-01 | Reset aborts only the current transaction and returns interface status to idle. | Reset at receive, padding, schedule, compression rounds 0/31/63, CHECK_NEXT and DONE. | `p_sync_reset_returns_idle`; message IDs and abort counters; reset-scenario coverage. |
| PROG-01 | A deadlocked DUT fails within a bounded time. | Ready-deadlock mutation and ordinary regression. | Driver/sequence watchdogs and 50 ms test watchdog; regression runner checks transcript. |

## 4. Functional coverage model

The covergroup samples accepted starts and accepted words, not just arbitrary input activity. Reset phases are tagged by the sequence and sampled only while reset is active. Coverage includes:

- Exact/region message lengths at word, byte, padding and block boundaries.
- Bit alignment modulo eight and the remainder modulo 512.
- Number of padded blocks (1, 2, 3, 4+).
- Cross of bit alignment and padded-block count.
- Accepted data patterns and edge bits.
- Stall run duration (1, 2–4, 5–16, 17+ cycles).
- Reset injection scenario and externally visible status.

No catch-all `default` bin is used to claim digest coverage. Functional coverage percentage is not a pass criterion by itself: report uncovered mandatory bins and waiver rationale. Code coverage, assertion activation/coverage and mutation score are separate metrics and must be reported separately.

## 5. Assertion review policy

Assertion source audit:

| Assertion | What it checks | Source/status |
|---|---|---|
| `p_sync_reset_returns_idle` | Reset forces idle status on the following sample. | Interface behavior inferred from RTL/testbench; provisional. |
| `p_done_is_one_cycle` | `done` deasserts after one cycle. | RTL behavior only; provisional, not specified by FIPS. |
| `p_valid_matches_done` | `valid` equals `done` every cycle. | RTL behavior only; provisional, not specified by FIPS. |
| `p_no_error` | Error never asserts. | RTL tie-off only; provisional and unsafe as a normative assertion until error behavior is specified. |
| `p_digest_stable_when_valid` | Digest is stable during the valid sample. | Interface assumption; provisional, especially for first valid cycle. |
| `p_start_only_when_idle_ready`, `p_start_is_one_cycle` | Start legal only idle/ready and one cycle wide. | Provisional interface contract. |
| `p_input_held_during_backpressure` | Valid/data held until ready. | Provisional ready/valid contract. |

FIPS 180-4 specifies the hash algorithm, not these pin-level handshake, reset, valid/done, or error semantics. The workspace search found no independent interface specification. Therefore the assertions above are useful checks against the currently assumed contract, but cannot establish protocol sign-off. An interface owner must approve this contract (or supply the controlling spec), then each provisional property must be retained, revised, or removed with traceable rationale. Internal W/round-order checks are implementation-facing consistency checks and complement, but do not replace, the independent digest scoreboard.

Internal W and round checks are implementation-facing consistency checks. They complement, but do not replace, the independent digest scoreboard. Round order is checked as exactly 0 through 63, once each, with no skipped or extra round.

## 6. Golden model independence

`verification/sha256_independent_oracle.py` implements bit-level SHA-256 separately from the SystemVerilog model. It checks all byte-aligned vectors against Python `hashlib`, then records fixed digests for bit-aligned and padding-boundary vectors in `sha256_independent_vectors.json`. The SV reference model self-tests against fixed outputs for empty, `abc`, 1-bit, 9-bit, 447/448/449-bit, and 1024-bit chaining cases.

The Python model and SV model still implement the same standard and are not formal proofs. Keep the fixed vector JSON and script under review; update both only when independently validated values change.

## 7. Regression and sign-off criteria

Run `sim/run_seed_sweep.sh` for the configured seed list. Each run must record:

- Full source-file SHA-256 manifest and aggregate source hash.
- Seed and QuestaSim version.
- Compile status, simulator exit status, UVM error/fatal counts and assertion failures.
- Started/completed/aborted/digest-compared/pending counts; require `started = completed + aborted + pending`, `completed = digest_compared`, and `pending = 0` at test end.
- Input stall counts and uncovered mandatory functional bins.
- Mutation results for the maintained mutation set.
- If a UCDB is captured, preserve it with its matching log, seed, simulator version and source hash; generate the detailed bin report with `vcover report -cvg -details -zeros`.

A run is PASS only if compilation succeeds, the scoreboard and internal checker emit PASS, no UVM error/fatal/assertion error appears in the transcript, all transaction equations hold and the runner exits zero. A mutation is KILLED only if the same runner exits nonzero for the expected checker/test reason.

## 8. Open items before verification sign-off

1. Obtain approval or a separate interface specification covering start acceptance, word packing/tail bits, reset-abort semantics, output valid/done and error behavior.
2. Review the provisional assertions with that specification; remove neither bins nor checks merely to raise percentages.
3. UCDB gap analysis for seed 1 found exactly one uncovered bin: `sha256_cg.cp_length.two_block_padding_after` (897 bits). This is reachable and required by the padding-boundary plan. A directed 897-bit message was added without changing bins; regenerated `coverage_seed1_closed.ucdb` reports 115/115 bins hit and 100% covergroup coverage. Seeds 1, 2 and 3 also report 100% in their regression transcripts.
4. The runner saves a UCDB when invoked with `UCDB_FILE=/path/to/run.ucdb`; `vcover report -cvg -details -zeros` identifies uncovered bins. Keep the UCDB and matching log/source hash together as evidence.
5. The maintained 15-mutation set was rerun with this testbench/runner: all 15 were killed with nonzero exit status. M01–M10, M13 and M14 were caught by scoreboard digest mismatches, M11/M12 by ordered-round checking, and M15 by the driver watchdog. Per-mutant logs are under `audit_results_20261106/mutations_fixed/<mutation>/p2_runner.log`; the summary is `audit_results_20261106/p2_mutation_sweep.txt`.
6. Treat the current plan as algorithm verification with a provisional interface contract, not protocol sign-off, until item 1 is resolved.
