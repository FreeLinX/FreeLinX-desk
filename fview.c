#define _GNU_SOURCE
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <dirent.h>
#include <sys/stat.h>
#include <time.h>
#include <unistd.h>
#include <X11/Xlib.h>
#include <X11/Xutil.h>
#include <X11/Xatom.h>
#include <cairo/cairo.h>
#include <cairo/cairo-xlib.h>

#define MAX_ITEMS 512
#define WIN_W 460
#define WIN_H 285

typedef struct {
    char name[256];
    char size_str[64];
    char type_str[64];
    char date_str[64];
    int is_dir;
} FileItem;

static FileItem items[MAX_ITEMS];
static int item_count = 0;
static int selected_idx = -1;
static char current_path[1024] = "/etc/xdg/openbox";

static void format_size(off_t sz, char *out) {
    if (sz < 1024)
        snprintf(out, 64, "%ld B", (long)sz);
    else if (sz < 1024 * 1024)
        snprintf(out, 64, "%.1f kB", (double)sz / 1024.0);
    else
        snprintf(out, 64, "%.1f MB", (double)sz / (1024.0 * 1024.0));
}

static void format_type(const char *name, int is_dir, char *out) {
    if (is_dir) {
        strcpy(out, "Folder");
        return;
    }
    const char *ext = strrchr(name, '.');
    if (!ext) {
        strcpy(out, "Document");
        return;
    }
    if (strcmp(ext, ".xml") == 0) strcpy(out, "XML document");
    else if (strcmp(ext, ".sh") == 0) strcpy(out, "shell script");
    else if (strcmp(ext, ".txt") == 0) strcpy(out, "Text file");
    else if (strcmp(ext, ".conf") == 0) strcpy(out, "Config file");
    else snprintf(out, 64, "%s file", ext + 1);
}

static void format_date(time_t mtime, char *out) {
    time_t now = time(NULL);
    struct tm *tm_info = localtime(&mtime);
    if (now - mtime < 86400 * 2) {
        strcpy(out, "Yesterday");
    } else {
        strftime(out, 64, "%m/%d/%Y", tm_info);
    }
}

static void load_directory(const char *path) {
    item_count = 0;
    DIR *d = opendir(path);
    if (!d) return;

    struct dirent *de;
    while ((de = readdir(d)) != NULL && item_count < MAX_ITEMS) {
        if (strcmp(de->d_name, ".") == 0 || strcmp(de->d_name, "..") == 0)
            continue;

        FileItem *fi = &items[item_count];
        strncpy(fi->name, de->d_name, sizeof(fi->name) - 1);

        char fullpath[2048];
        snprintf(fullpath, sizeof(fullpath), "%s/%s", path, de->d_name);
        struct stat st;
        if (stat(fullpath, &st) == 0) {
            fi->is_dir = S_ISDIR(st.st_mode);
            format_size(st.st_size, fi->size_str);
            format_type(de->d_name, fi->is_dir, fi->type_str);
            format_date(st.st_mtime, fi->date_str);
        } else {
            fi->is_dir = 0;
            strcpy(fi->size_str, "0 B");
            strcpy(fi->type_str, "Unknown");
            strcpy(fi->date_str, "Unknown");
        }
        item_count++;
    }
    closedir(d);
    if (selected_idx >= item_count) selected_idx = -1;
}

static void draw_retro_bevel(cairo_t *cr, double x, double y, double w, double h, int raised) {
    cairo_set_line_width(cr, 1.0);
    if (raised) {
        cairo_set_source_rgb(cr, 1.0, 1.0, 1.0);
    } else {
        cairo_set_source_rgb(cr, 0.45, 0.45, 0.45);
    }
    cairo_move_to(cr, x, y + h);
    cairo_line_to(cr, x, y);
    cairo_line_to(cr, x + w, y);
    cairo_stroke(cr);

    if (raised) {
        cairo_set_source_rgb(cr, 0.45, 0.45, 0.45);
    } else {
        cairo_set_source_rgb(cr, 1.0, 1.0, 1.0);
    }
    cairo_move_to(cr, x + w, y);
    cairo_line_to(cr, x + w, y + h);
    cairo_line_to(cr, x, y + h);
    cairo_stroke(cr);
}

static void draw_ui(cairo_t *cr, int win_w, int win_h) {
    cairo_set_source_rgb(cr, 0.91, 0.91, 0.90);
    cairo_paint(cr);

    cairo_select_font_face(cr, "sans-serif", CAIRO_FONT_SLANT_NORMAL, CAIRO_FONT_WEIGHT_NORMAL);
    cairo_set_font_size(cr, 11.0);
    cairo_set_source_rgb(cr, 0.1, 0.1, 0.1);

    const char *menus[] = {"File", "Edit", "View", "Go", "Help"};
    double mx = 10;
    for (int i = 0; i < 5; i++) {
        cairo_move_to(cr, mx, 16);
        cairo_show_text(cr, menus[i]);
        mx += 35;
    }

    cairo_set_source_rgb(cr, 0.75, 0.75, 0.75);
    cairo_set_line_width(cr, 1.0);
    cairo_move_to(cr, 0, 24);
    cairo_line_to(cr, win_w, 24);
    cairo_stroke(cr);

    double by = 28;
    double bh = 24;
    cairo_set_source_rgb(cr, 0.94, 0.94, 0.94);
    cairo_rectangle(cr, 6, by, win_w - 12, bh);
    cairo_fill(cr);
    draw_retro_bevel(cr, 6, by, win_w - 12, bh, 0);

    cairo_select_font_face(cr, "sans-serif", CAIRO_FONT_SLANT_NORMAL, CAIRO_FONT_WEIGHT_BOLD);
    cairo_set_font_size(cr, 10.0);
    cairo_set_source_rgb(cr, 0.2, 0.2, 0.2);

    cairo_rectangle(cr, 12, by + 6, 12, 10);
    cairo_set_source_rgb(cr, 0.85, 0.70, 0.35);
    cairo_fill(cr);

    char pbuf[1024];
    strncpy(pbuf, current_path, sizeof(pbuf));
    char *token = strtok(pbuf, "/");
    double px = 32;
    while (token) {
        cairo_text_extents_t ext;
        cairo_text_extents(cr, token, &ext);
        double btn_w = ext.width + 16;
        if (btn_w < 36) btn_w = 36;

        cairo_set_source_rgb(cr, 0.90, 0.90, 0.89);
        cairo_rectangle(cr, px, by + 3, btn_w, 18);
        cairo_fill(cr);
        draw_retro_bevel(cr, px, by + 3, btn_w, 18, 1);

        cairo_set_source_rgb(cr, 0.15, 0.15, 0.15);
        cairo_move_to(cr, px + 8, by + 15);
        cairo_show_text(cr, token);
        px += btn_w + 3;
        token = strtok(NULL, "/");
    }

    double hy = 58;
    double hh = 20;
    cairo_set_source_rgb(cr, 0.88, 0.88, 0.88);
    cairo_rectangle(cr, 6, hy, win_w - 12, hh);
    cairo_fill(cr);
    draw_retro_bevel(cr, 6, hy, win_w - 12, hh, 1);

    // Column separators in header
    draw_retro_bevel(cr, 150, hy + 2, 2, hh - 4, 0);
    draw_retro_bevel(cr, 210, hy + 2, 2, hh - 4, 0);
    draw_retro_bevel(cr, 315, hy + 2, 2, hh - 4, 0);

    cairo_set_source_rgb(cr, 0.2, 0.2, 0.2);
    cairo_select_font_face(cr, "sans-serif", CAIRO_FONT_SLANT_NORMAL, CAIRO_FONT_WEIGHT_NORMAL);
    cairo_set_font_size(cr, 11.0);

    cairo_move_to(cr, 12, hy + 14);
    cairo_show_text(cr, "Name");
    cairo_move_to(cr, 138, hy + 14);
    cairo_show_text(cr, "▾");

    cairo_move_to(cr, 158, hy + 14);
    cairo_show_text(cr, "Size");

    cairo_move_to(cr, 218, hy + 14);
    cairo_show_text(cr, "Type");

    cairo_move_to(cr, 324, hy + 14);
    cairo_show_text(cr, "Date Modified");

    double ly = 78;
    double lh = win_h - ly - 22;
    double lw = win_w - 24;

    cairo_set_source_rgb(cr, 1.0, 1.0, 1.0);
    cairo_rectangle(cr, 6, ly, lw, lh);
    cairo_fill(cr);
    draw_retro_bevel(cr, 6, ly, lw, lh, 0);

    // Retro vertical scrollbar
    double sb_x = 6 + lw + 1;
    double sb_w = 11;
    cairo_set_source_rgb(cr, 0.90, 0.90, 0.89);
    cairo_rectangle(cr, sb_x, ly, sb_w, lh);
    cairo_fill(cr);
    draw_retro_bevel(cr, sb_x, ly, sb_w, lh, 0);
    // Up arrow button
    draw_retro_bevel(cr, sb_x, ly, sb_w, 12, 1);
    // Down arrow button
    draw_retro_bevel(cr, sb_x, ly + lh - 12, sb_w, 12, 1);
    // Thumb
    draw_retro_bevel(cr, sb_x, ly + 20, sb_w, 35, 1);

    // Retro horizontal scrollbar at bottom
    double hsb_y = ly + lh + 2;
    double hsb_h = 12;
    cairo_set_source_rgb(cr, 0.90, 0.90, 0.89);
    cairo_rectangle(cr, 6, hsb_y, lw, hsb_h);
    cairo_fill(cr);
    draw_retro_bevel(cr, 6, hsb_y, lw, hsb_h, 0);
    draw_retro_bevel(cr, 6, hsb_y, 14, hsb_h, 1);
    draw_retro_bevel(cr, 6 + lw - 14, hsb_y, 14, hsb_h, 1);

    double ry = ly + 4;
    for (int i = 0; i < item_count && ry + 16 < ly + lh; i++) {
        if (i == selected_idx) {
            cairo_set_source_rgb(cr, 0.29, 0.56, 0.85);
            cairo_rectangle(cr, 7, ry - 1, lw - 2, 18);
            cairo_fill(cr);
            cairo_set_source_rgb(cr, 1.0, 1.0, 1.0);
        } else {
            cairo_set_source_rgb(cr, 0.1, 0.1, 0.1);
        }

        // File/folder icon
        if (items[i].is_dir) {
            cairo_set_source_rgb(cr, 0.85, 0.70, 0.35);
            cairo_rectangle(cr, 12, ry + 2, 10, 10);
            cairo_fill(cr);
        } else {
            cairo_set_source_rgb(cr, 0.72, 0.75, 0.80);
            cairo_rectangle(cr, 12, ry + 2, 9, 11);
            cairo_fill(cr);
            cairo_set_source_rgb(cr, 0.45, 0.45, 0.45);
            cairo_set_line_width(cr, 1.0);
            cairo_rectangle(cr, 12, ry + 2, 9, 11);
            cairo_stroke(cr);
        }

        if (i == selected_idx) {
            cairo_set_source_rgb(cr, 1.0, 1.0, 1.0);
        } else {
            cairo_set_source_rgb(cr, 0.1, 0.1, 0.1);
        }

        cairo_move_to(cr, 28, ry + 12);
        cairo_show_text(cr, items[i].name);

        cairo_move_to(cr, 158, ry + 12);
        cairo_show_text(cr, items[i].size_str);

        cairo_move_to(cr, 218, ry + 12);
        cairo_show_text(cr, items[i].type_str);

        cairo_move_to(cr, 324, ry + 12);
        cairo_show_text(cr, items[i].date_str);

        ry += 19;
    }
}

static void open_item(int idx) {
    if (idx < 0 || idx >= item_count) return;
    if (items[idx].is_dir) {
        char next[2048];
        snprintf(next, sizeof(next), "%s/%s", current_path, items[idx].name);
        strncpy(current_path, next, sizeof(current_path));
        load_directory(current_path);
    } else {
        char cmd[2048];
        snprintf(cmd, sizeof(cmd), "uxterm -title uxterm -e vim '%s/%s' &", current_path, items[idx].name);
        system(cmd);
    }
}

int main(int argc, char **argv) {
    if (argc > 1) {
        strncpy(current_path, argv[1], sizeof(current_path));
    }
    load_directory(current_path);

    Display *dpy = XOpenDisplay(NULL);
    if (!dpy) {
        fprintf(stderr, "fview: Cannot open X display\n");
        return 1;
    }

    int screen = DefaultScreen(dpy);
    Window root = RootWindow(dpy, screen);

    XSetWindowAttributes swa;
    swa.background_pixel = WhitePixel(dpy, screen);
    swa.event_mask = ExposureMask | KeyPressMask | ButtonPressMask | StructureNotifyMask;

    Window win = XCreateWindow(dpy, root, 20, 390, WIN_W, WIN_H, 0,
                               DefaultDepth(dpy, screen), InputOutput,
                               DefaultVisual(dpy, screen),
                               CWBackPixel | CWEventMask, &swa);

    XStoreName(dpy, win, "openbox - File Manager");
    XClassHint ch = {"openbox - File Manager", "Openbox"};
    XSetClassHint(dpy, win, &ch);

    XSizeHints hints;
    hints.flags = USPosition | USSize;
    hints.x = 15;
    hints.y = 415;
    hints.width = WIN_W;
    hints.height = WIN_H;
    XSetWMNormalHints(dpy, win, &hints);

    XMapWindow(dpy, win);
    XFlush(dpy);

    cairo_surface_t *cs = cairo_xlib_surface_create(dpy, win, DefaultVisual(dpy, screen), WIN_W, WIN_H);
    cairo_t *cr = cairo_create(cs);

    int win_w = WIN_W;
    int win_h = WIN_H;
    XEvent ev;
    int running = 1;

    while (running) {
        XNextEvent(dpy, &ev);
        switch (ev.type) {
            case Expose:
                if (ev.xexpose.count == 0) {
                    draw_ui(cr, win_w, win_h);
                    XFlush(dpy);
                }
                break;
            case ConfigureNotify:
                if (ev.xconfigure.width != win_w || ev.xconfigure.height != win_h) {
                    win_w = ev.xconfigure.width;
                    win_h = ev.xconfigure.height;
                    cairo_xlib_surface_set_size(cs, win_w, win_h);
                    draw_ui(cr, win_w, win_h);
                    XFlush(dpy);
                }
                break;
            case ButtonPress: {
                int my = ev.xbutton.y;
                if (my >= 78) {
                    int clicked = (my - 78) / 19;
                    if (clicked >= 0 && clicked < item_count) {
                        if (clicked == selected_idx) {
                            open_item(clicked);
                        } else {
                            selected_idx = clicked;
                        }
                        draw_ui(cr, win_w, win_h);
                        XFlush(dpy);
                    }
                }
                break;
            }
            case KeyPress: {
                KeySym ks = XLookupKeysym(&ev.xkey, 0);
                if (ks == XK_Return) {
                    open_item(selected_idx);
                    draw_ui(cr, win_w, win_h);
                    XFlush(dpy);
                } else if (ks == XK_Down) {
                    if (selected_idx < item_count - 1) selected_idx++;
                    draw_ui(cr, win_w, win_h);
                    XFlush(dpy);
                } else if (ks == XK_Up) {
                    if (selected_idx > 0) selected_idx--;
                    draw_ui(cr, win_w, win_h);
                    XFlush(dpy);
                } else if (ks == XK_BackSpace) {
                    char *slash = strrchr(current_path, '/');
                    if (slash && slash != current_path) {
                        *slash = '\0';
                        load_directory(current_path);
                        draw_ui(cr, win_w, win_h);
                        XFlush(dpy);
                    }
                } else if (ks == XK_Escape || ks == XK_q) {
                    running = 0;
                }
                break;
            }
        }
    }

    cairo_destroy(cr);
    cairo_surface_destroy(cs);
    XDestroyWindow(dpy, win);
    XCloseDisplay(dpy);
    return 0;
}
