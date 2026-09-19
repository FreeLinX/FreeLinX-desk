#!/usr/bin/env python3
import socket, time, subprocess, sys, os

MON = 4445
BASE = "/home/devuan/FreeLinX/Desktop-test/vmtest"
TAG = sys.argv[1] if len(sys.argv) > 1 else "altp"

def hmp(cmds, wait=0.6):
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
    hmp(["screendump %s/%s.ppm" % (BASE, name)])
    time.sleep(0.5)

def png_of(name):
    subprocess.run(["convert", "%s/%s.ppm" % (BASE, name), "%s/%s.png" % (BASE, name)],
                   capture_output=True)
    return "%s/%s.png" % (BASE, name)

def diffbbox(a, b):
    pa = png_of(a); pb = png_of(b)
    r = subprocess.run(
        ["python3", "-c",
         "from PIL import Image,ImageChops;"
         "a=Image.open('%s').convert('RGB');"
         "b=Image.open('%s').convert('RGB');"
         "print(ImageChops.difference(a,b).getbbox())" % (pa, pb)],
        capture_output=True, text=True)
    return r.stdout.strip() or "None"

def combo(tag):
    dump(tag + "_pre")
    hmp(["sendkey alt-p"])
    time.sleep(2.5)
    dump(tag + "_open")
    hmp(["sendkey esc"])
    time.sleep(1.2)
    dump(tag + "_post")
    print("%-10s pre->open : %s" % (tag, diffbbox(tag + "_pre", tag + "_open")))
    print("%-10s open->esc: %s" % ("", diffbbox(tag + "_open", tag + "_post")))

combo(TAG)
print("done")
