# chakshu — Benchmarks

Captured for the v1.0 criteria (criterion 3). Every figure below was **measured**, not carried
forward from an earlier release; where a number disagrees with a prior document, this file is the
one that was taken with a stated method.

**Box:** AMD Ryzen 7 5800H (16 cores) · Arch Linux 7.1.10-arch1-1 · 283-293 processes at rest ·
cyrius 6.5.41 · chakshu v0.9.6 · `build/shu` 663,704 B. Re-captured 2026-09-02 for the v0.9.6
toolchain bump; every figure below was re-measured on 6.5.41, none carried forward.

**A same-box 6.5.35 control was built and benchmarked alongside** (isolated `CYRIUS_HOME`, so
`cycc` itself is 6.5.35 rather than only the vendored `lib/`). It is the only way to tell a
toolchain regression from a box that has simply changed since the last capture — and here it
separates the two cleanly. See "Is the CPU rise the toolchain?" below.

Targets come from [`design-spec.md`](design-spec.md) §8.

---

## Results

| Measurement | Target (§8) | Measured | Verdict |
|---|---|---|---|
| TUI CPU, 1 Hz | < 0.5 % of one core | **0.600 %** (3 runs: 0.600 / 0.650 / 0.600) | ❌ **over**, see below |
| TUI CPU, 4 Hz | *(none)* | 2.332 % (2 runs: 2.332 / 2.416) | — |
| Steady RSS (peak) | < 8 MB | **4,712 kB (4.60 MB)** | ✅ met, 42 % headroom |
| Cold start (`--version`) | < 5 ms | **0.343 ms** | ✅ met, 14x headroom |
| `shu -p` wall | < 30 ms *of work* | **109.4 ms** wall = 100 ms sample window + **~9.4 ms work** | ✅ met on the stated definition |
| First TUI frame | < 50 ms | first bytes 1.0 ms; first **complete** frame ~109 ms | ⚠️ **definition unsettled** |

### The 1 Hz CPU figure is now OVER the target — stated plainly

**0.600 % against `< 0.5 %` is a miss.** It was 0.500 % at v0.9.4 (already *at* the budget rather
than within it) and 0.533 % at v0.9.5, when the per-core, per-device and per-interface parsing
landed. It reads 0.600 % today.

### Is the CPU rise the toolchain? No — measured, not assumed

v0.9.6 changed no monitor source, so a rise from 0.533 % to 0.600 % had to be either the toolchain
or the box. A 6.5.35 binary was rebuilt from this same tree with an isolated `CYRIUS_HOME` and
benchmarked head-to-head, alternating runs:

| | 1 Hz | 4 Hz | peak RSS |
|---|---|---|---|
| cyrius 6.5.35 (control) | 0.633 % / 0.600 % | 2.283 % | 4,692 kB |
| cyrius 6.5.41 (this cut) | 0.650 % / 0.600 % | 2.332 % | 4,712 kB |

**The two are indistinguishable** — the toolchain delta (≈ +0.02 pp at 1 Hz) is smaller than the
run-to-run spread of a single binary (0.600 → 0.650 %, i.e. ±0.05 pp). The +20 kB of RSS is the
only consistent difference and is 0.4 % of a budget with 42 % headroom.

So the gap against v0.9.5's 0.533 % is **box state, not this cut**: a different kernel
(7.1.9-arch1-2 → 7.1.10-arch1-1) and a drifting process count (283 → 293 during the run alone).
Which is really the same complaint as point 1 below — a budget with no stated workload cannot
distinguish a regression from a busier machine, and this cut is the demonstration.

Two things follow, and neither is "adjust the number until it passes":

1. **The target is not checkable as written.** `< 0.5 %` states no process count, and the per-frame
   cost is dominated by the `/proc` walk, which is linear in it. On a ~290-process box the monitor
   costs 0.533-0.600 % depending only on which day it is measured; on a 1,200-process box it will
   cost several times that, against the same target. A budget has to name its workload — and the
   6.5.35-vs-6.5.41 control above shows the unstated workload moving the reading by more than a
   whole toolchain generation does.
2. **The USER column showed how much room is actually there.** Reading `/proc/<pid>/status` for every
   pid cost **0.866 %** — a 73 % rise — and making that read lazy for everything except
   `--sort user` brought it back to 0.517 %. The same technique has not been applied to the rest of
   the per-pid walk, so there is headroom left if the budget is held.

⚠ Recorded as a **miss**, not waived. Design-spec §8 is a v1.0 contract and this is the number.

### Rate scaling is essentially linear

1 Hz → 0.600 %, 4 Hz → 2.332 %. That is **3.9x cost for 4x the rate** (4.1x at v0.9.5), so fixed per-second overhead
is negligible and per-frame work dominates. Two consequences worth recording: the v0.7.15 rolling
delta baseline (`TUI_MIN_SAMPLE_MS = 200`) is doing its job — a keypress repaint inside that window
costs a repaint, not a `/proc` walk — and any future CPU reduction has to come out of the per-frame
path, not out of startup or bookkeeping.

---

## Method

Reproduce with the committed harness:

```bash
cyrius build src/main.cyr build/shu
python3 tests/bench_tui.py ./build/shu 60 1
python3 tests/bench_tui.py ./build/shu 60 4
```

⚠ To benchmark a *different* toolchain as a control, point `CYRIUS_HOME` at an isolated tree —
the `cyrius` wrapper re-execs to the manifest pin but resolves `cycc` from `$CYRIUS_HOME/bin`, so
editing the pin alone still compiles with the currently-linked `cycc` and silently compares a
toolchain against itself.

**TUI CPU + RSS** — [`tests/bench_tui.py`](../tests/bench_tui.py) forks a real **pseudo-terminal**
(`shu` checks `isatty(stdout)` and will not enter the render loop behind a pipe, so a pipe measures
the wrong program), drains its output so the writer never blocks, discards the first **2 s** as
startup, then reads `utime+stime` from `/proc/<pid>/stat` across a **60 s** window and `VmHWM` from
`/proc/<pid>/status`.

The window length is not arbitrary. CPU time is accounted in clock ticks — 100 Hz here — so a 20 s
window quantises to ~0.05 % per tick, the same order as the figure being measured. Short runs look
precise and are noise. 60 s puts the quantum an order of magnitude below the reading.

**Cold start** — 200 sequential `shu --version` runs, wall time divided by 200. This measures
process setup plus the version path only; it deliberately excludes any `/proc` work.

**`shu -p` wall** — three trials of 20 runs each; all three landed within 0.4 ms of 109.4 ms
(109.517 / 109.567 / 109.219). The 100 ms component is the deliberate two-sample delta window
(`-p` must show CPU *rates*, which require two samples separated in time); the residual ~9.4 ms is
the actual work.

**First TUI frame** — timed from exec to first bytes on the PTY, and separately to the first frame
containing the cpu/disk/net rate line. The gap between them is the same 100 ms sample window.

---

## Binary sizes

| Artifact | Size | Note |
|---|---|---|
| `build/shu` (lean, x86_64) | 663,704 B | vs the revised < 768 KB target — met, ~120 KB headroom |
| `build/shu-agnos` (lean, AGNOS) | 657,368 B | compile-gated in CI since v0.9.4 |
| `ai/build/shu-ai` | 2,960,696 B | explicitly out of budget — the opt-in heavy build |
| `build/shu` (lean, aarch64) | ~975,888 B | ⚠️ **over** the 768 KB target; aarch64 is not in the release matrix |

The 768 KB figure is a revision made at v0.9.0. The original 256 KB came from M0, before chakshu
took its dependencies, and is unreachable while the lean build links mihi + ai-hwaccel. `CYRIUS_DCE=1`
emits a **byte-identical** binary since cycc 6.5.16, so it is a parity check rather than an optimiser
— the remaining bulk is upstream bundle size, not chakshu code.

---

## What is NOT benchmarked

Stated so the absence is not mistaken for a passing measurement:

- **AGNOS runtime cost.** `tests/agnos_qemu.py` proves the binary runs; nothing measures its CPU or
  memory there. Under QEMU TCG the numbers would not transfer to real hardware anyway.
- **`--watch` throughput** against a high-rate producer. The panel is gated by the same refresh
  loop, but the NDJSON tail path has no measured ceiling.
- **AI latency.** `--explain` is dominated by the hoosh gateway and the model behind it; timing it
  would benchmark the gateway, not chakshu.
