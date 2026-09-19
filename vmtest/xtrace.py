#!/usr/bin/env python3
import subprocess, sys, os
BASE = "/home/devuan/FreeLinX/Desktop-test"
GB = "%s/src/rootfs/bin" % BASE
GU = "%s/src/rootfs/usr/bin" % BASE
SH = "%s/src/rootfs/bin/sh" % BASE
ST = "%s/src/rootfs/bin/stest" % BASE
P = GB + ":" + GU
def run(label, argv, env=None):
    e = dict(os.environ)
    if env:
        e.update(env)
    r = subprocess.run(argv, capture_output=True, env=e, text=True)
    print("== %s == rc=%d" % (label, r.returncode))
    print(r.stdout.strip()[:600])
    if r.stderr.strip():
        print("[stderr] " + r.stderr.strip()[:400])
run("A: toybox sh xtrace - separations", [SH, "-x", "-c", "stest -flx $PATH"],
    {"PATH": P, "IFS": ":"})
run("B: toybox sh xtrace, one command nosplit (quoted)", [SH, "-x", "-c", "stest -flx \"$PATH\""],
    {"PATH": P, "IFS": ":"})
run("C: bash xtrace same", ["bash", "-x", "-c", "stest -flx $PATH"],
    {"PATH": P, "IFS": ":"})
run("D: direct two-arg stest via guest sh", [SH, "-c", "stest -flx \"$1\" \"$2\""],
    {"PATH": P, "IFS": ":"}, env=None)
