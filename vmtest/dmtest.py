#!/usr/bin/env python3
import socket, time, subprocess

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

def to_png(name):
    subprocess.run(["convert", "%s/%s.ppm" % (D, name), "%s/%s.png" % (D, name)],
                   capture_output=True)

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
    return r.stdout.strip()

def combo(keys, tag):
    dump(tag + "0")
    hmp(["sendkey %s" % keys])
    time.sleep(2.5)
    dump(tag + "1")
    hmp(["sendkey esc"])
    time.sleep(1.0)
    dump(tag + "2")
    print("%s pre->open: %s  open->esc: %s" %
          (tag, bbox(tag + "0", tag + "1"), bbox(tag + "1", tag + "2")))

for k, t in [("alt-p", "altp"),
             ("meta-d", "metad"),
             ("meta-p", "metap")]:
    combo(k, t)

print("ok")
