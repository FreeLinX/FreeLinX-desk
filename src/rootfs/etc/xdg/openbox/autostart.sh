#!/bin/sh
# FreeLinX Desktop Autostart

# 0. Apply the keyboard layout selected by the installer (FreeBSD-style
#    "Keymap" step).  /etc/flx-kbd is written by flxinstall and baked into
#    the running initramfs, so this also configures the installed system.
if [ -r /etc/flx-kbd ]; then
    setxkbmap "$(cat /etc/flx-kbd)" 2>/dev/null || \
    setxkbmap -layout "$(cat /etc/flx-kbd)" 2>/dev/null || true
fi

# 1. Desktop Background (Plan 9 Rio muted sage)
if [ -x /usr/bin/flxbg ]; then
    /usr/bin/flxbg "#778877" &
elif command -v xsetroot >/dev/null 2>&1; then
    xsetroot -solid "#778877" 2>/dev/null &
fi

# 2. Compositor: picom (screen-tearing fix, shadows, transparency).
#    --no-fading-openclose and no animation flags = ZERO animations.
# No compositor: the desktop is CPU-rendered (fbdev/KMS dumb buffers, no
# GLX), and picom would redraw every frame on the CPU.  Opt in with
# FLX_COMPOSITOR=1 on machines that do have a working GL stack.
if [ "${FLX_COMPOSITOR:-0}" = "1" ] && command -v picom >/dev/null 2>&1; then
    picom --daemon --backend xrender --no-fading-openclose --config /etc/xdg/picom/picom.conf 2>/dev/null &
fi

# 3. Notification daemon: dunst
if command -v dunst >/dev/null 2>&1; then
    dunst &
fi

# 4. Panel: launchers (Firefox, terminal, files, installer), windows, clock.
if command -v tint2 >/dev/null 2>&1; then
    tint2 -c /etc/xdg/tint2/tint2rc &
fi
