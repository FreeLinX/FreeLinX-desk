#!/usr/bin/env python3
import socket, time, subprocess
MON = 4445
D = "/home/devuan/FreeLinX/Desktop-test/vmtest"

def hmp(cmds, wait=0.4):
    s = socket.socket()
    s.connect(("127.0.0.1", MON))
    time.sleep(0.15)
    try: s.recv(8192)
    except Exception: pass
    for c in cmds:
        s.sendall(c.encode() + b"\r\n")
        time.sleep(wait)
    s.close()

def shot(name):
    hmp(["screendump %s/%s.ppm" % (D, name)])
    time.sleep(0.4)

def diff(a, b):
    subprocess.run(["convert", "%s/%s.ppm" % (D, a), "%s/%s.png" % (D, a)], capture_output=True)
    subprocess.run(["convert", "%s/%s.ppm" % (D, b), "%s/%s.png" % (D, b)], capture_output=True)
    r = subprocess.run(
        ["python3", "-c",
         "from PIL import Image,ImageChops;"
         "a=Image.open('%s/%s.png').convert('RGB');"
         "b=Image.open('%s/%s.png').convert('RGB');"
         "print(ImageChops.difference(a,b).getbbox())" % (D, a, D, b)],
        capture_output=True, text=True)
    return r.stdout.strip() or "None"

print("PRE shot"); shot("qn_pre")
print("Alt+p (cache-free dmenu_path rebuild)"); hmp(["sendkey alt-p"]); time.sleep(3.0)
print("OPEN shot"); shot("qn_open")
print("ESC"); hmp(["sendkey esc"]); time.sleep(1.2)
print("POST shot"); shot("qn_post")
print("pre->open :", diff("qn_pre", "qn_open"))
print("open->post:", diff("qn_open", "qn_post"))
print("DONE")
