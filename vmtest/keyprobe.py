#!/usr/bin/env python3
"""Keyprobe: openbox W-p (super+p) -> dmenu screendump diff via qemu monitor."""
import socket, time, os, hashlib, sys

HOST, PORT = "127.0.0.1", 4445
VM = "/home/devuan/FreeLinX/Desktop-test/vmtest"
OUT = os.path.join(VM, "postmodp.ppm")

def mon(cmd, wait=1.5):
    s = socket.create_connection((HOST, PORT), timeout=5)
    s.sendall(cmd.encode())
    time.sleep(wait)
    try:
        s.recv(4096)
    except Exception:
        pass
    s.close()

pre = os.path.join(VM, "predmenu.ppm")
mon("screendump %s\r" % pre, 1.2)
print("PRE screendump:", pre, os.path.getsize(pre) if os.path.exists(pre) else "YOX")
print("PRE md5:", hashlib.md5(open(pre, "rb").read()).hexdigest() if os.path.exists(pre) else "-")

mon("sendkey super-p\r", 1.5)
print("sendkey super-p gonderildi")

mon("screendump %s\r" % OUT, 1.2)
print("POST screendump:", OUT, os.path.getsize(OUT) if os.path.exists(OUT) else "YOX")
post_md5 = hashlib.md5(open(OUT, "rb").read()).hexdigest() if os.path.exists(OUT) else "-"
print("POST md5:", post_md5)

if os.path.exists(pre) and os.path.exists(OUT):
    print("DIFF:", "VAR (dmenu ekranda!)" if open(pre, "rb").read() != open(OUT, "rb").read() else "YOX (ekran deyismeyib)")
