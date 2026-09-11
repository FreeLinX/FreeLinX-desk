#include <stdio.h>
#include <stdlib.h>
#include <math.h>
#include <unistd.h>
#include <X11/Xlib.h>
#include <X11/Xutil.h>
#include <cairo/cairo.h>
#include <cairo/cairo-xlib.h>

static void draw_eye(cairo_t *cr, double cx, double cy, double rx, double ry, double mx, double my) {
    cairo_save(cr);
    cairo_translate(cr, cx, cy);
    cairo_scale(cr, rx, ry);
    cairo_arc(cr, 0, 0, 1.0, 0, 2 * M_PI);
    cairo_restore(cr);
    cairo_set_source_rgb(cr, 0, 0, 0);
    cairo_set_line_width(cr, 8.0);
    cairo_stroke_preserve(cr);
    cairo_set_source_rgb(cr, 1, 1, 1);
    cairo_fill(cr);

    double dx = mx - cx;
    double dy = my - cy;
    double dist = hypot(dx, dy);
    double prx = rx * 0.55;
    double pry = ry * 0.55;
    double px = cx, py = cy;
    if (dist > 0.001) {
        double angle = atan2(dy, dx);
        double max_dist = 1.0 / hypot(cos(angle)/prx, sin(angle)/pry);
        double d = dist < max_dist ? dist : max_dist;
        px = cx + d * cos(angle);
        py = cy + d * sin(angle);
    }

    cairo_save(cr);
    cairo_translate(cr, px, py);
    cairo_scale(cr, rx * 0.28, ry * 0.28);
    cairo_arc(cr, 0, 0, 1.0, 0, 2 * M_PI);
    cairo_restore(cr);
    cairo_set_source_rgb(cr, 0, 0, 0);
    cairo_fill(cr);
}

int main(void) {
    Display *dpy = XOpenDisplay(NULL);
    if (!dpy) return 1;
    int scr = DefaultScreen(dpy);
    Window root = RootWindow(dpy, scr);

    int w = 240, h = 160;
    Window win = XCreateSimpleWindow(dpy, root, 100, 100, w, h, 0,
                                     BlackPixel(dpy, scr), WhitePixel(dpy, scr));
    XStoreName(dpy, win, "xeyes");
    XClassHint ch = {"xeyes", "Xeyes"};
    XSetClassHint(dpy, win, &ch);
    XSelectInput(dpy, win, ExposureMask | StructureNotifyMask | KeyPressMask);
    XMapWindow(dpy, win);

    cairo_surface_t *cs = cairo_xlib_surface_create(dpy, win, DefaultVisual(dpy, scr), w, h);
    cairo_t *cr = cairo_create(cs);

    while (1) {
        while (XPending(dpy)) {
            XEvent ev;
            XNextEvent(dpy, &ev);
            if (ev.type == ConfigureNotify) {
                w = ev.xconfigure.width;
                h = ev.xconfigure.height;
                cairo_xlib_surface_set_size(cs, w, h);
            } else if (ev.type == KeyPress) {
                KeySym ks = XLookupKeysym(&ev.xkey, 0);
                if (ks == XK_Escape || ks == XK_q) goto done;
            }
        }

        Window r_root, r_child;
        int rx, ry, wx, wy;
        unsigned int mask;
        XQueryPointer(dpy, win, &r_root, &r_child, &rx, &ry, &wx, &wy, &mask);

        cairo_set_source_rgb(cr, 0.75, 0.75, 0.75);
        cairo_paint(cr);

        double ey_w = w / 4.0;
        double ey_h = h / 2.0 - 8;
        draw_eye(cr, w * 0.28, h * 0.5, ey_w * 0.85, ey_h, wx, wy);
        draw_eye(cr, w * 0.72, h * 0.5, ey_w * 0.85, ey_h, wx, wy);
        XFlush(dpy);
        usleep(30000);
    }

done:
    cairo_destroy(cr);
    cairo_surface_destroy(cs);
    XDestroyWindow(dpy, win);
    XCloseDisplay(dpy);
    return 0;
}
