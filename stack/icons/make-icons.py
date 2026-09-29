#!/usr/bin/env python3
"""FreeLinX icon theme generator.

GTK 3 aborts when it cannot find an icon it needs for its own widgets (the
search entry's magnifier, a combo box arrow, an expander, a dialog), and the
Adwaita theme is SVG, which would need librsvg.  This draws the icons GTK's
widgets and dialogs ask for as small PNGs, into a theme named FreeLinX that
inherits hicolor.

    make-icons.py <output dir>      writes <output dir>/FreeLinX/...
"""
import math
import os
import sys

from PIL import Image, ImageDraw

SIZES = (16, 24, 32, 48)
FG = (46, 52, 54, 255)          # glyph colour
BLUE = (53, 132, 228, 255)
RED = (192, 28, 40, 255)
YELLOW = (229, 165, 10, 255)
GREEN = (38, 162, 105, 255)
GREY = (119, 118, 123, 255)

# name -> (context, painter)
ICONS = {}


def icon(name, context="actions"):
    def reg(fn):
        ICONS[name] = (context, fn)
        return fn
    return reg


def canvas(s):
    # draw at 4x and scale down: cheap anti-aliasing
    im = Image.new("RGBA", (s * 4, s * 4), (0, 0, 0, 0))
    return im, ImageDraw.Draw(im), s * 4


def tri(d, S, direction, colour=FG):
    m, c = S * 0.3, S / 2
    pts = {
        "down": [(m, S * 0.38), (S - m, S * 0.38), (c, S * 0.68)],
        "up": [(m, S * 0.62), (S - m, S * 0.62), (c, S * 0.32)],
        "end": [(S * 0.38, m), (S * 0.38, S - m), (S * 0.68, c)],
        "start": [(S * 0.62, m), (S * 0.62, S - m), (S * 0.32, c)],
    }[direction]
    d.polygon(pts, fill=colour)


def chevron(d, S, direction, colour=FG):
    w = max(2, int(S * 0.11))
    c, a, b = S / 2, S * 0.3, S * 0.7
    pts = {
        "down": [(a, S * 0.4), (c, S * 0.62), (b, S * 0.4)],
        "up": [(a, S * 0.6), (c, S * 0.38), (b, S * 0.6)],
        "next": [(S * 0.4, a), (S * 0.62, c), (S * 0.4, b)],
        "previous": [(S * 0.6, a), (S * 0.38, c), (S * 0.6, b)],
    }[direction]
    d.line(pts, fill=colour, width=w, joint="curve")


def cross(d, S, colour=FG, m=0.28):
    w = max(2, int(S * 0.11))
    d.line([(S * m, S * m), (S * (1 - m), S * (1 - m))], fill=colour, width=w)
    d.line([(S * (1 - m), S * m), (S * m, S * (1 - m))], fill=colour, width=w)


def check(d, S, colour=FG):
    w = max(2, int(S * 0.12))
    d.line([(S * 0.24, S * 0.52), (S * 0.42, S * 0.7), (S * 0.76, S * 0.3)], fill=colour, width=w, joint="curve")


def circle_badge(d, S, colour):
    d.ellipse([S * 0.06, S * 0.06, S * 0.94, S * 0.94], fill=colour)


def glyph_text(d, S, ch):
    # a bold "!", "?" or "i" made of shapes (no fonts needed)
    white = (255, 255, 255, 255)
    c = S / 2
    w = S * 0.09
    if ch == "!":
        d.rounded_rectangle([c - w, S * 0.22, c + w, S * 0.6], radius=w, fill=white)
        d.ellipse([c - w * 1.1, S * 0.67, c + w * 1.1, S * 0.67 + w * 2.2], fill=white)
    elif ch == "i":
        d.ellipse([c - w * 1.1, S * 0.2, c + w * 1.1, S * 0.2 + w * 2.2], fill=white)
        d.rounded_rectangle([c - w, S * 0.42, c + w, S * 0.78], radius=w, fill=white)
    elif ch == "?":
        d.arc([S * 0.32, S * 0.18, S * 0.68, S * 0.52], 180, 90, fill=white, width=int(w * 2))
        d.line([(c, S * 0.5), (c, S * 0.62)], fill=white, width=int(w * 2))
        d.ellipse([c - w * 1.1, S * 0.68, c + w * 1.1, S * 0.68 + w * 2.2], fill=white)


def page(d, S, colour=(250, 250, 250, 255)):
    d.polygon([(S * 0.2, S * 0.08), (S * 0.62, S * 0.08), (S * 0.8, S * 0.26),
               (S * 0.8, S * 0.92), (S * 0.2, S * 0.92)], fill=colour, outline=GREY, width=max(1, S // 24))
    for i in range(4):
        y = S * (0.4 + i * 0.12)
        d.line([(S * 0.3, y), (S * 0.7, y)], fill=GREY, width=max(1, S // 32))


def folder(d, S, colour=(98, 160, 234, 255)):
    d.rounded_rectangle([S * 0.08, S * 0.2, S * 0.45, S * 0.36], radius=S * 0.05, fill=colour)
    d.rounded_rectangle([S * 0.08, S * 0.3, S * 0.92, S * 0.84], radius=S * 0.06, fill=colour)
    d.rounded_rectangle([S * 0.08, S * 0.38, S * 0.92, S * 0.84], radius=S * 0.06, fill=(160, 200, 245, 255))


# --- actions / ui -------------------------------------------------------------
for dname in ("down", "up", "start", "end"):
    icon("pan-%s-symbolic" % dname)(lambda d, S, dn=dname: tri(d, S, dn))
for dname, g in (("down", "down"), ("up", "up"), ("next", "next"), ("previous", "previous")):
    icon("go-%s-symbolic" % dname)(lambda d, S, g=g: chevron(d, S, g))
icon("window-close-symbolic")(lambda d, S: cross(d, S))
icon("edit-clear-symbolic")(lambda d, S: cross(d, S, m=0.32))
icon("action-unavailable-symbolic")(lambda d, S: (d.ellipse([S*.2, S*.2, S*.8, S*.8], outline=FG, width=max(2, int(S*.1))),
                                                   d.line([(S*.3, S*.7), (S*.7, S*.3)], fill=FG, width=max(2, int(S*.1)))))
icon("object-select-symbolic")(lambda d, S: check(d, S))
icon("emblem-ok-symbolic")(lambda d, S: check(d, S, GREEN))
icon("checkbox-checked-symbolic")(lambda d, S: check(d, S))
icon("radio-checked-symbolic")(lambda d, S: d.ellipse([S*.34, S*.34, S*.66, S*.66], fill=FG))
icon("checkbox-mixed-symbolic")(lambda d, S: d.line([(S*.28, S/2), (S*.72, S/2)], fill=FG, width=max(2, int(S*.12))))
icon("radio-mixed-symbolic")(lambda d, S: d.line([(S*.28, S/2), (S*.72, S/2)], fill=FG, width=max(2, int(S*.12))))
icon("list-add-symbolic")(lambda d, S: (d.line([(S/2, S*.25), (S/2, S*.75)], fill=FG, width=max(2, int(S*.11))),
                                        d.line([(S*.25, S/2), (S*.75, S/2)], fill=FG, width=max(2, int(S*.11)))))
icon("list-remove-symbolic")(lambda d, S: d.line([(S*.25, S/2), (S*.75, S/2)], fill=FG, width=max(2, int(S*.11))))
icon("window-minimize-symbolic")(lambda d, S: d.line([(S*.28, S*.68), (S*.72, S*.68)], fill=FG, width=max(2, int(S*.1))))
icon("window-maximize-symbolic")(lambda d, S: d.rectangle([S*.28, S*.28, S*.72, S*.72], outline=FG, width=max(2, int(S*.09))))
icon("window-restore-symbolic")(lambda d, S: (d.rectangle([S*.36, S*.24, S*.76, S*.64], outline=FG, width=max(2, int(S*.08))),
                                              d.rectangle([S*.24, S*.36, S*.64, S*.76], outline=FG, width=max(2, int(S*.08)))))
icon("open-menu-symbolic")(lambda d, S: [d.line([(S*.25, S*y), (S*.75, S*y)], fill=FG, width=max(2, int(S*.1))) for y in (.3, .5, .7)])
icon("view-more-symbolic")(lambda d, S: [d.ellipse([S*x-S*.07, S*.43, S*x+S*.07, S*.57], fill=FG) for x in (.27, .5, .73)])


@icon("edit-find-symbolic")
def _find(d, S):
    w = max(2, int(S * 0.1))
    d.ellipse([S * 0.18, S * 0.18, S * 0.62, S * 0.62], outline=FG, width=w)
    d.line([(S * 0.56, S * 0.56), (S * 0.82, S * 0.82)], fill=FG, width=int(w * 1.4))


@icon("view-refresh-symbolic")
def _refresh(d, S):
    w = max(2, int(S * 0.1))
    d.arc([S * 0.2, S * 0.2, S * 0.8, S * 0.8], 40, 330, fill=FG, width=w)
    d.polygon([(S * 0.66, S * 0.1), (S * 0.9, S * 0.3), (S * 0.62, S * 0.38)], fill=FG)


@icon("process-working-symbolic")
def _working(d, S):
    for i in range(8):
        a = i * math.pi / 4
        x, y = S / 2 + math.cos(a) * S * 0.32, S / 2 + math.sin(a) * S * 0.32
        r = S * (0.05 + 0.012 * i)
        shade = 60 + i * 22
        d.ellipse([x - r, y - r, x + r, y + r], fill=(shade // 3, shade // 3, shade // 3, 80 + i * 20))


@icon("starred-symbolic")
def _star(d, S):
    pts = []
    for i in range(10):
        a = -math.pi / 2 + i * math.pi / 5
        r = S * (0.42 if i % 2 == 0 else 0.18)
        pts.append((S / 2 + math.cos(a) * r, S / 2 + math.sin(a) * r))
    d.polygon(pts, fill=FG)


icon("non-starred-symbolic")(lambda d, S: _star(d, S))
icon("document-open-symbolic")(lambda d, S: folder(d, S, FG))
icon("document-open-recent-symbolic")(lambda d, S: (d.ellipse([S*.15, S*.15, S*.85, S*.85], outline=FG, width=max(2, int(S*.09))),
                                                    d.line([(S/2, S*.3), (S/2, S/2), (S*.66, S*.62)], fill=FG, width=max(2, int(S*.09)))))
icon("media-eject-symbolic")(lambda d, S: (d.polygon([(S*.2, S*.56), (S*.8, S*.56), (S/2, S*.22)], fill=FG),
                                           d.rectangle([S*.2, S*.66, S*.8, S*.78], fill=FG)))
icon("user-home-symbolic", "places")(lambda d, S: (d.polygon([(S*.12, S*.5), (S/2, S*.14), (S*.88, S*.5)], fill=FG),
                                                   d.rectangle([S*.24, S*.46, S*.76, S*.86], fill=FG)))
icon("folder-symbolic", "places")(lambda d, S: folder(d, S, FG))
icon("drive-harddisk-symbolic", "devices")(lambda d, S: d.rounded_rectangle([S*.12, S*.3, S*.88, S*.72], radius=S*.08, fill=FG))
icon("computer-symbolic", "devices")(lambda d, S: (d.rectangle([S*.14, S*.2, S*.86, S*.66], fill=FG), d.rectangle([S*.36, S*.72, S*.64, S*.8], fill=FG)))
icon("text-x-generic-symbolic", "mimetypes")(lambda d, S: page(d, S, FG))

# --- full-colour icons -------------------------------------------------------------
icon("image-missing", "status")(lambda d, S: (d.rectangle([S*.14, S*.14, S*.86, S*.86], outline=RED, width=max(2, int(S*.08))), cross(d, S, RED, 0.32)))
icon("dialog-error", "status")(lambda d, S: (circle_badge(d, S, RED), glyph_text(d, S, "!")))
icon("dialog-warning", "status")(lambda d, S: (d.polygon([(S/2, S*.06), (S*.96, S*.9), (S*.04, S*.9)], fill=YELLOW), glyph_text(d, S, "!")))
icon("dialog-information", "status")(lambda d, S: (circle_badge(d, S, BLUE), glyph_text(d, S, "i")))
icon("dialog-question", "status")(lambda d, S: (circle_badge(d, S, BLUE), glyph_text(d, S, "?")))
icon("dialog-password", "status")(lambda d, S: (d.rounded_rectangle([S*.2, S*.44, S*.8, S*.9], radius=S*.08, fill=YELLOW),
                                                d.arc([S*.3, S*.12, S*.7, S*.62], 180, 360, fill=GREY, width=max(2, int(S*.1)))))
icon("folder", "places")(lambda d, S: folder(d, S))
icon("user-home", "places")(lambda d, S: (folder(d, S), d.polygon([(S*.34, S*.62), (S/2, S*.48), (S*.66, S*.62)], fill=(255, 255, 255, 255))))
icon("user-desktop", "places")(lambda d, S: folder(d, S))
icon("text-x-generic", "mimetypes")(lambda d, S: page(d, S))
icon("drive-harddisk", "devices")(lambda d, S: (d.rounded_rectangle([S*.08, S*.3, S*.92, S*.74], radius=S*.08, fill=GREY),
                                                d.ellipse([S*.72, S*.46, S*.82, S*.56], fill=GREEN)))
icon("system-software-install", "apps")(lambda d, S: (d.rounded_rectangle([S*.1, S*.3, S*.9, S*.9], radius=S*.08, fill=(181, 131, 90, 255)),
                                                      d.polygon([(S*.36, S*.08), (S*.64, S*.08), (S*.64, S*.4), (S*.78, S*.4), (S/2, S*.7), (S*.22, S*.4), (S*.36, S*.4)], fill=GREEN)))


def main():
    out = os.path.join(sys.argv[1], "FreeLinX")
    dirs = set()
    for name, (ctx, fn) in sorted(ICONS.items()):
        for s in SIZES:
            im, d, S = canvas(s)
            fn(d, S)
            im = im.resize((s, s), Image.LANCZOS)
            sub = "%dx%d/%s" % (s, s, ctx)
            dirs.add((s, ctx, sub))
            os.makedirs(os.path.join(out, sub), exist_ok=True)
            im.save(os.path.join(out, sub, name + ".png"), optimize=True)
    with open(os.path.join(out, "index.theme"), "w") as f:
        f.write("[Icon Theme]\nName=FreeLinX\nComment=FreeLinX interface icons\n"
                "Inherits=hicolor\nDirectories=%s\n\n" % ",".join(sorted(x[2] for x in dirs)))
        for s, ctx, sub in sorted(dirs, key=lambda x: x[2]):
            f.write("[%s]\nSize=%d\nContext=%s\nType=Fixed\n\n" % (sub, s, ctx.capitalize()))
    print("make-icons: %d icons x %d sizes -> %s" % (len(ICONS), len(SIZES), out))


if __name__ == "__main__":
    main()
