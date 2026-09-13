/*
 * FreeLinX Screen Magnifier (xmag)
 *
 * Realtime screen magnifier and pixel inspector for FreeLinX Desktop.
 * Captures the screen area around the pointer and renders at 2x/4x/8x zoom
 * with exact hex/RGB color readout and crosshairs.
 */

#define _GNU_SOURCE
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <X11/Xlib.h>
#include <X11/Xutil.h>
#include <X11/Xatom.h>
#include <X11/keysym.h>
#include <cairo/cairo.h>
#include <cairo/cairo-xlib.h>

#define WIN_W 340
#define WIN_H 360
#define INFO_H 34

static int zoom = 4;
static int frozen = 0;
static int sample_x = 0, sample_y = 0;

int main(int argc, char **argv)
{
    Display *dpy = XOpenDisplay(NULL);
    if (!dpy) {
        fprintf(stderr, "xmag: Cannot open display\n");
        return 1;
    }

    int screen = DefaultScreen(dpy);
    Window root = RootWindow(dpy, screen);
    int screen_w = DisplayWidth(dpy, screen);
    int screen_h = DisplayHeight(dpy, screen);

    XSetWindowAttributes swa;
    swa.background_pixel = BlackPixel(dpy, screen);
    swa.event_mask = ExposureMask | KeyPressMask | ButtonPressMask | StructureNotifyMask;

    Window win = XCreateWindow(dpy, root, 100, 100, WIN_W, WIN_H, 0,
                               DefaultDepth(dpy, screen), InputOutput,
                               DefaultVisual(dpy, screen),
                               CWBackPixel | CWEventMask, &swa);

    XSizeHints hints;
    hints.flags = PPosition | PSize | PMinSize;
    hints.x = 100;
    hints.y = 100;
    hints.width = WIN_W;
    hints.height = WIN_H;
    hints.min_width = 240;
    hints.min_height = 240;
    XSetStandardProperties(dpy, win, "xmag", "xmag", None, argv, argc, &hints);

    XClassHint ch = {"xmag", "FreeLinX"};
    XSetClassHint(dpy, win, &ch);

    Atom wm_delete_window = XInternAtom(dpy, "WM_DELETE_WINDOW", False);
    XSetWMProtocols(dpy, win, &wm_delete_window, 1);

    XMapWindow(dpy, win);

    cairo_surface_t *cs = cairo_xlib_surface_create(dpy, win, DefaultVisual(dpy, screen), WIN_W, WIN_H);
    cairo_t *cr = cairo_create(cs);

    int win_w = WIN_W, win_h = WIN_H;
    int running = 1;

    while (running) {
        while (XPending(dpy) > 0) {
            XEvent ev;
            XNextEvent(dpy, &ev);
            if (ev.type == KeyPress) {
                KeySym sym = XLookupKeysym(&ev.xkey, 0);
                if (sym == XK_Escape || sym == XK_q || sym == XK_Q) {
                    running = 0;
                    break;
                } else if (sym == XK_plus || sym == XK_equal || sym == XK_KP_Add) {
                    if (zoom < 16) zoom *= 2;
                } else if (sym == XK_minus || sym == XK_underscore || sym == XK_KP_Subtract) {
                    if (zoom > 2) zoom /= 2;
                } else if (sym == XK_space) {
                    frozen = !frozen;
                }
            } else if (ev.type == ButtonPress) {
                frozen = !frozen;
            } else if (ev.type == ConfigureNotify) {
                if (ev.xconfigure.width != win_w || ev.xconfigure.height != win_h) {
                    win_w = ev.xconfigure.width;
                    win_h = ev.xconfigure.height;
                    cairo_xlib_surface_set_size(cs, win_w, win_h);
                }
            } else if (ev.type == ClientMessage) {
                if ((Atom)ev.xclient.data.l[0] == wm_delete_window) {
                    running = 0;
                    break;
                }
            }
        }

        if (!running) break;

        /* Query current pointer position on root window */
        if (!frozen) {
            Window root_ret, child_ret;
            int win_x, win_y;
            unsigned int mask;
            XQueryPointer(dpy, root, &root_ret, &child_ret, &sample_x, &sample_y,
                          &win_x, &win_y, &mask);
        }

        /* Calculate capture rect */
        int view_w = win_w;
        int view_h = win_h - INFO_H;
        int src_w = view_w / zoom;
        int src_h = view_h / zoom;
        if (src_w < 1) src_w = 1;
        if (src_h < 1) src_h = 1;

        int src_x = sample_x - src_w / 2;
        int src_y = sample_y - src_h / 2;

        if (src_x < 0) src_x = 0;
        if (src_y < 0) src_y = 0;
        if (src_x + src_w > screen_w) src_x = screen_w - src_w;
        if (src_y + src_h > screen_h) src_y = screen_h - src_h;

        XImage *img = XGetImage(dpy, root, src_x, src_y, src_w, src_h, AllPlanes, ZPixmap);

        /* Draw background */
        cairo_set_source_rgb(cr, 0.15, 0.15, 0.15);
        cairo_paint(cr);

        unsigned long center_pixel = 0;

        if (img) {
            /* Magnify pixels onto view area */
            for (int py = 0; py < src_h; py++) {
                for (int px = 0; px < src_w; px++) {
                    unsigned long pixel = XGetPixel(img, px, py);
                    if (src_x + px == sample_x && src_y + py == sample_y)
                        center_pixel = pixel;

                    double r = ((pixel >> 16) & 0xFF) / 255.0;
                    double g = ((pixel >> 8) & 0xFF) / 255.0;
                    double b = (pixel & 0xFF) / 255.0;

                    cairo_set_source_rgb(cr, r, g, b);
                    cairo_rectangle(cr, px * zoom, py * zoom, zoom, zoom);
                    cairo_fill(cr);
                }
            }
            XDestroyImage(img);
        }

        /* Draw crosshair at center */
        int cx = (sample_x - src_x) * zoom + zoom / 2;
        int cy = (sample_y - src_y) * zoom + zoom / 2;

        cairo_set_line_width(cr, 1.0);
        cairo_set_source_rgb(cr, 1.0, 1.0, 1.0);
        cairo_rectangle(cr, cx - zoom / 2 - 0.5, cy - zoom / 2 - 0.5, zoom + 1, zoom + 1);
        cairo_stroke(cr);

        cairo_set_source_rgb(cr, 0.0, 0.0, 0.0);
        cairo_rectangle(cr, cx - zoom / 2 + 0.5, cy - zoom / 2 + 0.5, zoom - 1, zoom - 1);
        cairo_stroke(cr);

        /* Draw Info bar at bottom */
        cairo_set_source_rgb(cr, 0.92, 0.92, 0.92);
        cairo_rectangle(cr, 0, win_h - INFO_H, win_w, INFO_H);
        cairo_fill(cr);

        cairo_set_source_rgb(cr, 0.7, 0.7, 0.7);
        cairo_move_to(cr, 0, win_h - INFO_H + 0.5);
        cairo_line_to(cr, win_w, win_h - INFO_H + 0.5);
        cairo_stroke(cr);

        /* Color preview swatch */
        double cr_r = ((center_pixel >> 16) & 0xFF) / 255.0;
        double cr_g = ((center_pixel >> 8) & 0xFF) / 255.0;
        double cr_b = (center_pixel & 0xFF) / 255.0;

        cairo_set_source_rgb(cr, cr_r, cr_g, cr_b);
        cairo_rectangle(cr, 8, win_h - INFO_H + 7, 20, 20);
        cairo_fill(cr);
        cairo_set_source_rgb(cr, 0.3, 0.3, 0.3);
        cairo_rectangle(cr, 7.5, win_h - INFO_H + 6.5, 21, 21);
        cairo_stroke(cr);

        /* Status text */
        char info_str[128];
        snprintf(info_str, sizeof(info_str), "%dx | %4d,%4d | #%02X%02X%02X %s",
                 zoom, sample_x, sample_y,
                 (int)((center_pixel >> 16) & 0xFF),
                 (int)((center_pixel >> 8) & 0xFF),
                 (int)(center_pixel & 0xFF),
                 frozen ? "[PAUSED]" : "");

        cairo_select_font_face(cr, "monospace", CAIRO_FONT_SLANT_NORMAL, CAIRO_FONT_WEIGHT_BOLD);
        cairo_set_font_size(cr, 11.0);
        cairo_set_source_rgb(cr, 0.1, 0.1, 0.1);
        cairo_move_to(cr, 36, win_h - INFO_H + 21);
        cairo_show_text(cr, info_str);

        XFlush(dpy);
        usleep(33000); /* ~30 FPS refresh */
    }

    cairo_destroy(cr);
    cairo_surface_destroy(cs);
    XDestroyWindow(dpy, win);
    XCloseDisplay(dpy);
    return 0;
}
