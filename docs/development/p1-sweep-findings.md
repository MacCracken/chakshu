# chakshu — P-1 sweep findings (v0.7.13, 2026-08-24)

> Full repair plan from the v0.7.13 P-1 sweep. Seven audit dimensions; every
> finding adversarially re-verified against a real build before being recorded,
> and 10 of 58 candidates refuted and dropped. Items marked deferred are tracked
> as checkboxes in [`roadmap.md`](roadmap.md) — this file holds the verified
> mechanism and exact fix for each, so the work does not depend on anyone's memory.
>
> **Section 6 ("Deliberately not doing") is load-bearing** — it records what was
> chased and closed with a probe, so a future sweep does not re-litigate it.

## Repair plan

## 1. Verdict

**The tree is structurally sound but not shippable as-is.** The architecture holds: no libc/FFI in lean `shu` (verified — zero `getaddrinfo`/`libssl`/`socket` markers in the binary), AI opt-in at the binary level holds, parser bounds arithmetic is correct throughout, exit-code contract is consistent, TUI teardown is reachable from every alt-screen path, and the signalfd mask fix from 0.7.12 is complete.

What fails is the **outer edge**: untrusted `/proc` bytes reach the terminal and the LLM prompt unfiltered; the secret redactor misses the two most common real-world credential shapes; the default TUI leaks ~44 KB/frame and breaches the documented 8 MB budget in ~90 seconds; and on any host with >1024 processes the monitor silently omits the busiest process — its headline function. Eight P1s, all reproduced against real binaries.

Nothing here is a design flaw. Every one is a bounded, local repair.

---

## 2. Repair table

Ranked by (severity, confidence, fix-risk). Duplicate findings merged; source IDs in brackets.

| # | Sev | file:line | Defect | Exact fix | Blast radius | Test? |
|---|-----|-----------|--------|-----------|--------------|-------|
| **R1** | P1 | `src/ai.cyr:67` [SEC-1] | Pattern folds only the **leading** letter of password/token/secret/passwd. `PASSWORD=`, `TOKEN=`, `SECRET=`, `PASSWD=`, `MYSQL_ROOT_PASSWORD=` ship verbatim to hoosh. | `niyama_re2_compile("(?i)password\|passwd\|secret\|token\|key")`. `(?i)` verified to compile and match in pinned niyama 1.0.7. Update the now-wrong comment at `ai.cyr:57-60`. | `shu-ai` only; widens matching (fail-safe direction) | **Yes** — uppercase assertions |
| **R2** | P1 | `src/ai.cyr:100-151` [SEC-2, D7-02] | Only `key=value` is examined. `--password hunter2`, `mysql -phunter2`, `postgres://u:p@h`, JWTs, `AKIA…`, `--data=password=x` all pass through. | Cross-token lookback: arm on a secret-looking token **only when that token contains no `=`**; clear the flag after it fires. Add URL-userinfo / `AKIA\|ASIA` / `eyJ…` shape rules. Declare the carry flag *outside* the `while` at `ai.cyr:103`. | `shu-ai` only | **Yes** — one per rule |
| **R3** | P1 | `src/processes.cyr:213`, `src/proc.cyr:403-406` [D1-01, SEC-3] | Only NUL→space. Raw `0x1B`/`0x0A` from cmdline **and** comm reach stdout, the alt-screen, and the LLM prompt. Reproduced: a fabricated `999 R 100 99 fake-root-shell` row and a live `OSC 0` title-set. | In `_proc_read_cmdline`: `if (c == 0) { store8(p,32); } elif (c < 32 \|\| c == 127) { store8(p,63); }` — **NUL branch first** (it is the argv separator; reordering collapses tokens and silently disables R1/R2). Same map on the comm copy in `proc_pid_stat_parse`. Leave ≥0x80 alone. | All 4 render sites + AI prompt + TUI filter | **Yes** — parse w/ ESC/NL comm |
| **R4** | P1 | `src/processes.cyr:58, 115` [P6-1, D1-02, D2-12] | `dir_list` allocates ~22 KB/call on a bump allocator with no free; 2 calls/frame. Measured: 44 KB/frame, RSS 4.5→12.7 MB in 200 s on the real binary at 1 Hz. Spec §8 (<8 MB) breached at ~100 s. | `dir_list_into` (`lib/fs.cyr:248`, allocates nothing). Heap-allocate `names`/`offs` once in `_proc_ensure_init`; `scratch` can be a stack local. Hoist `str_from("/proc")`. **Add `_proc_ensure_init()` to `processes_sample2`** — it never calls it today. | TUI table mode only (`--pid` focus unaffected) | **Yes** — RSS-flat smoke |
| **R5** | P1 | `src/processes.cyr:118` [P6-2] | `break` at PROC_MAX=1024 fires **before** the sort. Reproduced on a 1197-proc box: a 103%-CPU burner absent from `-p --top 5`; 3 of 5 rows were 0% kernel threads. | Raise `PROC_MAX` to **8192** (`processes.cyr:25`). 8192 is a **hard ceiling** — `_tui_filtered_idx` (module scope) holds exactly 8192 u64 slots and `tui.cyr:756` has no bounds check. Must land together with R6 and R11. | Sort cost, `_tui_filtered_idx`, R4 buffers | **Yes** |
| **R6** | P2 | `src/processes.cyr:158-175` [P6-4] | 3-memcpy swap per shift step (`lib/string.cyr:55` memcpy is a byte loop). 61 ms at n=1024; ~1.5 s at n=8192 with `--sort mem`. | Shift-hole insertion sort (2.85× measured, byte-identical output, stability preserved by the same strict `> 0`). Then partial heapselect over `top_n` — only the prefix is displayed. | Sort only | **Yes** — comparator units |
| **R7** | P1 | `src/proc.cyr:26` [D2-1, D1-06] | `proc_read` cannot distinguish truncation from success. Reproduced: 100-veth `/proc/net/dev` → 47% rx undercount; interface churn between samples → `net: rx -14821601740 B/s` on the `-p` contract line. | (a) `proc.cyr:246` — replace the early `return 0` with `break` so `sec_read`/`sec_writ` are stored. (b) mihi-style extra 1-byte probe (`lib/mihi.cyr:100-107`) → distinct sentinel **outside errno space** (`0-4096`; `0-2` collides with ENOENT). (c) Heap-allocate the three scratch buffers at 64 KB once (locals are 1 B/element; `var X[65536]` trips the CI gate and puts 192 KB/frame on the stack). Callers consume partial data + mark, **never** `EXIT_ERR`. | 6 delta sites + 4 loadavg sites | **Yes** |
| **R8** | P2 | `src/tui.cyr:1001` [D4-03] | `sys_kill` return discarded. Reproduced as uid 1000 on `--pid 1`: EPERM (`rc=-1`) silently no-ops, UI returns to Normal as if it succeeded. | `var rc = sys_kill(...); if (rc < 0) { <status-line message> }`. Status line, **not stderr** — stderr mid-alt-screen corrupts the frame. Needs a `_tui_msg` slot (`_tui_render_status` is purely mode-driven today). Also clear `_tui_mode` on the focus-exited early return at `tui.cyr:472-488`, which currently strands CONFIRM_KILL. | Kill path | Yes |
| **R9** | P2 | `src/tui.cyr:1012-1029` + `997-1005` [D4-02] | Typeahead bypasses the confirm gate. Reproduced: one `write(pty,"ky",2)` sends SIGTERM with no prompt ever seen. Also fires from `aaaky`, `risky`, `~/proj/ky.log`. | Flush the **kernel** tty queue on entering CONFIRM — `syscall(SYS_IOCTL, 0, 0x540B, 0)` — plus `_tui_input_pos = _tui_input_n`. The proposal's userspace-only flush and "armed by fresh epoll_wait" flag both fail: `aaaky` was proven to deliver `y` via a fresh `epoll_wait`. Add a ~250 ms dwell guard via `clock_now_ms` (`chrono` already in `[deps].stdlib`). | Kill path | **Yes** — PTY burst |
| **R10** | P2 | `src/ai.cyr:389-390`, `src/tui.cyr:522-524` [D1-03] | `proc_meminfo_field` uses unanchored `strstr`. `prctl(PR_SET_NAME,"Uid:0")` makes the focus panel **and the LLM prompt** report an unprivileged process as uid 0. All three fields (PPid/Uid/Threads) spoofable; verified on this kernel. | Add line-anchored `proc_line_field(buf,key)` (walk via `_proc_skip_line`, accept only `memeq(buf+line_start,key,strlen(key))==1`). Reimplement `proc_meminfo_field` on top of it. **Repoint both `tui.cyr` and `ai.cyr`** — patching only the TUI leaves the prompt poisoned. | Focus panel + AI prompt | **Yes** — `"Name:\tUid:0\nUid:\t1000"` → 1000 |
| **R11** | P2 | `src/tui.cyr:290` [D5-02, D1-08, D4-07, P6-5] | `var _tui_filtered_idx[8192]` at module scope = **65,536 B**, comment claims 8 KB. Measured: −57,344 B in `.bss` **and on disk**, and it removes the compiler's `large static data` warning. | **Decision point — mutually exclusive with R5.** If PROC_MAX stays 1024 → `[1024]`. If R5 raises it to 8192 → leave `[8192]`, it becomes exactly correct. Either way fix the comment and state the lockstep coupling. | Static size only | No |
| **R12** | P2 | `src/tui.cyr:520` [D1-04, D2-5] | `status_buf` NUL-terminated only on `stn > 0`; three `proc_meminfo_field` calls run unconditionally. Reproduced: on a failed read the panel re-renders the **previous frame's** ppid/uid/threads as current. | Mirror `src/ai.cyr:386-391`: init `ppid_val/uid_val/threads_val`, move all three parses inside `if (stn > 0)`, render `-` otherwise. Keep `store8(&status_buf, 0)` in the else as a floor. `rss`/`mem%` come from the successful stat read — do not blank them. | Focus frame | Yes |
| **R13** | P2 | `src/snapshot.cyr:34` [D2-8] | `_snap_print_rate_bps` has no sign test; `bps < 1024` catches negatives and `print_num` emits the `-`. Reproduced in an unprivileged netns: 5/8 runs printed `net: rx -8665120 B/s`. | `if (bps < 0) { bps = 0; }` at the top. **Single choke point** — all eight `*_bps` values flow only here, so this alone fixes both `-p` and the TUI. Skip the `cpu_active` clamp (the aggregate `cpu ` line is over *possible* CPUs; monotonic). | Rate rendering | **Yes** |
| **R14** | P2 | `src/tui.cyr:1048`, `src/ai_stub.cyr:31`, `src/ai.cyr:491` [D4-01] | `?` overlay parks in a bare blocking `read(0,…,1)` with HUP/INT/TERM SIG_BLOCKed and the signalfd undrained. `kill <pid>` is inert until a keystroke. | `poll(2)` over `{fd 0, sfd_exit}` (reuse the idiom at `ai.cyr:497-500`; second pollfd at `&pfd + 8`). **Return a sentinel to `_tui_dispatch_key`** rather than calling `_tui_teardown()` in place — exiting there skips `tty_close_signalfd` at `tui.cyr:1225-1237` and strands the mask. Add the signalfd to `_ai_stream_check_cancel`. | Overlay + shu-ai stream | Yes |
| **R15** | P2 | `src/tui.cyr:1130` [D4-04] | Signalfds are opened **before** `epoll_create1`. Reproduced at `ulimit -n 5`: EMFILE → degraded loop → SigBlk `…4003`, SIGTERM pending forever, only SIGKILL works, terminal left raw+alt-screen. | `if (epfd < 0) { tty_close_signalfd(sfd_exit, TTY_SIGMASK_EXIT); sfd_exit = 0-1; …winch…; }`. Skip the proposed WINCH-hoist (SIGWINCH default is ignore). Consider bailing before `tty_alt_enter` instead — this fix makes it killable but the terminal is still wrecked. | Degraded-launch path | No |
| **R16** | P2 | `src/snapshot.cyr:171-175`, `src/tui.cyr:651-655`, `src/ai.cyr:204-207` [D2-3] | `mihi_mem_free()` −1 unchecked → `mem: 61192 MiB used / 61192 MiB total`, exit 0, empty stderr. Reproduced via bind-mounted meminfo. | Guard `mem_total_b < 0 \|\| mem_avail_b < 0` at **all three** sites, if/else so exactly one render happens. TUI arm: `"mem:  n/a"` (9 bytes) + `tty_clear_to_eol()` — **no `\n`**, it scrolls the cursor-addressed frame. `ai.cyr` is the worst site: the sentinel currently becomes an OOM diagnosis in the prompt. | Mem line ×3 | Yes |
| **R17** | P2 | `src/snapshot.cyr:58` [D2-2] | `mihi_uptime_secs()` −1 → `up: 0d 00:00`, exit 0, silent. Reproduced with `unshare -r -m` + bind-mounted `/proc/uptime`. | Early-out **inside** `snapshot_print_uptime`: `if (secs < 0) { syscall(1,1,"--d --:--",9); return 0; }` — fixes all three call sites at once and enforces the precondition its own comment at `snapshot.cyr:22` already declares. Do **not** add the eprint+EXIT_ERR (aborts mid-line, discards a good snapshot). Never eprint from the TUI sites. | Uptime field ×3 | **Yes** |
| **R18** | P2 | `src/snapshot.cyr:135` [D2-4] | `mihi_cpu_count()` −1 → `proc: <model> (-1 cores)` in "sacred" `-p` output. Reproduced with `/sys` masked. | `var ncpu = mihi_cpu_count(); if (ncpu > 0) { print_num(ncpu); … } else { "unknown cores)\n", 15 }`. `> 0` catches both sentinels (−1 I/O, 0 parse). Optionally fall back to `proc_stat_ncores` to keep the field numeric. | `proc:` line | No |
| **R19** | P2 | `.github/workflows/ci.yml:187` [D7-01] | AI-privacy guard wrapped in `if [ -d src/ai ]`; the AI landed as the **file** `src/ai.cyr`. Both greps have never run. | Re-point to `-f src/ai.cyr` (+ `ai/*.cyr`). The proposed allowlist **fails on a clean tree** — `ai.cyr:229` is `getenv(name)` in the generic helper body and matches neither the env-name literals nor `fn _ai_env_or`. Allowlist on the *argument*: `getenv\(name\)` plus the three `CHAKSHU_*` literals, then pin `_ai_env_or(` call sites separately. | CI | n/a |
| **R20** | P2 | `.github/workflows/ci.yml:174-178` [D4-07] | Large-buffer gate compares the bracket literal against 65536 while labelling it "bytes", and prints `NR` (cumulative across the glob) instead of `FNR`. | Element size is **scope-dependent** (measured): module-scope `var X[N]` = N×8 B, function-local = N×1 B. Anchor a module-level rule to column 1 (`/^var …/`, ×8) and a separate local rule (×1). Fix `NR`→`FNR`. Fix the "lives on the stack" comment for the module case. | CI | n/a |
| **R21** | P2 | `src/tui.cyr:847` [D7-07] | `avail = _tui_cols - 21` assumes a 6-digit PID. With `pid_max=4194304`, 7-digit PIDs make the row `_tui_cols + 1` wide. Reproduced at 24 cols: a 25-column row. | Derive per row: `avail = _tui_cols - (pid_w + 15)` where `pid_w = max(6, digits(pid))` — **per iteration**, not hoisted. Separately, `_tui_status_append` clips by **bytes**, so `[↑↓]` under-fills by 4 columns and at `cols=3` emits a lone `\xe2`. Cap on both bytes (256, the `sbuf` bound) and display columns. | Table rows + status | **Yes** — width assertion |
| **R22** | P3 | `src/snapshot.cyr:217-219`, `src/tui.cyr:513, 587` [D1-07, D4-05, D4-10, D7-04] | 5 hand-counted literal lengths under-count. Three drop `\n` from stderr (spec §9); `" ──"` declared 4 of 7; focus status drops its `)`. | `snapshot.cyr:217-219` → `eprintln(...)` (`cli.cyr:63`; verified the forward reference across includes resolves). `tui.cyr:513` → 7, `tui.cyr:587` → 51. | Error + focus render | **Yes** — CI gate |
| **R23** | P2 | `src/proc.cyr:366-368` [D1-05, D2-6] | Three early `return 1` paths precede every store to `out_rec`; `tui.cyr:494` discards the rc, then `strlen(&srec+24)` walks past the 48-byte record and writes raw stack bytes to the terminal. Proven in isolation (`strlen`=33 from offset 24). Not reachable through today's procfs. | Zero `out_rec` before the early returns (`store64` ×3 + `store8(+24,0)`) **and** check the rc at `tui.cyr:494`. Bail to a *new* message ("unreadable /proc stat"), not "has exited" — the process exists. | Parser + focus | Yes |
| **R24** | P3 | `src/cli.cyr:259-266` [D2-10] | `shu -p --pid N` silently discards `--pid`. Worse: a *bad* pid still exits 1 (parse-time probe), so the flag is half-honored. | Guard before the `mode_p` dispatch (compiled + verified: `-p --pid 1` → exit 2, all other paths unchanged). Decline the `--rate`/`--color` follow-on — both are documented TUI-only. | Arg dispatch | No |
| **R25** | P3 | `cyrius.cyml:16` [D5-04] | Manifest states "DCE drops the unused code". Measured: `CYRIUS_DCE=1` produces an **identical-size** binary, 453,141 differing bytes, `1677 unreachable fns NOPed`. The bayan note cites `bayan_*` when the real calls are `json_v_*`. | Rewrite the `[deps]` preamble: whole-module emission since 6.5.16; closure = `union(dist/*.deps) ∪ [deps].stdlib`; only `chrono` is manifest-only. **Keep** the ≥6.5.30 caveat on byte-neutrality and the AI-chain warning verbatim. | Comments only | n/a |

---

## 3. Apply now vs ask first

### (a) Apply without checking in — mechanical, verified, no judgment

| # | Why it's safe |
|---|---|
| **R13** | One line, single choke point, all 8 callers verified. 0 is the only defensible render for a counter that went backwards. |
| **R17** | Sentinel-only, inside the function, enforces its own documented precondition. No eprint, no exit-code change. |
| **R18** | Render-only. `> 0` covers both sentinels. `scripts/smoke.sh:104` still passes ("unknown cores)"). |
| **R22** | Byte counts + `eprintln`. Verified: builds clean, 64/64 pass. |
| **R23** (parser half) | 4 stores on an already-failed path. Behavior-neutral for the two rc-checking callers. |
| **R12** | Mirrors the shape already shipping in `ai.cyr:386-391`. |
| **R7(a)** only | `proc.cyr:246` `return 0` → `break`. Unconditional win; `proc_netdev_agg` already does this. |
| **R11** | One line + comment — **but see the R5 decision below**; do not apply until PROC_MAX is settled. |
| **R20, R25** | CI awk + comments. No product code. |
| **R3** | P1, both adversarial verdicts confirmed the fix is correct and side-effect-free. It changes no *policy* — it's fail-safe byte filtering. Ordering (`c == 0` first) is mandatory. Flagging here so the maintainer can veto: it does touch the AI prompt path. |
| **R24** | Compiled and run; adds one rejection path, breaks no existing invocation. |

### (b) Confirm with the maintainer first

| # | Why |
|---|---|
| **R1, R2** | AI privacy policy. R1's vocabulary widening (`auth`, `bearer`, `credential`) over-redacts benign tokens — a judgment call about prompt quality vs. paranoia. The **minimal** R1 (`(?i)password\|passwd\|secret\|token\|key`) closes the reported hole with zero behavior change beyond case; recommend that as the floor. |
| **R5 + R6 + R11** | **The one real architectural decision.** R5 (correctness: don't lie about the busiest process) and R11 (57 KB, 6.7% of the binary) are mutually exclusive — `_tui_filtered_idx` is either sized for 1024 or 8192. R5 also makes the O(n²) sort ~1.5 s at `--sort mem` unless R6's heapselect lands with it. My recommendation: **take R5+R6, forgo R11's 57 KB.** Correctness on server hosts beats binary size, and chakshu targets AGNOS servers. But this is the maintainer's call. |
| **R4** | Overflow semantics change: `dir_list_into` returns −3/−4 on overflow and **discards the count**, so an undersized buffer renders an empty table where today it renders 1024 rows. Needs a deliberate sizing + fallback decision. |
| **R7(b,c)** | Changes error surfacing and buffer allocation strategy. The naive form (`return 0-7` into the existing checks) makes `shu -p` *refuse to run* on the big-core host that triggers it, and leaves the TUI at `ncores=1` — strictly worse. |
| **R8, R9** | Kill path. |
| **R10** | Security semantics + touches the AI prompt. |
| **R14, R15** | Signal disposition policy. R15 in particular: unblocking makes the process killable but SIGTERM then kills it outright, still wrecking the terminal. Bailing before `tty_alt_enter` contradicts the deliberate comment at `tui.cyr:1124-1126`. |
| **R16** | Exit-code question: is a missing `MemAvailable` (Linux <3.14) fatal, or a degraded field? |
| **R19** | CI gate that will start failing builds. |
| **R21** | Visible layout change. |

---

## 4. Size plan

### Binary size — CORRECTED, then FIXED UPSTREAM 2026-08-24

**Status: resolved upstream.** ai-hwaccel 2.3.19 and mihi 1.2.5 carry the fix; chakshu
needs only a pin bump once both are tagged. Measured end-to-end against the local fixed
trees: **861,536 B → 571,480 B (−290,056 B, −33.7%)**, 81/81 green, zero undefined
warnings. The analysis that led there follows.

### Original diagnosis — CORRECTED (the sweep's number and framing were both wrong)

The sweep reported "drop `bayan`: −353,624 B, **upstream-blocked**, chakshu cannot do
this alone" and implied ai-hwaccel needed a refactor to move `profile_from_json*` behind
a `[lib.json]` profile. Re-measured directly; the correct picture:

**bayan already ships focused sublibs.** Its dist carries nine of them — `bayan-json`,
`bayan-base64`, `bayan-bigint`, `bayan-csv`, `bayan-cyml`, `bayan-pdf`, `bayan-toml`,
`bayan-u128`, `bayan-yaml` — each with its own `.deps` sidecar. No refactor is needed;
the mechanism exists and works today.

**Measured saving is −290,040 B (−33.7%), not −353,624 B.** Substituting
`dist/bayan-json.cyr` (100,309 B) for the monolith (641,083 B) at the toolchain snapshot
and rebuilding: **861,536 B → 571,496 B**, with `cyrius test` still 81/81 green.

**What actually blocks it — two small upstream fixes, not a refactor:**

1. **mihi over-declares.** `dist/mihi.deps` lists `bayan`, but `dist/mihi.cyr` contains
   **zero** `bayan_*` / `json_*` references. The entry is spurious and should be dropped.
2. **ai-hwaccel calls the un-namespaced compat aliases.** It references the bare
   `json_v_obj_get` / `json_v_int` / `json_v_str` / `json_v_parse_buf` family. The
   **monolith exports both** the bare alias and the `bayan_`-prefixed form; the
   **sublib exports only the prefixed form**. So swapping in `bayan-json` leaves ~7
   `undefined function 'json_v_*'` warnings. They are *warnings, not errors* here because
   the `profile_from_json*` path is unreachable from chakshu — but it is fragile, and it
   becomes a hard link error the moment anything upstream calls it.

   Fix is one of: ai-hwaccel switches its call sites to `bayan_json_v_*` and declares
   `bayan-json` in its sidecar; **or** bayan carries the bare compat aliases into the
   `bayan-json` sublib as it already does in the full bundle.

**Note the manifest entry is a red herring.** Removing `"bayan"` from `[deps].stdlib`
saves **16 bytes** — the sidecars re-vendor it and ai-hwaccel's references pull it in
regardless. The lever is the sidecar + the call sites, not chakshu's manifest.

---

### Original (superseded) size plan, kept for the per-module measurements

| Rank | Change | Saving | Status |
|------|--------|--------|--------|
| 1 | Drop `bayan` from `dist/mihi.deps` + `dist/ai-hwaccel.deps` + both stdlib lists | **−353,624 B (−41.3%)** | **Upstream-blocked.** chakshu cannot do this alone — deleting it from `cyrius.cyml` alone is byte-neutral (857,136 either way); `cyrius deps` re-vendors it from the sidecars. Ask: (1) ai-hwaccel moves `profile_from_json*`/`_pj_*` into a `[lib.json]` profile (mihi has **zero** `json_v_`/`bayan_` references — its sidecar entry is spurious). Without the profile move you inherit 7 permanent `undefined function 'json_v_*'` warnings that flip to a **hard link error** the moment anything upstream calls `profile_from_json_str`. |
| 2 | `_tui_filtered_idx[8192]` → `[1024]` (R11) | **−57,344 B (−6.7%)** | Chakshu one-liner. 64/64 pass, smoke PASS, `.text`/`.rodata` byte-identical, kills the `large static data` warning. **Forfeited if R5 raises PROC_MAX.** |
| 3 | Drop `freelist` (after bayan) | −8,848 B | Safe |
| 4 | Drop `bench` | −8,360 B | Safe |
| 5 | Drop `thread` | −8,240 B | **Risky** — adds 5 unreachable undefs on ai-hwaccel's async-detect path. Do last or not at all. |
| 6 | Drop `tagged` | −4,152 B | Safe |
| 7 | Drop `slice` | −4,120 B | Safe |
| — | `fnptr`, `ct` | 0 B | Not worth touching |

**Best measured safe combination** (bayan + bench + freelist + tagged + slice + R11): **424,784 B, −432,352 B (−50.4%)**, 64/64 tests pass, `scripts/smoke.sh` PASS, `shu -p` field-for-field identical including the `gpu:` line, stderr 0 bytes.

**Do not attempt** (each verified to hard-fail the build): `chrono` (undefined `sleep_ms`, reachable), `args`, `vec`, `process`, `hashmap`, `sakshi` (parse error `lib/mihi.cyr:1040: undefined variable 'SK_WARN'` — mihi clamps ai-hwaccel's log level around its one `registry_detect_no_exec()` call; the manifest's sakshi note is the one dep comment that is fully accurate). Removing `assert` is +16 B, i.e. worse.

**Planning reality:** even the full 50.4% sweep lands at 424,784 B — still **1.66× over design-spec §8's 256 KB target**. The remaining `.text` is stdlib/mihi/ai-hwaccel bulk unreachable from chakshu's side. Either revise §8 or take it upstream.

**Do not shrink the local scratch buffers to save size** — function-scope `var X[N]` is stack-allocated and costs **zero** binary bytes (proven: shrinking four `[8192]` locals in `snapshot.cyr` by 229,376 declared bytes left the binary at exactly 857,136).

---

## 5. Test additions

Ordered by bug-finding power per line.

| Test | Catches | Notes |
|------|---------|-------|
| **`tests/literal_len_check.py` + CI step** | The entire hand-counted-literal class (R22; `cli.cyr:48-54` says it has "already bitten us twice" — it's now bitten five times) | Scan `syscall(1,1,"…",N)` / `eprint(…)` / `print(…)`, decode `\n\t\r\\\"\xNN`, compare UTF-8 length. Skip non-literal length args. **Needs a `# len-ok` escape hatch** for legitimate prefix-writes. 94 sites scan clean apart from the 5. |
| **`ai/tests/chakshu-ai.tcyr`: uppercase + space-separated** | R1, R2. Both **fail today**. | `PASSWORD=`, `TOKEN=`, `SECRET=`, `PASSWD=`, `-e MYSQL_ROOT_PASSWORD=`, `psql --password hunter2`. Plus a regression pin on `--password=*** --port=8080` so the R2 lookback can't over-fire. |
| **`tests/chakshu.tcyr`: `proc_pid_stat_parse` with `0x1B`/`0x0A` comm** | R3. Current comm assertions (`:185`, `:194`) are printable-only. | |
| **`tests/chakshu.tcyr`: `proc_line_field("Name:\tUid:0\nUid:\t1000…")` → 1000** | R10 anchoring | |
| **`tests/chakshu.tcyr`: `_snap_print_rate_bps(-1)` emits no `-`** | R13 | |
| **`tests/chakshu.tcyr`: `snapshot_print_uptime(-1)`** | R17 | `proc_uptime_secs` is tested; the formatter is not. |
| **PTY smoke: SIGTERM / SIGHUP / SIGWINCH** | The design-spec §9 guarantee — currently defended only by a unit test of *darshana's* contract and a source grep. | **Gate on readiness, not a sleep.** Drain until `\x1b[?1049h` before signalling — I measured 8/8 runs returning `rc=-15` with no teardown when the signal races startup, a flake indistinguishable from the real regression. Needs `import signal` and `total = 7` → 10. |
| **PTY smoke: `write(pty,"ky",2)` in one burst → target survives** | R9. Reproduced kill. | |
| **PTY smoke: `drive(rows=10, cols=40)` + no-row-exceeds-cols assertion** | R21, plus the unclipped header rows 1-5 | Parse `ESC[<row>;1H` … `ESC[K`, strip CSI, decode. Use a width function, not codepoint count (CJK argv). |
| **PTY smoke against `build/shu-dce` + both release artifacts** | 1243 lines of `tui.cyr` currently validated only in the non-DCE build. DCE is a real transform at 6.5.35 (453,141 differing bytes). Verified: DCE'd `shu` and `shu-ai` both PASS 7/7. | `release.yml:132` runs inside `cd ai` — the line must be `python3 ../tests/integration_smoke.py build/shu-ai`. Cited line numbers in the source finding (113/127) are stale; they are **116** and **132**. |
| **`scripts/smoke.sh`: real NUL check on `-p`** | The block's own comment already claims it ("no embedded NULs") while asserting only `wc -l`. | `"$BIN" -p \| tr -d '\0' \| wc -c` vs untranslated. Measured 0 NULs today. |
| **`scripts/smoke.sh`: `--rate`/`--color`/`--pid`/`--explain` exit matrix** | Half the arg surface, incl. spec §10's named `--pid 0` gate. | `expect_rc` **does not exist** — use the inline `set +e` idiom. Use `$(cat /proc/sys/kernel/pid_max)` for the no-such-process case; `999999` is allocatable and can flake. |
| **`scripts/smoke.sh`: `--version` == `VERSION`** | A stale/cached build (this tree is in that state right now: `build/shu` says 0.7.12, `cli.cyr` says 0.7.13) | Anchor to the script dir: `REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"`. Reading `VERSION` relative to CWD **breaks `release.yml`**, which runs smoke from `ai/`. |
| **`tests/chakshu.tcyr`: `include "src/processes.cyr"` + comparator units** | Sort-direction inversion. Mutation-tested: inverting the CPU and MEM comparators leaves **all three** gates green (smoke PASS, 64/64, PTY 7/7) while the busiest process vanishes. | `_proc_cmp_comm` ±1/0, `_proc_cmp` sign per key, `_proc_int_to_cstr(n, buf)` (two args). Compiles cleanly beside the existing `proc.cyr` include. |
| **`ci.yml`: root-manifest AI-dep gate + `strings build/shu` network check** | "AI is opt-in at the binary level" — the one binding CLAUDE.md rule with zero encoding. | The `^\[deps\.(sandhi\|niyama)\]` regex **misses sandhi**, which is consumed as a stdlib module (`ai/cyrius.cyml` lists it in `[deps].stdlib`, no `[deps.sandhi]` table). Scan the stdlib array for `sandhi\|net\|http\|tls\|dynlib\|fdlopen`. The `strings` check discriminates cleanly (lean: 0 hits; shu-ai: 6). Do **not** put the `--explain` assertion in `smoke.sh` — `release.yml` runs it against `shu-ai`, which exits 0. |

### Vacuous tests to fix or delete

- **`tests/chakshu.tcyr:52-58` — DELETE.** Declares `var v = "chakshu 0.3.0"` then asserts `strlen(v) > 8` and the `"chakshu "` prefix *of that literal*. Proven vacuous: I replaced it with `"chakshu 99.99.99-BOGUS"` and got **64 passed, 0 failed**. `CHAKSHU_VERSION` is not even in scope (the file includes only `proc.cyr` + `darshana.cyr`; substituting it gives `undefined variable`). The comment points at `src/main.cyr`; the constant is at `src/cli.cyr:10`. Fix the identical stale pointer in `docs/development/state.md:71`.
- **Do NOT add the proposed `sort -rn -c` gate** for `--sort cpu/mem`. Tested against the inverted-comparator mutant: the top-N becomes the *quietest* processes, whose columns are all `0`, and an all-zero column is trivially reverse-sorted — it **PASSES on the mutant**. Either add a non-vacuity guard (≥2 distinct values, or spin a CPU burner) or rely on the comparator units.
- **Do NOT add an ordering assertion for `--sort name`** — the sort key is `comm`, the CMD column prints the full cmdline. It would false-fail.
- **`ci.yml:128`** — the hoosh-stub step is the **only** `continue-on-error: true` in either workflow. Its own comment flags it; leaving it is defensible, but know it is ungated.
- **`ci.yml` signalfd grep** keys on a variable literally named `sfd*` — a rename slips past it. The unit half (`tests/chakshu.tcyr:74-85`, reading `SigBlk` from `/proc/self/status`) is solid and is the model to copy.

---

## 6. Deliberately not doing

Do not re-litigate these. Each was chased and closed with a probe or a build.

**Element size is scope-dependent — this killed four findings.** Measured on cyrius 6.5.35: module-scope `var X[N]` = **N×8 bytes** (`&gb-&ga == 65536` for `var ga[8192]`); function-local `var X[N]` = **N×1 byte** (`&b-&a == 8192` for `var b[8192]`; a canary at offset 8192 is already out of bounds). Consequences:
- `var sb1[8192]` etc. really are 8,192 B. **Raising their `maxlen` to 65536 without enlarging the arrays is an immediate SIGSEGV** — reproduced verbatim against a 76,822-byte synthetic `/proc/net/dev`, exit 139 before the first write. Never apply that patch.
- The CI large-buffer gate is **not** uniformly 8× too lenient. Applying a blanket `×8` produces 17 hits of which 16 are legitimate stack buffers (`ai.cyr:441 var answer[16384]`, fourteen `[8192]` locals) — it would red the first push.
- `var events[16]` is 16 bytes, and `maxevents` is hardcoded to 1. Fine.

**Other closed items:**
- **`epoll_event.data` offset** — `store64(ev+4, data)` looks x86_64-packed, but an actual aarch64 build+run refutes the defect. Leave it.
- **Allocation-failure handling in `_proc_ensure_init`** — the stdlib citations are accurate (`alloc` returns 0, `map_u64_clear` derefs unguarded) but the reachability argument fails. Not a defect.
- **`--pid` reporting "no such process" for EACCES** — `file_open` does return `-errno`, but the trigger is not reachable (hidepid hides the whole directory, so the earlier `/stat` probe fails first).
- **Plaintext `http://` to a non-loopback hoosh** — reproduced the behavior (token + prompt on the wire) but it is documented, opt-in, and defaults to loopback. Not a defect.
- **`CHAKSHU_HOOSH_TOKEN` 1016-byte truncation** — the finding's central premise was inverted by the element-size correction; nothing left to fix.
- **`proc_pid_stat_parse` rc in the focus frame** — the *facts* hold (R23), but no procfs input can reach it: the kernel emits the record whole and parenthesised, the longest `/proc/<pid>/stat` on this box is 324 B against a 1023-byte cap, and the parens sit in the first ~25 bytes. Fix it as hardening, do not file it as live.
- **`mihi_uname` return discarded** at `snapshot.cyr:86`, `tui.cyr:452`, `tui.cyr:632` — safe by construction: `lib/mihi.cyr:747-757` zeroes the whole `UTS_SIZE` buffer *before* `sys_uname` precisely so a failure yields empty strings. `var uts[400]` > UTS_SIZE 390.
- **`proc_stat_cpu_agg` return discarded** at four sites — every call site pre-initialises its out-params to 0 on the preceding lines, and the `total_delta > 0` guard suppresses the division. Fragile, not live.
- **Division by zero** — enumerated every `/` in `snapshot.cyr`, `processes.cyr`, `cli.cyr`, `tui.cyr`. All divisors are constants or explicitly guarded. `SNAP_SAMPLE_MS` is set once at `snapshot.cyr:19` and never reassigned. `_hz_to_ms` is bounded by the 1..10 rejection at `cli.cyr:149-156`. `proc_stat_ncores` floors at 1 (`proc.cyr:290`).
- **`cpu_active2 - cpu_active1` clamp** — the aggregate `cpu ` line is summed over *possible* CPUs and is monotonic; hotplug-offlining does not shrink it. Speculative hardening; do not ship it alongside R13.
- **`map_u64` key-0 collision** — `MAP_U64_EMPTY` is 0, but `/proc` never contains a directory named `0` and `proc_is_pid_name` gates it.
- **`_proc_int_to_cstr` with negative n** — writes a single NUL (empty string), no underflow. Unreachable anyway.
- **Shift-hole sort's near-sorted regression** — `--sort pid` on sorted input goes 9 µs → 166 µs. That is 0.16 ms against a 40 ms saving. **Do not add a guard compare to recover it.**
- **`--rate`/`--color` silently ignored under `-p`** — documented as TUI-only in the help text. Stated design; erroring would be a gratuitous break.
- **`print_unimplemented` returning `EXIT_ERR` (1) rather than `EXIT_USAGE` (2)** for `--watch`/`--with-logs` — the flag is recognised, the feature is absent. Defensible.
- **The 100 ms sample window itself** — deliberate and documented at `tui.cyr:594-600`. `shu -p` is 0.112 s wall / 0.01 s CPU; parse+render is ~12 ms. The window is what blows spec §8's "-p < 30 ms", and no fix in this sweep changes that.
- **`dir_list`'s 4096-byte getdents scratch** — already moved to the stack in v6.5.11. The leak is the per-entry `str_clone`, not the scratch.
- **`CYRIUS_DCE=1` as a size lever** — reports "453475 bytes NOPed" and emits a byte-identical 857,136 B binary. It is a parity check, not an optimizer.

---

## 7. Sequencing

Each step is independently verifiable: `cyrius build src/main.cyr build/shu` → `cyrius test tests/chakshu.tcyr` (64) → `cd ai && CYRIUS_ALLOW_PARENT_INCLUDES=1 cyrius test tests/chakshu-ai.tcyr` (13) → `bash scripts/smoke.sh` → `python3 tests/integration_smoke.py`. Manual TUI check per CLAUDE.md step 4 after any step touching `tui.cyr`.

**Phase 0 — gates first, so later phases are actually guarded**
1. `tests/literal_len_check.py` + CI step (expect 5 failures) → **R22** → gate green.
2. Delete the vacuous version group; fix `state.md:71`.
3. **R20** (CI awk: scope-aware ×8/×1, `FNR`), **R25** (manifest comments). No product code.
4. **R19** (AI-privacy guard re-point, corrected allowlist) — must be green on the current tree before anything touches `ai.cyr`.

**Phase 1 — AI privacy (needs maintainer sign-off on vocabulary)**

5. Add the failing redaction assertions.
6. **R1** (minimal `(?i)` form) → uppercase assertions green.
7. **R2** (lookback + shape rules) → remaining assertions green, `--password=*** --port=8080` pin holds.
8. Add the AI-opt-in CI gates (stdlib-array scan + `strings`).

**Phase 2 — untrusted input (self-contained, no coupling)**

9. **R3** (control-byte scrub, NUL branch first) + the ESC/NL comm assertion. Re-run the AI assertions — R3 changes the bytes R1/R2 see.
10. **R10** (`proc_line_field`, both call sites) + the anchoring assertion.
11. **R23** (zero `out_rec` + rc check).
12. **R12** (`status_buf` guard).

**Phase 3 — error sentinels (each a one-liner, batch-verifiable)**

13. **R13**, **R17**, **R18**, **R7(a)**, **R24**. Add the three sentinel assertions.
14. **R16** — *after* the exit-code decision.

**Phase 4 — the scaling decision (largest blast radius; do it as one atomic change)**

15. **R6** shift-hole sort + comparator units — lands first and standalone; it is a pure win at PROC_MAX=1024 and *prerequisite* for step 17.
16. **R4** `dir_list_into` + RSS-flat smoke. Verify RSS is flat over 600 frames before proceeding.
17. **R5** PROC_MAX → 8192, **or** **R11** array shrink. Mutually exclusive. If R5: size R4's `offs` for the new cap in the same commit, leave `tui.cyr:290` at `[8192]`, add the heapselect from R6, and re-measure `--sort mem` wall time against spec §8. If R11: apply the one-liner, re-measure `.bss` (expect 87,656) and confirm the `large static data` warning is gone.
18. **R7(b,c)** truncation detection + 64 KB heap buffers — after R4 establishes the heap-buffer pattern in `_proc_ensure_init`.

**Phase 5 — TUI/signal (needs the manual terminal check per step)**

19. **R15** (epoll-failure unblock) — smallest, no interaction.
20. **R14** (overlay poll + sentinel return) — verify `kill` works with the `?` overlay open.
21. **R21** (per-row width + column-clipped status) + the width assertion.
22. **R8** (`sys_kill` rc + `_tui_msg` + CONFIRM_KILL clear).
23. **R9** (TCFLSH + dwell guard) + the `"ky"` burst test.

**Phase 6 — coverage and size**

24. PTY signal/resize scenarios (readiness-gated), DCE + release PTY smoke, smoke.sh exit matrix / NUL check / version check.
25. Size sweep: file the upstream asks for `bayan`; land `bench`/`freelist`/`tagged`/`slice` only once the sidecars are clean. Skip `thread`.

**Do not batch across phase boundaries.** Phase 2 changes the bytes Phase 1's tests assert on, and Phase 4 step 17 is the only irreversible design commitment in the sweep.