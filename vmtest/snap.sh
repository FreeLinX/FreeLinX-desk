#!/bin/sh
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
exec {fd}<>/dev/tcp/127.0.0.1/4445
printf 'screendump %s/screen.ppm\r' "$SCRIPT_DIR" >&$fd
sleep 0.5
printf 'quit\r' >&$fd
