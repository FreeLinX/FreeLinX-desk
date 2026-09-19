#!/usr/bin/env python3
import socket, time, subprocess, os, sys
MON = 4445
D = "/home/devuan/FreeLinX/Desktop-test/vmtest"
HDR = None
def hmp(cmds, wait=0.5):
    s = socket.socket()
    s.connect(("127.0.0.1", MON))
    time.sleep(0.2)
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
    time.sleep(0.6)
def png(name):
    subprocess.run(["convert", "%s/%s.ppm" % (D, name), "%s/%s.png" % (D, name)],
                   capture_output=True)
    return "%s/%s.png" % (D, name)
def bbox(a, b):
    pa = png(a); pb = png(b)
    r = subprocess.run(
        ["python3", "-c",
         "from PIL import Image,ImageChops;"
         "a=Image.open('%s').convert('RGB');"
         "b=Image.open('%s').convert('RGB');"
         "print(ImageChops.difference(a,b).getbbox())" % (pa, pb)],
        capture_output=True, text=True)
    return r.stdout.strip() or "None"
print("shot pre")
shot("altp3_pre")
print("send alt-p")
hmp(["sendkey alt-p"])
time.sleep(2.8)
print("shot open")
shot("altp3_open")
print("send esc")
hmp(["sendkey esc"])
time.sleep(1.3)
print("shot post")
shot("altp3_post")
print("pre->open :", bbox("altp3_pre", "altp3_open"))
print("open->post:", bbox("altp3_open", "altp3_post"))
print("DONE")
