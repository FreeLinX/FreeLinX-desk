#!/bin/sh
# FreeLinX Desktop Autostart

# 1. Desktop Background (Plan 9 Rio muted sage)
if [ -x /usr/bin/flxbg ]; then
    /usr/bin/flxbg "#778877" &
elif command -v xsetroot >/dev/null 2>&1; then
    xsetroot -solid "#778877" 2>/dev/null &
fi

# 2. Bottom status bar (minimal retro panel)
if [ -x /usr/bin/flxpanel-add ]; then
    /usr/bin/flxpanel-add &
elif [ -x /usr/bin/flxbar-bottom ]; then
    /usr/bin/flxbar-bottom &
fi
