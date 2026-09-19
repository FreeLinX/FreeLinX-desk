#!/usr/bin/env python3
import os, glob
U = "/tmp/unpack"
for pat in ["*/dmenu_run", "*/dmenu_path", "*/dwm", "*/dmenu", "*/stest",
            "*/dmenu_run~", "*dmenu*"]:
    print("\n=== %s ===" % pat)
    for f in sorted(glob.glob(U + "/" + pat)):
        try:
            sz = os.path.getsize(f)
            head = open(f, "rb").read(80)
            print("%-40s %7d B" % (f.replace(U, ""), sz), end=" ")
            if f.endswith(".gz") or f.endswith(".img"):
                print("(archive)")
            else:
                try:
                    t = head.decode("ascii", "replace")
                    if t.startswith("#!"):
                        print("script: " + t.splitlines()[0])
                    elif t.startswith("\x7fELF"):
                        print("ELF")
                    else:
                        print("raw:" + t[:20].replace("\n", "\\n"))
                except Exception:
                    print("raw")
        except Exception as e:
            print(f, "ERR", e)
