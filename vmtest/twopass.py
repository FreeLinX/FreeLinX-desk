#!/usr/bin/env python3
"""dmenu two-pass test via QEMU HMP. Pass A builds the cache (menu may
flash+close); pass B should leave dmenu OPEN because cache file exists now."""
import socket, time, subprocess

MON=4445
D="/home/devuan/FreeLinX/Desktop-test/vmtest"

def hmp(cmds, wait=0.4):
    s=socket.socket()
    s.connect(("127.0.0.1",MON))
    time.sleep(0.15)
    try:
        s.recv(8192)
    except Exception:
        pass
    for c in cmds:
        s.sendall(c.encode()+b"\r\n")
        time.sleep(wait)
    s.close()

def shot(name):
    hmp(["screendump %s/%s.ppm"%(D,name)])
    time.sleep(0.5)

def to_png(name):
    subprocess.run(["convert","%s/%s.ppm"%(D,name),"%s/%s.png"%(D,name)],
                   capture_output=True)
    return "%s/%s.png"%(D,name)

def diff(a,b):
    r=subprocess.run(["python3","-c",
        "from PIL import Image,ImageChops;"
        "a=Image.open('%s').convert('RGB');"
        "b=Image.open('%s').convert('RGB');"
        "print(ImageChops.difference(a,b).getbbox())"%(to_png(a),to_png(b))],
        capture_output=True,text=True)
    return r.stdout.strip() or "None"

def pass_(tag):
    shot(tag+"_pre")
    hmp(["sendkey alt-p"], wait=0.3)
    time.sleep(2.6)
    shot(tag+"_dmenu")
    hmp(["sendkey esc"])
    time.sleep(1.2)
    shot(tag+"_post")
    print("%s pre->dmenu: %s" % (tag, diff(tag+"_pre", tag+"_dmenu")))
    print("%s dmenu->esc: %s" % ("", diff(tag+"_dmenu", tag+"_post")))

print("--- pass A (cold cache) ---")
pass_("A")
print("--- pass B (warm cache)  ---")
pass_("B")
print("KEYTEST_DONE")
