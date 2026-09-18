#!/usr/bin/env python3
import socket
import time
import subprocess
import sys
import json

def qmp_cmd(cmd_dict):
    s = socket.socket()
    s.connect(("127.0.0.1", 4447))
    # read greeting
    time.sleep(0.1)
    s.recv(1024)
    # handshake
    s.sendall(json.dumps({"execute": "qmp_capabilities"}).encode() + b"\r\n")
    time.sleep(0.1)
    s.recv(1024)
    # execute
    s.sendall(json.dumps(cmd_dict).encode() + b"\r\n")
    time.sleep(0.1)
    resp = s.recv(2048)
    s.close()
    return resp

def monitor_cmds(cmd_list):
    s = socket.socket()
    s.connect(("127.0.0.1", 4445))
    s.recv(1024)
    for cmd_str in cmd_list:
        s.sendall(cmd_str.encode() + b"\r\n")
        time.sleep(0.02)
    time.sleep(0.1)
    s.close()

def monitor_cmd(cmd_str):
    monitor_cmds([cmd_str])

def screenshot(out_png="screen.png"):
    ppm = "/home/devuan/FreeLinX/Desktop-test/vmtest/screen.ppm"
    monitor_cmd(f"screendump {ppm}")
    time.sleep(0.4)
    subprocess.run(["ffmpeg", "-y", "-i", ppm, out_png], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    print(f"Screenshot saved to {out_png}")

def type_string(s):
    cmds = []
    for ch in s:
        if ch == ' ':
            cmds.append("sendkey spc")
        elif ch == '\n':
            cmds.append("sendkey ret")
        elif ch == '-':
            cmds.append("sendkey minus")
        elif ch == '_':
            cmds.append("sendkey shift-minus")
        elif ch == '&':
            cmds.append("sendkey shift-7")
        elif ch == '~':
            cmds.append("sendkey shift-grave_accent")
        elif ch == '/':
            cmds.append("sendkey slash")
        elif ch == '.':
            cmds.append("sendkey dot")
        elif ch.isupper():
            cmds.append(f"sendkey shift-{ch.lower()}")
        else:
            cmds.append(f"sendkey {ch}")
    monitor_cmds(cmds)

if __name__ == "__main__":
    if len(sys.argv) > 1:
        action = sys.argv[1]
        if action == "shot":
            out = sys.argv[2] if len(sys.argv) > 2 else "screen.png"
            screenshot(out)
        elif action == "type":
            type_string(" ".join(sys.argv[2:]) + "\n")
        elif action == "key":
            for k in sys.argv[2:]:
                monitor_cmd(f"sendkey {k}")
                time.sleep(0.1)
        elif action == "mouse_click":
            # btn: 1 (left), 2 (middle), 4 (right) in QEMU monitor
            btn = sys.argv[2] if len(sys.argv) > 2 else "1"
            monitor_cmd(f"mouse_button {btn}")
            time.sleep(0.05)
            monitor_cmd("mouse_button 0")
        elif action == "mouse_move":
            x = sys.argv[2]
            y = sys.argv[3]
            monitor_cmd(f"mouse_move {x} {y}")
