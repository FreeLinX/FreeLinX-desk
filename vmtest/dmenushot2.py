#!/usr/bin/env python3
"""Second-shot dmenu cache test. First Alt+p builds dmenu cache asynchronously;
a second Alt+p (cache now present) should keep dmenu open waiting for input.

Usage: python3 dmenushot2.py
"""
import socket, time, subprocess, sys

MON = 4445
D = "/home/devuan/FreeLinX/Desktop-test/vmtest"

def hmp(cmds, wait=0.4):
    s = socket.socket()
    s.connect(("127.0.0.1", MON))
    time.sleep(0.15)
    try:
        s.recv(8192)
    except Exception:
        pass
    for c in cmds:
        s.sendall(c.encode() + b"\r\n")
        time.sleep(wait)
    s.close()

def dump(name):
    hmp(["screendump %s/%s.ppm" % (D, name)])
    time.sleep(0.5)

def png(name):
    subprocess.run(["convert", "%s/%s.ppm" % (D, name), "%s/%s.png" % (D, name)],
                   capture_output=True)
    return "%s/%s.png" % (D, name)

def diff(a, b):
    r = subprocess.run(
        ["python3", "-c",
         "from PIL import Image,ImageChops;"
         "a=Image.open('%s').convert('RGB');"
         "b=Image.open('%s').convert('RGB');"
         "print(ImageChops.difference(a,b).getbbox())" % (png(a), png(b))],
        capture_output=True, text=True)
    return r.stdout.strip() or "None"

def combo(keys, tag):
    dump(tag + "p")          # before
    hmp(["sendkey " + keys])
    time.sleep(2.3)
    dump(tag + "o")          # dmenu should be up
    hmp(["sendkey esc"])     # if dmenu open, esc closes it
    time.sleep(0.9)
    dump(tag + "e")
    print("%-10s pre->open : %-24s  open->esc: %-24s" %
          (tag, diff(tag + "p", tag + "o"), diff(tag + "o", tag + "e")))

print("--- warmup shot 1 (build cache) ---")
combo("alt-p", "s1")
print("--- shot 2 (cache present, expect open->esc DIFF) ---")
combo("alt-p", "s2")
print("done")
