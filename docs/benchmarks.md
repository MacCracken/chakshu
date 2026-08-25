# chakshu — Benchmarks

Captured for the v1.0 criteria (criterion 3). Every figure below was **measured**, not carried
forward from an earlier release; where a number disagrees with a prior document, this file is the
one that was taken with a stated method.

**Box:** AMD Ryzen 7 5800H (16 cores) · Arch Linux 7.1.9-arch1-2 · 290 processes at rest ·
cyrius 6.5.35 · chakshu v0.9.4 · `build/shu` 640,216 B.

Targets come from [`design-spec.md`](design-spec.md) §8.

---

## Results

| Measurement | Target (§8) | Measured | Verdict |
|---|---|---|---|
| TUI CPU, 1 Hz | < 0.5 % of one core | **0.500 %** | ⚠️ **at the boundary**, see below |
| TUI CPU, 4 Hz | *(none)* | 2.050 % | — |
| Steady RSS (peak) | < 8 MB | **4,684 kB (4.57 MB)** | ✅ met, 42 % headroom |
| Cold start (`--version`) | < 5 ms | **0.544 ms** | ✅ met, 9x headroom |
| `shu -p` wall | < 30 ms *of work* | **111.0 ms** wall = 100 ms sample window + **~11 ms work** | ✅ met on the stated definition |
| First TUI frame | < 50 ms | first bytes 1.0 ms; first **complete** frame ~109 ms | ⚠️ **definition unsettled** |

### The 1 Hz CPU figure is at the limit, not under it

0.500 % against a `< 0.5 %` target is a pass only by rounding, and it should be read as *at the
budget* rather than *within* it. It is stable — three independent 60 s windows landed on
0.499–0.500 % — so this is the real steady-state cost on a 290-process box, not variance. A machine
with substantially more processes will exceed it, because the per-frame cost is dominated by the
`/proc` walk, which is linear in process count.

Either the target or the workload needs restating before it is frozen: `< 0.5 %` with no stated
process count is not a checkable claim.

### Rate scaling is essentially linear

1 Hz → 0.500 %, 4 Hz → 2.050 %. That is **4.1x cost for 4x the rate**, so fixed per-second overhead
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

**`shu -p` wall** — three trials of 20 runs each; all three landed within 0.1 ms of 111.0 ms. The
100 ms component is the deliberate two-sample delta window (`-p` must show CPU *rates*, which
require two samples separated in time); the residual ~11 ms is the actual work.

**First TUI frame** — timed from exec to first bytes on the PTY, and separately to the first frame
containing the cpu/disk/net rate line. The gap between them is the same 100 ms sample window.

---

## Binary sizes

| Artifact | Size | Note |
|---|---|---|
| `build/shu` (lean, x86_64) | 640,216 B | vs the revised < 768 KB target — met, ~130 KB headroom |
| `build/shu-agnos` (lean, AGNOS) | 633,840 B | compile-gated in CI since v0.9.4 |
| `ai/build/shu-ai` | 3,256,448 B | explicitly out of budget — the opt-in heavy build |
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
