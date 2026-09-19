#!/usr/bin/env python3
"""dmenu keybinding test - FreeLinX VM via QEMU monitor (4445).

Tests Alt+p (MODKEY), Super+p (SUPERKEY addition), Super+d, Super+Return.
For each: screenshot before, send combo, screenshot (dmenu should be up),
send Esc, screenshot. Then compute pixel diff bboxes to see the menu.

Usage: python3 dmenu3.py
"""
import socket, time, subprocess, sys

MON = 4445
D = "/home/devuan/FreeLinX/Desktop-test/vmtest"

def hmp(cmds, wait=0.4):
    s = socket.socket()
    s.settimeout(4)
    s.connect(("127.0.0.1", MON))
    time.sleep(0.2)
    s.recv(8192)
    for c in cmds:
        s.sendall(c.encode() + b"\r\n")
        time.sleep(wait)
    s.close()

def dump(name):
    hmp(["screendump %s/%s.ppm" % (D, name)])
    time.sleep(0.55)

def to_png(name):
    p = "%s/%s.ppm" % (D, name)
    o = "%s/%s.png" % (D, name)
    subprocess.run(["convert", p, o], capture_output=True)

def bbox(a, b):
    to_png(a); to_png(b)
    r = subprocess.run(
        ["python3", "-c",
         "from PIL import Image, ImageChops;"
         "a=Image.open('%s/%s.png').convert('RGB');"
         "b=Image.open('%s/%s.png').convert('RGB');"
         "print(ImageChops.difference(a, b).getbbox())" % (D, a, D, b)],
        capture_output=True, text=True)
    return r.stdout.strip()

def combo(keys, tag):
    dump(tag + "_p")
    hmp(["sendkey " + keys])
    time.sleep(2.4)
    dump(tag + "_m")
    hmp(["sendkey esc"])
    time.sleep(0.9)
    dump(tag + "_x")
    print("%-9s pre->menu:%s  menu->esc:%s" %
          (tag, bbox(tag + "_p", tag + "_m"), bbox(tag + "_m", tag + "_x")))

combo("alt-p", "altp")
combo("meta-p", "superp")
combo("meta-d", "superd")
combo("meta-ret", "superret")
print("OK-done")
