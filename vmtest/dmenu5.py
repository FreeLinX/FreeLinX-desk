#!/usr/bin/env python3
"""dmenu keybinding test. FreeLinX VM HMP monitor (4445), screendump via 4445.

Tests: alt-p, super-d, super-p, super-Return, super-d then type 'ux' etc.
Diff measures screen changes to infer whether dmenu appeared.
"""
import socket, time, subprocess, sys

MON = 4445
D = "/home/devuan/FreeLinX/Desktop-test/vmtest"

def hmp(cmds, wait=0.5):
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
    time.sleep(0.4)

def png(name):
    subprocess.run(["convert", "%s/%s.ppm" % (D, name), "%s/%s.png" % (D, name)],
                   capture_output=True)
    return "%s/%s.png" % (D, name)

def diff_bbox(a, b):
    r = subprocess.run(
        ["python3", "-c",
         "from PIL import Image,ImageChops;"
         "a=Image.open('%s').convert('RGB');"
         "b=Image.open('%s').convert('RGB');"
         "print(ImageChops.difference(a,b).getbbox())" % (png(a), png(b))],
        capture_output=True, text=True)
    return r.stdout.strip() or "None"

def test_combo(keys, tag):
    dump(tag + "_pre")
    hmp(["sendkey " + keys])
    time.sleep(2.5)
    dump(tag + "_open")
    hmp(["sendkey esc"])
    time.sleep(1.2)
    dump(tag + "_post")
    a = diff_bbox(tag + "_pre", tag + "_open")
    b = diff_bbox(tag + "_open", tag + "_post")
    print("%-9s pre->open: %s   open->esc: %s" % (tag, a, b))
    return a, b

# dwm MODKEY = Alt (config.h), so Mod+p => alt+p (dmenu), Mod+b => alt+b
test_combo("alt-p", "altp")
# SUPERKEY (Meta) bindings added: super+d dmenu, super+Return terminal
test_combo("super-d", "superd")
test_combo("super-Return", "superret")
test_combo("super-p", "superp")
print("done")
