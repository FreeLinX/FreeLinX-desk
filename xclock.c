#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>
#include <time.h>
#include <unistd.h>
#include <X11/Xlib.h>
#include <X11/Xutil.h>
#include <X11/Xatom.h>
#include <cairo/cairo.h>
#include <cairo/cairo-xlib.h>

int main(int argc, char **argv) {
    int digital = 0;
    for (int i = 1; i < argc; i++) {
        if (!strcmp(argv[i], "-digital") || !strcmp(argv[i], "-d")) digital = 1;
    }

    Display *dpy = XOpenDisplay(NULL);
    if (!dpy) {
        fprintf(stderr, "xclock: unable to open X display\n");
        return 1;
    }
    int scr = DefaultScreen(dpy);
    Window root = RootWindow(dpy, scr);

    int w = 200, h = 200;
    Window win = XCreateSimpleWindow(dpy, root, 60, 60, w, h, 0,
                                     BlackPixel(dpy, scr), WhitePixel(dpy, scr));
    XStoreName(dpy, win, "xclock");
    XClassHint ch = {"xclock", "XClock"};
    XSetClassHint(dpy, win, &ch);

    Atom wm_delete = XInternAtom(dpy, "WM_DELETE_WINDOW", False);
    XSetWMProtocols(dpy, win, &wm_delete, 1);

    XSelectInput(dpy, win, ExposureMask | StructureNotifyMask | KeyPressMask);
    XMapWindow(dpy, win);

    cairo_surface_t *cs = cairo_xlib_surface_create(dpy, win, DefaultVisual(dpy, scr), w, h);
    cairo_t *cr = cairo_create(cs);

    int running = 1;
    while (running) {
        while (XPending(dpy)) {
            XEvent ev;
            XNextEvent(dpy, &ev);
            if (ev.type == ConfigureNotify) {
                if (ev.xconfigure.width != w || ev.xconfigure.height != h) {
                    w = ev.xconfigure.width;
                    h = ev.xconfigure.height;
                    cairo_xlib_surface_set_size(cs, w, h);
                }
            } else if (ev.type == ClientMessage) {
                if ((Atom)ev.xclient.data.l[0] == wm_delete) running = 0;
            } else if (ev.type == KeyPress) {
                KeySym ks = XLookupKeysym(&ev.xkey, 0);
                if (ks == XK_q || ks == XK_Escape) running = 0;
            }
        }

        time_t now = time(NULL);
        struct tm *tm = localtime(&now);

        // Plan 9 parchment background (#ffffea)
        cairo_set_source_rgb(cr, 1.0, 1.0, 0.918);
        cairo_paint(cr);

        double cx = w / 2.0;
        double cy = h / 2.0;
        double radius = (w < h ? w : h) * 0.44;

        if (digital) {
            char buf[64];
            strftime(buf, sizeof(buf), "%H:%M:%S", tm);
            cairo_set_source_rgb(cr, 0.1, 0.1, 0.1);
            cairo_select_font_face(cr, "monospace", CAIRO_FONT_SLANT_NORMAL, CAIRO_FONT_WEIGHT_BOLD);
            cairo_set_font_size(cr, radius * 0.4);
            cairo_text_extents_t te;
            cairo_text_extents(cr, buf, &te);
            cairo_move_to(cr, cx - te.width / 2.0, cy + te.height / 2.0);
            cairo_show_text(cr, buf);
        } else {
            // Clock rim (subtle crisp ring)
            cairo_set_source_rgb(cr, 0.1, 0.1, 0.1);
            cairo_set_line_width(cr, 2.0);
            cairo_arc(cr, cx, cy, radius, 0, 2 * M_PI);
            cairo_stroke(cr);

            // Tick marks
            for (int i = 0; i < 12; i++) {
                double angle = i * (M_PI / 6.0);
                double len = (i % 3 == 0) ? radius * 0.18 : radius * 0.09;
                double lw = (i % 3 == 0) ? 2.5 : 1.2;
                double x1 = cx + (radius - len) * sin(angle);
                double y1 = cy - (radius - len) * cos(angle);
                double x2 = cx + (radius - 2) * sin(angle);
                double y2 = cy - (radius - 2) * cos(angle);

                cairo_set_line_width(cr, lw);
                cairo_move_to(cr, x1, y1);
                cairo_line_to(cr, x2, y2);
                cairo_stroke(cr);
            }

            // Hour hand
            double hr_angle = (tm->tm_hour % 12 + tm->tm_min / 60.0 + tm->tm_sec / 3600.0) * (M_PI / 6.0);
            cairo_set_source_rgb(cr, 0.1, 0.1, 0.1);
            cairo_set_line_width(cr, 3.5);
            cairo_set_line_cap(cr, CAIRO_LINE_CAP_ROUND);
            cairo_move_to(cr, cx - 0.15 * radius * sin(hr_angle), cy + 0.15 * radius * cos(hr_angle));
            cairo_line_to(cr, cx + 0.55 * radius * sin(hr_angle), cy - 0.55 * radius * cos(hr_angle));
            cairo_stroke(cr);

            // Minute hand
            double min_angle = (tm->tm_min + tm->tm_sec / 60.0) * (M_PI / 30.0);
            cairo_set_line_width(cr, 2.2);
            cairo_move_to(cr, cx - 0.2 * radius * sin(min_angle), cy + 0.2 * radius * cos(min_angle));
            cairo_line_to(cr, cx + 0.8 * radius * sin(min_angle), cy - 0.8 * radius * cos(min_angle));
            cairo_stroke(cr);

            // Second hand (subdued warm red/terracotta)
            double sec_angle = tm->tm_sec * (M_PI / 30.0);
            cairo_set_source_rgb(cr, 0.65, 0.2, 0.2);
            cairo_set_line_width(cr, 1.2);
            cairo_move_to(cr, cx - 0.22 * radius * sin(sec_angle), cy + 0.22 * radius * cos(sec_angle));
            cairo_line_to(cr, cx + 0.86 * radius * sin(sec_angle), cy - 0.86 * radius * cos(sec_angle));
            cairo_stroke(cr);

            // Center pivot
            cairo_arc(cr, cx, cy, 3.5, 0, 2 * M_PI);
            cairo_fill(cr);
        }

        cairo_surface_flush(cs);
        XFlush(dpy);
        usleep(250000); // 4 fps refresh
    }

    cairo_destroy(cr);
    cairo_surface_destroy(cs);
    XDestroyWindow(dpy, win);
    XCloseDisplay(dpy);
    return 0;
}
