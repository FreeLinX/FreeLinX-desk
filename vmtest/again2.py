#!/usr/bin/env python3
"""Second-shot dmenu test: cache is built on first spawn; verify that a
second Alt+p keeps dmenu open (cache now root-writable after --owner fix)."""
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
    time.sleep(0.4)

def diff(a, b):
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

# Warm phase: ensure /root/.cache + dmenu_run cache built (dmenu self-terminates
# on empty stdin, which is fine; the cache file persists afterward).
dump("w1")
hmp(["sendkey alt-p"], wait=0.3)
time.sleep(2.0)
dump("w2")
hmp(["sendkey esc"], wait=0.3)
time.sleep(Projectile 0.7) if False else time.sleep(0.7)

print("warm pre->menu:", diff("w1", "w2"))

# Second shot: cache now exists -> dmenu_run cats it -> dmenu stays open.
dump("s1")
hmp(["sendkey alt-p"], wait=0.3)
time.sleep(2.0)
dump("s2")
print("2nd pre->menu:", diff("s1", "s2"))
hmp(["sendkey esc"], wait=0.3)
time.sleep(1.0)
dump("s3")
print("menu->esc    :", diff("s2", "s3"))
print("done")
