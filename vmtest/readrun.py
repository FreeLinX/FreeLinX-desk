#!/usr/bin/env python3
import os
U = "/tmp/unpack"
def show(p):
    try:
        with open(p) as f:
            print("### %s ###" % p)
            print(f.read())
    except Exception as e:
        print("### %s : %s" % (p, e))
print("=========== dmenu_run (boyuk: dwm hangisini cagirir?) ===========")
show(U + "/bin/dmenu_run")
show(U + "/usr/bin/dmenu_run")
print("=========== dwm xlog: hangi komut (dmenucmd) ===========")
show(U + "/usr/bin/dwm")
