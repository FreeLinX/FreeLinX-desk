#!/usr/bin/env python3
"""dmenu key combo test against FreeLinX VM via QEMU HMP (4445)."""
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

def shot(name):
    hmp(["screendump %s/%s.ppm" % (D, name)])
    time.sleep(0.5)

def png(name):
    p = "%s/%s.ppm" % (D, name)
    o = "%s/%s.png" % (D, name)
    subprocess.run(["convert", p, o], capture_output=True)
    return o

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
    shot(tag + "_pre")
    hmp(["sendkey %s" % keys])
    time.sleep(2.2)
    shot(tag + "_open")
    hmp(["sendkey esc"])
    time.sleep(0.9)
    shot(tag + "_post")
    print("%-9s pre->open: %s   open->post(esc): %s" %
          (tag, diff(tag + "_pre", tag + "_open"), diff(tag + "_open", tag + "_post")))

combo("alt-p", "altp")
combo("meta-d", "metad")
combo("meta-p", "metap")
print("done")
