#!/usr/bin/env python3
import socket, time, subprocess
MON=4445
D="/home/devuan/FreeLinX/Desktop-test/vmtest"
def hmp(c,w=0.4):
    s=socket.socket(); s.connect(("127.0.0.1",MON)); time.sleep(0.15)
    try: s.recv(8192)
    except Exception: pass
    for x in c: s.sendall(x.encode()+b"\r\n"); time.sleep(w)
    s.close()
def dump(n):
    hmp(["screendump %s/%s.ppm"%(D,n)]); time.sleep(0.4)
def pngof(n):
    subprocess.run(["convert","%s/%s.ppm"%(D,n),"%s/%s.png"%(D,n)],capture_output=True)
    return "%s/%s.png"%(D,n)
def bbox(a,b):
    r=subprocess.run(["python3","-c",
      "from PIL import Image,ImageChops;"
      "print(ImageChops.difference("
      "Image.open('%s').convert('RGB'),"
      "Image.open('%s').convert('RGB')).getbbox())"%(pngof(a),pngof(b))],
      capture_output=True,text=True)
    return r.stdout.strip() or "None"
def combo(keys,tag):
    dump(tag+"_pre")
    hmp(["sendkey "+keys]); time.sleep(2.4)
    dump(tag+"_open")
    hmp(["sendkey esc"]); time.sleep(1.0)
    dump(tag+"_post")
    print("%-6s pre->open %-22s open->esc %s"%(tag,
          bbox(tag+"_pre",tag+"_open"), bbox(tag+"_open",tag+"_post)))
for i in range(1,3):
    combo("alt-p","pass%d"%i)
print("done")
