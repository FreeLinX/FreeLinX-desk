#!/bin/sh
# FreeLinX Desktop Autostart

# 1. Desktop Background (Plan 9 Rio muted sage)
if [ -x /usr/bin/flxbg ]; then
    /usr/bin/flxbg "#778877" &
elif command -v xsetroot >/dev/null 2>&1; then
    xsetroot -solid "#778877" 2>/dev/null &
fi

# 2. Compositor: picom (screen-tearing fix, shadows, transparency).
#    --no-fading-openclose and no animation flags = ZERO animations.
if command -v picom >/dev/null 2>&1; then
    picom \
        --daemon \
        --backend glx \
        --vsync \
        --no-fading-openclose \
        --no-fading-destroyed-argb \
        --fading=false \
        --shadow=true \
        --shadow-radius=8 \
        --shadow-opacity=0.4 \
        --inactive-opacity=0.92 \
        --active-opacity=1.0 \
        --frame-opacity=1.0 \
        --config /etc/xdg/picom/picom.conf \
        2>/dev/null &
fi

# 3. Notification daemon: dunst
if command -v dunst >/dev/null 2>&1; then
    dunst &
fi

# 4. Desktop Panel (task bar, clock, app menu)
if [ -x /usr/bin/flxpanel ]; then
    /usr/bin/flxpanel &
elif [ -x /usr/bin/flxpanel-add ]; then
    /usr/bin/flxpanel-add &
elif [ -x /usr/bin/flxbar-bottom ]; then
    /usr/bin/flxbar-bottom &
fi
