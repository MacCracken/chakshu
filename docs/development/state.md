# chakshu — State

> **Status**: Active | **Last Updated**: 2026-06-10 (v0.7.3 cut — **M3 live transport**: lean/AI binary split (`shu` ~0.84 MB + `shu-ai` ~2.57 MB), live `--explain` via hoosh, `?` explain overlay; toolchain → 6.1.29)
>
> Volatile state — version, toolchain pin, milestone progress, binary size.
> Refreshed every release. Durable rules live in
> [`CLAUDE.md`](../../CLAUDE.md); design lives in
> [`docs/design-spec.md`](../design-spec.md).

---

## Current

| Field | Value |
|-------|-------|
| Version | **0.7.3** — **M3 live transport.** `--explain <PID>` POSTs the redacted prompt to the hoosh gateway (`POST /v1/chat/completions`) via sandhi and prints the answer; the `?` key overlays it in the TUI. Foundation (0.7.2) redaction + prompt assembly unchanged. Shipped as a **lean/AI binary split** — see Binary. Next: SSE streaming (0.7.4); `--watch` / `--with-logs` (0.7.5). |
| Cyrius toolchain pin | `6.1.29` (both manifests) — bumped 6.1.27→28 for directory-style stdlib (`lib/unicode/*.cyr`; 6.1.27 errored `cannot read ./lib/unicode.cyr`), then 28→29 (current wrapper). (`json`→`bayan` rename from 6.1.x still applies; `json`/`base64`/`bigint` all folded into `bayan`.) |
| Genesis cycle | v6.1.x — toolchain rev adopted; both manifests pin 6.1.29 |
| Active milestone | **M3 — AI integration** (in progress). Foundation (0.7.2): redaction + prompt assembly. Live transport (0.7.3, **cut**): `--explain` + `?` overlay POST to hoosh via sandhi; lean/AI binary split. The overlay is request→render (blocking). Remaining: **SSE streaming** (0.7.4 — `sandhi_http_stream` + Esc-cancel); `--watch` + `--with-logs` (0.7.5). Live-hoosh happy-path still needs manual verification on a box running the gateway. |
| Next milestone | **M4 — Polish + perf** |
| Binary | **Two builds** (0.7.3 split): lean **`shu`** (build/shu, monitor only) and **`shu-ai`** (ai/build/shu-ai, +AI). System Health Utility, per ADR 0001. |
| Binary size | **Lean `shu`: ~0.84 MB** (883 057 B — text 666 641 + bss 216 416), no AI deps — under btop's 1.7 MB install, beats htop once its ncurses/libc are counted. **`shu-ai`: ~2.57 MB** (sandhi's tls/sigil/sakshi/keccak chain + niyama/unicode). The split exists *because* the toolchain force-links listed stdlib (DCE NOPs but keeps bytes), so AI deps in the manifest = unavoidable bloat — kept out of the lean manifest, present only in `ai/cyrius.cyml`. Design-spec §8 `<256 KB` applies to the lean monitor (still ~3.3× over → M4: DCE/`--strip-dead`); `shu-ai` is explicitly the heavy opt-in. |
| Lines of Cyrius | Shared core src/{proc,processes,snapshot,tui,cli}.cyr + entries (main.cyr lean / ai/main.cyr) + ai.cyr (AI, ~370 LoC w/ live transport) / ai_stub.cyr (lean). Deps via cyrius deps (per-build lib/). |
| Test count | **Two suites**: monitor `tests/chakshu.tcyr` (57) + AI `ai/tests/chakshu-ai.tcyr` (13 — redaction / prompt / JSON marshalling). TUI render path still needs PTY-based testing. |
| `shu -p` wall time | ~113 ms (100 ms sample window + ~13 ms work). Roadmap gate `< 30 ms` work-budget met with margin. |

## Dependency Envelope

Pinned in `cyrius.cyml [deps].stdlib` (23 modules — the parser needs the
full chain present for the concatenated dist bundles; DCE drops what the
linked binary doesn't reach):

```
syscalls alloc fmt io fs str string slice vec
args chrono hashmap process tagged assert
agnosys fnptr thread freelist ct bayan bench
unicode
```

`unicode` (added v0.7.2) is a **directory-style** stdlib module
(`lib/unicode/*.cyr`) — required by niyama's re2/fuzzy engines and only
resolvable by the 6.1.28+ dep resolver.

**Git deps (pulled, in `lib/` via `cyrius deps`)**:

- **darshana** `0.7.0` — Linux TTY/raw-mode primitives (termios, ANSI, cursor). Powers the M2 TUI; chakshu has zero termios/ANSI code of its own. Already ecosystem-current at the 0.7.1 cut.
- **mihi** `1.0.0` — system-info probe library. Identity reads in chakshu's `-p` and TUI paths go through `lib/mihi.cyr` (hostname/kernel/distro/cpu_model/cpu_count/mem_total/mem_free/uptime/gpu_*). Per-frame deltas stay chakshu-local. Advanced `0.8.0` → `1.0.0` at v0.7.1 (mihi's v1.0 ship; same bundled surface).
- **ai-hwaccel** `2.2.6` (transitive via mihi) — accelerator-detection backends called via mihi's no-exec API for the GPU panel. **Pin tracks mihi's own `[deps.ai-hwaccel]` tag, not ai-hwaccel's latest** (2.3.x exists; mihi 1.0.0 still pins 2.2.6) — keeps the concatenated bundle ABI-consistent.
- **niyama** `1.0.4` (added v0.7.2) — regex engines. chakshu uses only the **re2** surface (`niyama_re2_compile`/`_search`/`_group_*`) in `src/ai.cyr` for §6.2 secret redaction; the bre/pcre/fuzzy/vim engines DCE-NOP. First niyama tag built on 6.1.27+; pulls the `unicode` stdlib module. **Carries the bulk of the 0.7.2 size jump** — see Binary size.

**Not yet pulled**:

- `net` (M2, stdlib) — `/proc/net` parsing for the network panel.
- `sandhi` (M3, 0.7.3) — daimon/hoosh JSON-RPC transport for the live `--explain` call.
- `niyama` (M3) — redaction patterns for AI-prompt assembly.

## Milestone Status

| M | Title | Status |
|---|-------|--------|
| M0 | Scaffold | **Gate cleared** — `cyrius deps`/`build`/`test` all green; `shu --version` / `--help` / `--watch` (placeholder) / unknown-flag paths exercised |
| M1 | Plain snapshot | **Closed (v0.2.0)** — all four slices landed. `shu -p` produces a header + memory + cpu/disk/net rates + sortable top-N process table with cmdline. Perf gate met. |
| M2 | Full TUI | **Closed (v0.5.0)** — Slices A–G.3 shipped across v0.2.1–v0.4.0; G.4 close audit (privacy/FFI/signals/buffers/perf) green. Powered by **darshana 0.3.0** — chakshu has zero termios/ANSI code of its own. See CHANGELOG `[0.5.0]` for the M2 arc summary + audit findings. |
| M2.5 | mihi integration | **Closed (v0.6.0)** — identity probes routed through mihi 0.8.0; toolchain bumped 5.10.20 → 6.0.1; GPU panel in `-p` and TUI table mode. Unblocked mihi v1.0 (shipped; chakshu pin advanced to 1.0.0 at v0.7.1). See CHANGELOG `[0.6.0]`. |
| — | AGNOS build target | **Cycle open (v0.7.0)** — `shu` runs on AGNOS: stats via mihi `uname`/`sysinfo`, kernel-log view via the `klog` syscall (unified klug ring), filtering delegated to the agnsh `grep` builtin. Inline; no platform-abstraction layer yet. See CHANGELOG `[0.7.0]`. |
| M3 | AI integration | Not started |
| M4 | Polish + perf | Not started |
| M5 | v1.0 ship | Not started |

## Release Process

| Surface | Where |
|---------|-------|
| CI on push/PR | `.github/workflows/ci.yml` — build, lint, test, smoke, DCE parity, security scan, docs + version consistency |
| Release on semver tag | `.github/workflows/release.yml` — gates on ci.yml, version-verify against tag, build matrix (x86_64-linux), source tarball, GH release with body from CHANGELOG section |
| Smoke test | `scripts/smoke.sh` — 17 gates over M0+M1 surface, run by both CI and locally pre-commit |
| Cutting a release | Bump VERSION + CHANGELOG section + `CHAKSHU_VERSION` literal in `src/main.cyr`, push tag `vX.Y.Z` (or `X.Y.Z`); release.yml takes over. Pre-1.0 tags publish as GH prerelease automatically. |

Patterned on owl's CI/release flow. Differences: no fuzz/bench/PTY
harnesses (chakshu has none), aarch64 target deferred until a real
consumer asks (AGNOS targets both arches, but no current user runs
chakshu on aarch64).

## Carry-Forward

- ADR 0001 records the `shu` binary-name decision (with `ctop` considered and rejected) — closed; no re-litigation needed barring new namespace pressure on `shu`.
- Bazaar `htop` / `btop` recipes remain the user-facing default until M2 closes.
- The original scaffold's `cyrius.cyml` declared `time` (real name: `chrono`)
  and `termios` (does not exist in the toolchain). Both fixed; recorded
  here so the same hallucinated deps don't get re-introduced by a future
  refactor or scaffold pass.

## Cross-References

- Genesis: [agnosticos `state.md`](https://github.com/MacCracken/agnosticos/blob/main/docs/development/state.md) (Cyrius cycle, ecosystem pin-lag)
- Registry: [agnosticos `shared-crates.md`](https://github.com/MacCracken/agnosticos/blob/main/docs/development/applications/shared-crates.md) — chakshu listed under Pre-1.0 Binaries & Tools
