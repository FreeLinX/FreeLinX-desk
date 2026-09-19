#!/usr/bin/env python3
"""FreeLinX VM dmenu key test - two-pass Alt+p combo via HMP monitor (4445).

Pass 1 builds the dmenu cache (async; dmenu may flash+exit).
Pass 2 should leave dmenu OPEN because the cache now exists.

Screensh勉 des: screendump before, Alt+p, after-2.2s, Esc, after. Pixel diff.
"""
import socket, time, subprocess

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
    time.sleep(0.6)

def png_of(name):
    subprocess.run(["convert", "%s/%s.ppm" % (D, name), "%s/%s.png" % (D, name)],
                   capture_output=True)
    return "%s/%s.png" % (D, name)

def bbox(a, b):
    subprocess.run(["convert", "%s/%s.ppm" % (D, a), "%s/%s.png" % (D, a)],
                   capture_output=True)
    subprocess.run(["convert", "%s/%s.ppm" % (D, b), "%s/%s.png" % (D, b)],
                   capture_output=True)
    r = subprocess.run(
        ["python3", "-c",
         "from PIL import Image,ImageChops;"
         "a=Image.open('%s/%s.png').convert('RGB');"
         "b=Image.open('%s/%s.png').convert('RGB');"
         "print(ImageChops.difference(a,b).getbbox())" % (D, a, D, b)],
        capture_output=True, text=True)
    return r.stdout.strip() or "None"

def combo(tag):
    dump(tag + "_pre")
    hmp(["sendkey alt-p"])
    time.sleep(2.4)
    dump(tag + "_open")
    hmp(["sendkey esc"])
    time.sleep(1.2)
    dump(tag + "_post")
    print("%-7s pre->open : %s" % (tag, bbox(tag + "_pre", tag + "_open")))
    print("%-7s open->esc : %s" % ("", bbox(tag + "_open", tag + "_post")))

combo("p1")
print("--- second pass (cache exists) ---")
combo("p2")
