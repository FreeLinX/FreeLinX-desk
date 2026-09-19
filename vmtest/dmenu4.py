#!/usr/bin/env python3
"""dmenu key combo test against FreeLinX VM via QEMU HMP (port 4445)."""
import socket, time, subprocess, sys

MON = 4445
D = "/home/devuan/FreeLinX/Desktop-test/vmtest"

def hmp(cmds, wait=0.45):
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

def png_of(name):
    subprocess.run(["convert", "%s/%s.ppm" % (D, name), "%s/%s.png" % (D, name)],
                   capture_output=True)

def bbox(a, b):
    png_of(a); png_of(b)
    r = subprocess.run(
        ["python3", "-c",
         "from PIL import Image,ImageChops;"
         "a=Image.open('%s/%s.png').convert('RGB');"
         "b=Image.open('%s/%s.png').convert('RGB');"
         "print(ImageChops.difference(a,b).getbbox())" % (D, a, D, b)],
        capture_output=True, text=True)
    return r.stdout.strip() or "None"

def combo(sendkey, tag):
    dump(tag + "_pre")
    hmp(["sendkey " + sendkey], wait=0.3)
    time.sleep(2.2)
    dump(tag + "_open")
    hmp(["sendkey esc"])
    time.sleep(1.0)
    dump(tag + "_post")
    print("%-10s pre->open : %s" % (tag, bbox(tag + "_pre", tag + "_open")))
    print("%-10s open->esc: %s" % ("", bbox(tag + "_open", tag + "_post")))

for k, t in [("alt-p", "altp"), ("meta-d", "metad"), ("meta-p", "metap"),
             ("meta-Return", "metaret"), ("alt-Return", "altret")]:
    combo(k, t)

print("done")
