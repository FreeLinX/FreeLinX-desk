#!/usr/bin/env python3
import socket, time, subprocess, os
MON = 4445
D = "/home/devuan/FreeLinX/Desktop-test/vmtest"

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
    time.sleep(0.5)

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
shot("final_pre")
print("send alt-p")
hmp(["sendkey alt-p"])
time.sleep(2.6)
print("shot open")
shot("final_open")
print("send esc")
hmp(["sendkey esc"])
time.sleep(1.4)
print("shot post")
shot("final_post")
print("pre->open:", bbox("final_pre", "final_open"))
print("open->post:", bbox("final_open", "final_post"))
print("DONE")
