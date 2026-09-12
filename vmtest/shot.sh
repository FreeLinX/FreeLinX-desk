#!/bin/sh
# Screenshot the running VM (monitor) and convert to PNG.
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
exec {fd}<>/dev/tcp/127.0.0.1/4445
printf 'screendump %s/screen.ppm\r' "$SCRIPT_DIR" >&$fd
sleep 1
if [ -f "$SCRIPT_DIR/screen.ppm" ]; then
    ffmpeg -y -i "$SCRIPT_DIR/screen.ppm" "$SCRIPT_DIR/screen.png" 2>/dev/null || \
    convert "$SCRIPT_DIR/screen.ppm" "$SCRIPT_DIR/screen.png" 2>/dev/null || true
fi
exit 0