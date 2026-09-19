#!/usr/bin/env python3
"""dmenu key test against booted FreeLinX VM via QEMU HMP (4445)."""
import socket, time, subprocess, os, sys

MON = 4445
BASE = "/home/devuan/FreeLinX/Desktop-test/vmtest"

def hmp(cmds, wait=0.45):
    s = socket.socket()
    s.settimeout(3)
    s.connect(("127.0.0.1", MON))
    time.sleep(0.15)
    try: s.recv(4096)
    except Exception: pass
    for c in cmds:
        s.sendall(c.encode() + b"\r\n")
        time.sleep(wait)
    s.close()

def shot(name):
    p = "%s/%s.ppm" % (BASE, name)
    hmp(["screendump %s" % p])
    time.sleep(0.5)
    q = "%s/%s.png" % (BASE, name)
    subprocess.run(["convert", p, q],
                   capture_output=True)

def diff(a, b):
    png = "%s/%s.png" % (BASE, a)
    qng = "%s/%s.png" % (BASE, b)
    r = subprocess.run(["python3", "-c",
        "from PIL import Image,ImageChops;"
        "a=Image.open('%s').convert('RGB');"
        "b=Image.open('%s').convert('RGB');"
        "print(ImageChops.difference(a,b).getbbox())" % (png, qng)],
        capture_output=True, text=True)
    return r.stdout.strip()

def combo(keys, tag):
    shot(tag + "1")
    hmp(["sendkey " + keys])   # dmenu (dmenu_run)
    time.sleep(1.4)
    shot(tag + "2")
    hmp(["sendkey esc"])       # close dmenu
    time.sleep(0.8)
    shot(tag + "3")
    pre = diff(tag + "1", tag + "2")
    post = diff(tag + "2", tag + "3")
    print("combo=%-7s : before->menu %s   menu->after %s" % (keys, pre, post))
    return pre, post

combo("alt-p", "cp")
combo("super-d", "cd")
combo("super-p", "cp2")
combo("meta-d", "cd2")
print("=== done ===")
