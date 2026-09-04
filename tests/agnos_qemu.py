#!/usr/bin/env python3
"""Boot the `--agnos` build of `shu` on real AGNOS under QEMU and assert on it.

WHY THIS EXISTS

Every other suite here runs on Linux. The AGNOS target is a *different kernel*
with a different syscall surface — no procfs, no termios, no epoll, no ioctl —
and the v0.9.3 work found three separate defects that only exist there, one of
which was an AGNOS kernel bug. None of them were reachable from a Linux test,
and two of them (`-p` aborting, then `run: exit 142`) had been recorded in the
roadmap as *working*. An unbootable claim is not a verified one.

This builds a GPT/ESP disk image, boots gnoboot + AGNOS under QEMU with the
binary seeded at /bin/shu, drives the agnsh prompt through the QEMU monitor's
`sendkey`, and asserts on what came back over the serial line.

REQUIREMENTS (all host-side; the script SKIPS cleanly if any are missing)

    qemu-system-x86_64, OVMF firmware, parted, sgdisk, mtools (mformat/mmd/
    mcopy), mkfs.ext2, and sibling checkouts of agnos + gnoboot already built:
        ../agnos/build/agnos          (./scripts/build.sh)
        ../gnoboot/build/BOOTX64.EFI

It is deliberately NOT a CI gate — CI has none of the above. Run it by hand
before tagging a release that touches the AGNOS path.

    cyrius build --agnos src/main.cyr build/shu-agnos
    python3 tests/agnos_qemu.py build/shu-agnos

MINIMUM KERNEL: the ring-3 stack fix (AGNOS cycle 1.56.46). Before it, any
frame over ~12 KB is page-fault-killed and `-p` reports `run: exit 142`.
"""

import re
import os
import shutil
import socket
import subprocess
import sys
import tempfile
import time

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
AGNOS_KERNEL = os.path.join(ROOT, "..", "agnos", "build", "agnos")
GNOBOOT_EFI = os.path.join(ROOT, "..", "gnoboot", "build", "BOOTX64.EFI")
# The shell has to be on the image too — without /bin/agnsh there is no prompt to
# type `run /bin/shu` at. It is built from the agnoshi repo; agnos stages a copy.
AGNSH_CANDIDATES = [
    os.path.join(ROOT, "..", "agnos", "build", "rootfs", "bin", "agnsh"),
    os.path.join(ROOT, "..", "agnoshi", "build", "agnsh_agnos"),
]
OVMF_CODE_CANDIDATES = [
    "/usr/share/edk2/x64/OVMF_CODE.4m.fd",
    "/usr/share/OVMF/OVMF_CODE.fd",
    "/usr/share/edk2-ovmf/x64/OVMF_CODE.fd",
]
OVMF_VARS_CANDIDATES = [
    "/usr/share/edk2/x64/OVMF_VARS.4m.fd",
    "/usr/share/OVMF/OVMF_VARS.fd",
    "/usr/share/edk2-ovmf/x64/OVMF_VARS.fd",
]

failures = []


class BootFailed(Exception):
    """Raised when a boot never reached the prompt.

    This ABORTS the run rather than letting later assertions score against an
    empty transcript: half the checks here are negative ("no page-fault kill",
    "no fabricated zero rate") and every one of them passes vacuously on "".
    A harness that cannot boot must report failure, not success.
    """


def check(label, cond, detail=""):
    if cond:
        print(f"  ok: {label}")
    else:
        print(f"  FAIL: {label}{(': ' + detail) if detail else ''}")
        failures.append(label)


def first_existing(paths):
    for p in paths:
        if os.path.exists(p):
            return p
    return None


def preflight(shu):
    """Return (ovmf_code, ovmf_vars) or None if this host can't run the test."""
    missing = [t for t in ("qemu-system-x86_64", "parted", "sgdisk", "mformat",
                           "mmd", "mcopy", "mkfs.ext2") if shutil.which(t) is None]
    if missing:
        print(f"agnos qemu: SKIP (missing tools: {', '.join(missing)})")
        return None
    code, vars_ = first_existing(OVMF_CODE_CANDIDATES), first_existing(OVMF_VARS_CANDIDATES)
    if not code or not vars_:
        print("agnos qemu: SKIP (no OVMF firmware found)")
        return None
    for p, what in ((shu, "shu --agnos binary"), (AGNOS_KERNEL, "agnos kernel"),
                    (GNOBOOT_EFI, "gnoboot BOOTX64.EFI")):
        if not os.path.exists(p):
            print(f"agnos qemu: SKIP (no {what} at {p})")
            return None
    if first_existing(AGNSH_CANDIDATES) is None:
        print("agnos qemu: SKIP (no --agnos agnsh build; see agnos "
              "scripts/burn/stage-agnsh.sh --build)")
        return None
    return code, vars_


def build_image(work, shu):
    """GPT: p1 ESP (fat32, gnoboot + kernel), p2 ext2 rootfs with /bin/shu."""
    img = os.path.join(work, "agnos-shu.img")
    seed = os.path.join(work, "seed")
    os.makedirs(os.path.join(seed, "bin"), exist_ok=True)
    for src, name in ((shu, "shu"), (first_existing(AGNSH_CANDIDATES), "agnsh")):
        dst = os.path.join(seed, "bin", name)
        shutil.copy(src, dst)
        os.chmod(dst, 0o755)

    part_offset = 33 * 1048576
    part_blocks = 67 * 1048576 // 4096
    run = lambda *a: subprocess.run(a, check=True, stdout=subprocess.DEVNULL)

    run("dd", "if=/dev/zero", f"of={img}", "bs=1M", "count=128", "status=none")
    run("parted", "-s", img, "mklabel", "gpt",
        "mkpart", "ESP", "fat32", "1MiB", "33MiB", "set", "1", "esp", "on",
        "mkpart", "agnos-fs", "ext2", "33MiB", "100MiB")
    run("sgdisk", "-t", "2:8300", img)
    esp = f"{img}@@1048576"
    run("mformat", "-i", esp, "-F")
    run("mmd", "-i", esp, "::EFI", "::EFI/BOOT", "::boot")
    run("mcopy", "-i", esp, GNOBOOT_EFI, "::EFI/BOOT/BOOTX64.EFI")
    run("mcopy", "-i", esp, AGNOS_KERNEL, "::boot/agnos")
    run("mkfs.ext2", "-F", "-q", "-L", "AGNOS-SHU", "-b", "4096", "-m", "0",
        "-O", "^resize_inode,^dir_index,^metadata_csum,^64bit,^uninit_bg",
        "-d", seed, "-E", f"offset={part_offset}", img, str(part_blocks))
    return img


def boot_and_run(work, img, ovmf, command, hold, keys=""):
    """Boot, type `command` at the agnsh prompt, send `keys`, return serial text."""
    code, vars_src = ovmf
    ser = os.path.join(work, "serial.log")
    mon = os.path.join(work, "mon.sock")
    varfd = os.path.join(work, "vars.fd")
    shutil.copy(vars_src, varfd)
    os.chmod(varfd, 0o644)
    open(ser, "w").close()
    if os.path.exists(mon):
        os.unlink(mon)

    q = subprocess.Popen([
        "qemu-system-x86_64", "-machine", "q35", "-m", "512M", "-cpu", "max",
        "-drive", f"if=pflash,format=raw,readonly=on,file={code}",
        "-drive", f"if=pflash,format=raw,file={varfd}",
        "-drive", f"file={img},format=raw,if=none,id=disk0",
        "-device", "nvme,drive=disk0,serial=AGNOS-SHU",
        "-device", "qemu-xhci,id=xhci", "-device", "usb-kbd,bus=xhci.0",
        "-serial", f"file:{ser}", "-display", "none", "-no-reboot",
        "-monitor", f"unix:{mon},server,nowait",
    ], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

    def serial():
        try:
            return open(ser, "rb").read().decode("latin1")
        except OSError:
            return ""

    try:
        s = None
        for _ in range(80):
            try:
                s = socket.socket(socket.AF_UNIX)
                s.connect(mon)
                break
            except OSError:
                time.sleep(0.25)
        if s is None:
            return None, "no qemu monitor socket"
        s.settimeout(1.0)

        def drain():
            try:
                while True:
                    s.recv(65536)
            except OSError:
                pass

        for _ in range(160):
            if "agnoshi" in serial():
                break
            time.sleep(0.25)
        else:
            return None, "boot never reached the agnsh prompt"

        km = {" ": "spc", "\n": "ret", "-": "minus", ".": "dot", "/": "slash"}

        def typ(text):
            for ch in text:
                s.sendall(("sendkey " + km.get(ch, ch) + "\n").encode())
                time.sleep(0.10)
                drain()

        typ("\n")           # QEMU drops the first char of the first line — prime it
        time.sleep(1.0)
        mark = len(serial())
        typ(command + "\n")
        time.sleep(hold)
        for ch in keys:
            s.sendall(("sendkey " + km.get(ch, ch) + "\n").encode())
            time.sleep(0.30)
            drain()
        time.sleep(2.0)
        return serial()[mark:], None
    finally:
        q.kill()


def run_or_die(work, img, ovmf, command, hold, keys=""):
    out, err = boot_and_run(work, img, ovmf, command, hold, keys)
    if err:
        raise BootFailed(f"{command!r}: {err}")
    return out


def main():
    shu = sys.argv[1] if len(sys.argv) > 1 else os.path.join(ROOT, "build", "shu-agnos")
    ovmf = preflight(shu)
    if ovmf is None:
        return 0

    work = tempfile.mkdtemp(prefix="chakshu-agnos-")
    try:
        print(f"[0] building disk image ({os.path.basename(shu)})")
        img = build_image(work, shu)
        check("image built", os.path.exists(img))

        print("[1] `shu -p` completes on AGNOS")
        out = run_or_die(work, img, ovmf, "run /bin/shu -p", 10)
        # `exit 142` is AGNOS's 128+14 page-fault kill — the pre-1.56.46 stack bug.
        check("no page-fault kill (needs AGNOS >= cycle 1.56.46)",
              "exit 142" not in out, "got `run: exit 142` — kernel stack fix missing?")
        check("no non-zero exit", "run: exit" not in out)
        check("host line", "host: agnos" in out)
        check("kernel line", "kern: AGNOS" in out)
        check("memory line", "mem:" in out and "MiB total" in out)
        # v0.9.5 widened the header with a USER column. Asserting the FULL header
        # keeps this a real end-of-output marker: a prefix match would still pass if
        # the table were truncated mid-header.
        check("column header reached (ran to the end)",
              "PID USER      S  CPU%  MEM% CMD" in out)

        # v0.9.8: proclist #99. Before this the table was a header and ZERO ROWS,
        # and the repo recorded that as blocked upstream. These assertions are the
        # ones that would catch it silently regressing to empty again.
        rows = [l for l in out.splitlines()
                if re.match(r"^\s*\d+\s+root\s+[RC?]\s", l)]
        check("process table is POPULATED (proclist #99)", len(rows) >= 2,
              f"expected >=2 rows, got {len(rows)}")
        # pid 1 is init and must always be live; a table that lists everything
        # EXCEPT init would be a walk that silently dropped a slot.
        check("init (pid 1) present", any(re.match(r"^\s*1\s+root\s", l) for l in rows),
              "pid 1 missing from the table")
        # ...and the untracked columns must say so rather than claim a measured 0.
        # v0.9.9 SUPERSEDES the old ">= 2 n/a per row" assertion. MEM% became a real
        # number when agnos 1.56.59 filled proclist's +56 high u32, so a row now
        # carries exactly ONE n/a (CPU%) plus a numeric MEM%. The two successor
        # assertions below pin both halves of that, which is stricter than the
        # count-based test ever was.
        # Assert on the FIELD, not the line: an unnamed slot renders its command as
        # "[n/a]" too, so a whole-line n/a count conflates two different columns.
        # Columns are: PID USER S CPU% MEM% CMD...
        check("MEM% is numeric on every row (never n/a)",
              all(l.split()[4].isdigit() for l in rows),
              f"a MEM% field is not numeric: {[l.split()[:5] for l in rows[:3]]}")
        check("USER reads root (agnos is single-user), not n/a",
              all(" root " in l for l in rows))
        # v0.9.9: MEM% is REAL — agnos 1.56.59 put rss pages in proclist's +56 high
        # u32. At least one userspace row must report a non-zero MEM%; a table where
        # every row reads 0 means the field is being read as a zeroed/absent slot.
        # (Kernel/boot-address-space slots legitimately report 0 — they have no user
        # PDEs — so this asserts "some row", not "every row".)
        memvals = [int(l.split()[4]) for l in rows if l.split()[4].isdigit()]
        check("MEM% is populated from proclist rss (some row > 0)",
              any(v > 0 for v in memvals),
              f"every MEM% read 0: {memvals}")
        # ...and CPU% must still say n/a. agnos charges timer ticks to a HALTED
        # process, so the ticks exist but are not CPU utilisation — see the header of
        # src/proc_agnos.cyr. A number here means someone rendered them anyway.
        check("CPU% stays n/a (agnos charges ticks to halted processes)",
              all(l.split()[3] == "n/a" for l in rows),
              "CPU% rendered a number from halt-inclusive ticks")

        print("[2] absent /proc degrades to n/a, never a false zero")
        check("loadavg reports n/a", "load: n/a" in out)
        check("delta line reports n/a", "cpu:  n/a   disk: n/a   net: n/a" in out)
        check("no fabricated zero rate", "disk: rd 0 B/s" not in out)

        print("[3] the TUI runs and quits cleanly")
        out = run_or_die(work, img, ovmf, "run /bin/shu", 10, "q")
        check("entered the alt screen", "\x1b[?1049" in out)
        check("painted the header", "host: " in out and "mem:" in out)
        check("ASCII footer (no UTF-8 arrows on a byte console)",
              "[up/dn] move" in out and "\xe2\x86\x91" not in out)
        check("`q` exited: alt screen left", "\x1b[?1049l" in out)
        check("`q` exited: cursor restored", "\x1b[?25h" in out)

        print("[4] scancode decode handles a command key AND a letter")
        out = run_or_die(work, img, ovmf, "run /bin/shu", 9, "fa")
        # If only `q` worked it could be coincidence; this proves the Set-1 table.
        check("`f` entered filter mode", "filter:" in out)
        check("`a` was decoded into the filter", "filter: a_" in out)
    except BootFailed as e:
        print(f"  FAIL: {e}")
        failures.append(str(e))
    finally:
        shutil.rmtree(work, ignore_errors=True)

    print()
    if failures:
        print(f"agnos qemu: FAIL ({len(failures)} checks)")
        for f in failures:
            print(f"  - {f}")
        return 1
    print("agnos qemu: PASS")
    return 0


if __name__ == "__main__":
    sys.exit(main())
