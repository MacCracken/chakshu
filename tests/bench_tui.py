#!/usr/bin/env python3
"""Measure the TUI's steady-state CPU cost and peak RSS under a real PTY.

WHY A PTY AND NOT A PIPE: `shu` checks isatty(stdout) and will not enter the TUI
render loop otherwise, so a pipe measures the wrong program.

WHY A 60 s WINDOW: CPU time is accounted in clock ticks (100 Hz here), so a 20 s
window quantises to ~0.05 %/tick — the same order as the figure being measured,
which makes short runs look precise while being noise. 60 s puts the quantum an
order of magnitude below the reading.

The first 2 s are discarded: startup work (the first /proc walk, the mihi identity
probe) is not steady state, and including it inflates a short window.

Usage: python3 tests/bench_tui.py <binary> <seconds> <rate-hz>
See docs/benchmarks.md for captured results and the design-spec §8 targets.
"""
import os, pty, time, signal, sys
def clk(pid):
    with open(f"/proc/{pid}/stat") as f: p=f.read().rsplit(')',1)[1].split()
    return int(p[11])+int(p[12])          # utime+stime, fields 14/15
def hwm(pid):
    for l in open(f"/proc/{pid}/status"):
        if l.startswith("VmHWM"): return int(l.split()[1])
    return 0
binp, secs, rate = sys.argv[1], int(sys.argv[2]), sys.argv[3]
pid, fd = pty.fork()
if pid == 0:
    os.execv(binp, [binp, "--rate", rate]); os._exit(1)
os.set_blocking(fd, False)
time.sleep(2.0)                            # let it settle past startup
t0, c0 = time.time(), clk(pid)
end = t0 + secs
while time.time() < end:
    try: os.read(fd, 65536)
    except (BlockingIOError, OSError): pass
    time.sleep(0.05)
c1, t1 = clk(pid), time.time()
peak = hwm(pid)
os.kill(pid, signal.SIGTERM); os.close(fd)
try: os.waitpid(pid, 0)
except ChildProcessError: pass
hz = os.sysconf("SC_CLK_TCK")
cpu = (c1-c0)/hz/(t1-t0)*100
print(f"  rate={rate}Hz  window={t1-t0:.1f}s  CPU={cpu:.3f}% of one core  peakRSS={peak} kB")
