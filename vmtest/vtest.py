#!/usr/bin/env python3
import socket, time, os, sys
MON=4445; D="/home/devuan/FreeLinX/Desktop-test/vmtest"
def hmp(c,w=0.5):
    s=socket.socket(); s.connect(("127.0.0.1",MON)); time.sleep(0.15)
    try: s.recv(8192)
    except Exception: pass
    for x in c: s.sendall(x.encode()+b"\r\n"); time.sleep(w)
    s.close()
def shot(n):
    hmp(["screendump %s/%s.ppm"%(D,n)])
    time.sleep(0.8)
    return os.path.getsize("%s/%s.ppm"%(D,n))
def combo(tag):
    a=shot(tag+"_pre")
    hmp(["sendkey alt-p"],0.3)
    time.sleep(3.0)
    b=shot(tag+"_open")
    hmp(["sendkey esc"],0.3)
    time.sleep(1.5)
    c=shot(tag+"_post")
    print("%-8s sizes pre=%d open=%d post=%d  pre->open=%s  open->esc=%s"%(
        tag,a,b,c,(b!=a),(c!=b)))
print("== run1 (build cache) ==")
combo("r1")
print("== run2 (cache exists) ==")
combo("r2")
print("done")
