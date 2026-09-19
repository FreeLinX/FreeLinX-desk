#!/usr/bin/env python3
import socket, time, subprocess, os
MON = 4445
D = "/home/devuan/FreeLinX/Desktop-test/vmtest"
def hmp(cmds, wait=0.4):
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
    time.sleep(0.5)
def png(name):
    r = subprocess.run(["convert", "%s/%s.ppm" % (D, name), "%s/%s.png" % (D, name)],
                       capture_output=True)
    return "%s/%s.png" % (D, name)
def diff(a, b):
    pa = png(a); pb = png(b)
    r = subprocess.run(
        ["python3", "-c",
         "from PIL import Image,ImageChops;"
         "a=Image.open('%s').convert('RGB');"
         "b=Image.open('%s').convert('RGB');"
         "print(ImageChops.difference(a,b).getbbox())" % (pa, pb)],
        capture_output=True, text=True)
    return r.stdout.strip() or "None"
shot("loop_pre")
hmp(["sendkey alt-p"])
time.sleep(2.5)
shot("loop_open")
hmp(["sendkey esc"])
time.sleep(1.0)
shot("loop_post")
print("pre->open:", diff("loop_pre", "loop_open"))
print("open->post:", diff("loop_open", "loop_post"))
print("DONE")
