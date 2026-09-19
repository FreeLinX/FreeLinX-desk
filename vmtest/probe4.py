#!/usr/bin/env python3
import subprocess, os
B = "/home/devuan/FreeLinX/Desktop-test/src/rootfs/bin"
S = B + "/sh"
ST = B + "/stest"
D = "/home/devuan/FreeLinX/Desktop-test/src/build/x86_64/freelinx-desktop.img.gz"
UN = "/tmp/unpack"

def run(script, shebang=S, env=None):
    e = dict(os.environ)
    if env:
        e.update(env)
    r = subprocess.run([shebang, "-c", script], capture_output=True, text=True, env=e)
    return r

print("=== 1) set -- $PATH: nece arqmen (IFS=: daxilde) ===")
r = run("IFS=:; set -- $PATH; echo count=$#")
print(r.stdout.strip(), "| rc", r.returncode)

print("=== 2) for d in $PATH: nece iterasiya ===")
r = run("IFS=:; n=0; for d in $PATH; do n=$((n+1)); done; echo iter=$n")
print(r.stdout.strip())

print("=== 3) set -- + \"$@\" ile stest -flx: sətir sayı ===")
r = run('IFS=:\nset -- $PATH\nfor d in "$@"; do stest -flx "$d"; done | wc -l')
print(r.stdout.strip(), "| rc", r.returncode)

print("=== 4) $@-siz, for d in $PATH sagirdi stest (split?) ===")
r = run("IFS=:; for d in $PATH; do stest -flx \"$d\"; done | wc -l")
print(r.stdout.strip())

print("=== 5) isbat: stest birbasa 2 ayri dir arqumen ===")
r = run("stest -flx \"$1\" \"$2\" | wc -l", env={"1": UN+"/bin", "2": UN+"/usr/bin"})
print(r.stdout.strip())
