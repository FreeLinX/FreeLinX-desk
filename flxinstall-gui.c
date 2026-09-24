/*
 * FreeLinX Installer GUI (flxinstall-gui)
 * Retro X11 + Cairo wizard that drives /sbin/flxinstall in preset mode.
 * Consistent with the project's hand-rolled cairo apps (flxnetmgr, xfi, ...).
 */
#define _GNU_SOURCE
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <dirent.h>
#include <fcntl.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <errno.h>

#include <X11/Xlib.h>
#include <X11/Xutil.h>
#include <X11/Xatom.h>
#include <X11/keysym.h>

#include <cairo/cairo.h>
#include <cairo/cairo-xlib.h>

#define WIN_W 680
#define WIN_H 500

/* ---- wizard pages -------------------------------------------------------- */
enum {
    PG_WELCOME, PG_LANG, PG_KBD, PG_TZ, PG_HOST, PG_ROOTPW,
    PG_USER, PG_WIFI, PG_DESK, PG_DISK, PG_CONFIRM, PG_DONE, PG_COUNT
};

static int page = PG_WELCOME;
static int running = 1;
static char status_msg[160] = "FreeLinX Installer ready.";

/* ---- wizard data --------------------------------------------------------- */
static char sel_lang[64] = "English (en_US.UTF-8)";
static char sel_kbd[16]  = "us";
static char sel_tz[16]   = "UTC0";
static char hostname[64] = "freelinx";
static char rootpw[64]   = "";
static int  user_en = 0;
static char username[64] = "";
static char realname[64] = "";
static char userpw[64]   = "";
static int  wifi_en = 0;
static char wifissid[64] = "";
static char wifipass[64] = "";
static int  desktop_gui = 1;   /* 1 = GUI, 0 = headless */
static char target_disk[64] = "";
static int  active_field = 0;  /* focused text field on the current page */

/* ---- generic list/data --------------------------------------------------- */
#define MAX_ITEMS 24
typedef struct {
    char items[MAX_ITEMS][80];
    int  count;
    int  sel;
    int  top;                  /* first visible row (scrolling) */
} PgList;

static PgList lang_list, kbd_list, tz_list, desk_list, disk_list;

/* ---- install job --------------------------------------------------------- */
enum { INST_IDLE, INST_RUNNING, INST_DONE, INST_ERROR };
static int inst_state = INST_IDLE;
static int inst_fd = -1;
static pid_t inst_pid = -1;
static char inst_log[32768];
static size_t inst_log_len = 0;
static int inst_col = 0;

/* ---- retro UI helpers (same style as flxnetmgr) -------------------------- */
static void draw_bevel(cairo_t *cr, double x, double y, double w, double h, int raised) {
    cairo_set_line_width(cr, 1.0);
    cairo_set_source_rgb(cr, raised ? 1.0 : 0.4, raised ? 1.0 : 0.4, raised ? 1.0 : 0.4);
    cairo_move_to(cr, x, y + h);
    cairo_line_to(cr, x, y);
    cairo_line_to(cr, x + w, y);
    cairo_stroke(cr);
    cairo_set_source_rgb(cr, raised ? 0.4 : 1.0, raised ? 0.4 : 1.0, raised ? 0.4 : 1.0);
    cairo_move_to(cr, x + w, y);
    cairo_line_to(cr, x + w, y + h);
    cairo_line_to(cr, x, y + h);
    cairo_stroke(cr);
}

static void draw_button(cairo_t *cr, double x, double y, double w, double h,
                        const char *label, int enabled) {
    cairo_set_source_rgb(cr, 0.88, 0.88, 0.86);
    cairo_rectangle(cr, x, y, w, h);
    cairo_fill(cr);
    draw_bevel(cr, x, y, w, h, enabled ? 1 : 0);
    cairo_select_font_face(cr, "sans-serif", CAIRO_FONT_SLANT_NORMAL, CAIRO_FONT_WEIGHT_BOLD);
    cairo_set_font_size(cr, 11.0);
    cairo_set_source_rgb(cr, enabled ? 0.12 : 0.55, enabled ? 0.12 : 0.55, enabled ? 0.12 : 0.55);
    cairo_text_extents_t ext;
    cairo_text_extents(cr, label, &ext);
    cairo_move_to(cr, x + (w - ext.width) / 2.0, y + (h + ext.height) / 2.0 - 1.0);
    cairo_show_text(cr, label);
}

static void draw_list(cairo_t *cr, PgList *pl, double x, double y, double w, double h,
                      const char *hint) {
    cairo_set_source_rgb(cr, 0.82, 0.82, 0.80);
    cairo_rectangle(cr, x, y, w, 22);
    cairo_fill(cr);
    draw_bevel(cr, x, y, w, 22, 1);
    cairo_select_font_face(cr, "sans-serif", CAIRO_FONT_SLANT_NORMAL, CAIRO_FONT_WEIGHT_BOLD);
    cairo_set_font_size(cr, 10.5);
    cairo_set_source_rgb(cr, 0.2, 0.2, 0.2);
    cairo_move_to(cr, x + 8, y + 16);
    cairo_show_text(cr, hint);

    int visible = (int)((h - 24) / 21);
    if (visible < 1) visible = 1;
    if (pl->count == 0) {
        cairo_select_font_face(cr, "sans-serif", CAIRO_FONT_SLANT_ITALIC, CAIRO_FONT_WEIGHT_NORMAL);
        cairo_set_font_size(cr, 10.5);
        cairo_set_source_rgb(cr, 0.5, 0.5, 0.5);
        cairo_move_to(cr, x + 8, y + 50);
        cairo_show_text(cr, "(nothing available)");
        return;
    }
    if (pl->sel < pl->top) pl->top = pl->sel;
    if (pl->sel >= pl->top + visible) pl->top = pl->sel - visible + 1;

    char buf[96];
    double ry = y + 24;
    for (int i = pl->top; i < pl->count && i < pl->top + visible; i++) {
        if (i == pl->sel) {
            cairo_set_source_rgb(cr, 0.22, 0.40, 0.65);
            cairo_rectangle(cr, x + 2, ry + 1, w - 4, 18);
            cairo_fill(cr);
            cairo_set_source_rgb(cr, 1.0, 1.0, 1.0);
        } else {
            cairo_set_source_rgb(cr, 0.15, 0.15, 0.15);
        }
        cairo_select_font_face(cr, "sans-serif", CAIRO_FONT_SLANT_NORMAL, CAIRO_FONT_WEIGHT_NORMAL);
        cairo_set_font_size(cr, 10.5);
        cairo_move_to(cr, x + 8, ry + 14);
        snprintf(buf, sizeof(buf), "%.74s", pl->items[i]);
        cairo_show_text(cr, buf);
        ry += 21;
    }
    if (pl->count > visible) {
        cairo_set_source_rgb(cr, 0.45, 0.45, 0.45);
        cairo_select_font_face(cr, "sans-serif", CAIRO_FONT_SLANT_NORMAL, CAIRO_FONT_WEIGHT_NORMAL);
        cairo_set_font_size(cr, 9.0);
        snprintf(buf, sizeof(buf), "%d/%d", pl->sel + 1, pl->count);
        cairo_move_to(cr, x + w - 40, y + 15);
        cairo_show_text(cr, buf);
    }
}

static void draw_text_field(cairo_t *cr, double x, double y, double w, double h,
                            const char *label, const char *value, int masked,
                            int active, int enabled) {
    cairo_select_font_face(cr, "sans-serif", CAIRO_FONT_SLANT_NORMAL, CAIRO_FONT_WEIGHT_BOLD);
    cairo_set_font_size(cr, 11.0);
    cairo_set_source_rgb(cr, enabled ? 0.15 : 0.55, enabled ? 0.15 : 0.55, enabled ? 0.15 : 0.55);
    cairo_move_to(cr, x, y - 6);
    cairo_show_text(cr, label);

    cairo_set_source_rgb(cr, enabled ? 1.0 : 0.93, enabled ? 1.0 : 0.93, enabled ? 1.0 : 0.93);
    cairo_rectangle(cr, x, y, w, h);
    cairo_fill(cr);
    draw_bevel(cr, x, y, w, h, active ? 0 : 1);
    if (active && enabled) {
        cairo_set_source_rgb(cr, 0.22, 0.55, 0.85);
        cairo_set_line_width(cr, 2.0);
        cairo_rectangle(cr, x, y, w, h);
        cairo_stroke(cr);
    }

    cairo_select_font_face(cr, "monospace", CAIRO_FONT_SLANT_NORMAL, CAIRO_FONT_WEIGHT_NORMAL);
    cairo_set_font_size(cr, 12.0);
    cairo_set_source_rgb(cr, 0.08, 0.08, 0.08);
    char shown[96];
    if (masked && value[0]) {
        size_t n = strlen(value);
        if (n > 70) n = 70;
        memset(shown, '*', n);
        shown[n] = '\0';
    } else {
        snprintf(shown, sizeof(shown), "%s", value);
    }
    cairo_move_to(cr, x + 8, y + h * 0.68);
    cairo_show_text(cr, shown);
}

static void draw_check(cairo_t *cr, double x, double y, int checked, const char *label) {
    cairo_set_source_rgb(cr, 1.0, 1.0, 1.0);
    cairo_rectangle(cr, x, y, 16, 16);
    cairo_fill(cr);
    draw_bevel(cr, x, y, 16, 16, 1);
    if (checked) {
        cairo_set_source_rgb(cr, 0.10, 0.35, 0.60);
        cairo_set_line_width(cr, 2.0);
        cairo_move_to(cr, x + 3, y + 8);
        cairo_line_to(cr, x + 7, y + 12);
        cairo_line_to(cr, x + 13, y + 3);
        cairo_stroke(cr);
    }
    cairo_select_font_face(cr, "sans-serif", CAIRO_FONT_SLANT_NORMAL, CAIRO_FONT_WEIGHT_BOLD);
    cairo_set_font_size(cr, 11.0);
    cairo_set_source_rgb(cr, 0.15, 0.15, 0.15);
    cairo_move_to(cr, x + 24, y + 13);
    cairo_show_text(cr, label);
}

static const char *page_title(int pg) {
    switch (pg) {
        case PG_WELCOME: return "Welcome";
        case PG_LANG:    return "Language";
        case PG_KBD:     return "Keyboard layout";
        case PG_TZ:      return "Timezone";
        case PG_HOST:    return "Hostname";
        case PG_ROOTPW:  return "Root password";
        case PG_USER:    return "User account";
        case PG_WIFI:    return "WiFi (optional)";
        case PG_DESK:    return "Desktop environment";
        case PG_DISK:    return "Target disk";
        case PG_CONFIRM: return "Confirm & install";
        case PG_DONE:    return "Installation finished";
    }
    return "";
}

/* ---- install job --------------------------------------------------------- */
static void shell_quote(FILE *f, const char *key, const char *val) {
    fprintf(f, "%s='", key);
    for (const char *p = val; *p; p++) {
        if (*p == '\'') fputs("'\\''", f);
        else fputc(*p, f);
    }
    fputs("'\n", f);
}

static void log_puts(const char *s) {
    for (; *s; s++) {
        if (*s == '\n') {
            inst_col = 0;
        } else {
            if (inst_log_len < sizeof(inst_log) - 2) {
                inst_log[inst_log_len++] = *s;
                inst_log[inst_log_len] = '\0';
            }
            inst_col++;
            if (inst_col >= 84 && inst_log_len < sizeof(inst_log) - 2) {
                inst_log[inst_log_len++] = '\n';
                inst_log[inst_log_len] = '\0';
                inst_col = 0;
            }
        }
    }
}

static void start_install(void) {
    FILE *f = fopen("/tmp/flxinstall-gui.conf", "w");
    if (!f) { snprintf(status_msg, sizeof(status_msg), "Cannot write presets file."); return; }
    shell_quote(f, "LANG_LC", sel_lang);
    shell_quote(f, "KBD_LAYOUT", sel_kbd);
    shell_quote(f, "TZ_STR", sel_tz);
    shell_quote(f, "HOSTNAME", hostname);
    shell_quote(f, "ROOTPW", rootpw);
    if (user_en) {
        shell_quote(f, "USERNAME", username);
        shell_quote(f, "REALNAME", realname);
        shell_quote(f, "USERPW", userpw);
    }
    if (wifi_en && wifissid[0]) {
        shell_quote(f, "WIFISSID", wifissid);
        shell_quote(f, "WIFIPASS", wifipass);
    }
    fprintf(f, "DI=%d\n", desktop_gui ? 2 : 1);
    fclose(f);

    int fds[2];
    if (pipe(fds) != 0) { snprintf(status_msg, sizeof(status_msg), "pipe() failed."); return; }
    pid_t pid = fork();
    if (pid < 0) { snprintf(status_msg, sizeof(status_msg), "fork() failed."); return; }
    if (pid == 0) {
        dup2(fds[1], 1);
        dup2(fds[1], 2);
        close(fds[0]);
        execl("/sbin/flxinstall", "flxinstall", "-p", "/tmp/flxinstall-gui.conf",
              "-y", target_disk, (char *)NULL);
        _exit(127);
    }
    close(fds[1]);
    inst_fd = fds[0];
    fcntl(inst_fd, F_SETFL, O_NONBLOCK);
    inst_pid = pid;
    inst_state = INST_RUNNING;
    inst_log_len = 0; inst_log[0] = '\0'; inst_col = 0;
    log_puts(">>> Installing FreeLinX. This may take a minute...\n");
    snprintf(status_msg, sizeof(status_msg), "Installing to %s ...", target_disk);
}

static void poll_install(void) {
    if (inst_state != INST_RUNNING) return;
    char buf[512];
    for (;;) {
        ssize_t n = read(inst_fd, buf, sizeof(buf) - 1);
        if (n < 0) {
            if (errno == EAGAIN || errno == EWOULDBLOCK) break;
            inst_state = INST_ERROR;
            snprintf(status_msg, sizeof(status_msg), "Install pipe error.");
            break;
        }
        if (n == 0) break;
        buf[n] = '\0';
        log_puts(buf);
    }
    if (inst_state == INST_RUNNING && inst_pid > 0) {
        int st = 0;
        pid_t r = waitpid(inst_pid, &st, WNOHANG);
        if (r == inst_pid) {
            inst_state = (WIFEXITED(st) && WEXITSTATUS(st) == 0) ? INST_DONE : INST_ERROR;
            if (inst_state == INST_DONE) {
                log_puts("\n>>> Installation finished successfully.\n");
                snprintf(status_msg, sizeof(status_msg), "Installed. Reboot to use FreeLinX.");
            } else {
                log_puts("\n>>> Installer exited with an error (see log above).\n");
                snprintf(status_msg, sizeof(status_msg), "Installation failed - see log.");
            }
        }
    }
}

static void do_reboot(void) {
    sync();
    system("reboot 2>/dev/null || poweroff -f 2>/dev/null");
}

/* ---- disk enumeration ---------------------------------------------------- */
static void scan_disks(void) {
    disk_list.count = 0;
    disk_list.sel = 0;
    disk_list.top = 0;
    DIR *d = opendir("/sys/block");
    if (!d) return;
    struct dirent *de;
    while ((de = readdir(d)) && disk_list.count < MAX_ITEMS) {
        if (de->d_name[0] == '.') continue;
        if (!strncmp(de->d_name, "loop", 4) || !strncmp(de->d_name, "ram", 3) ||
            !strncmp(de->d_name, "dm-", 3) || !strncmp(de->d_name, "sr", 2) ||
            !strncmp(de->d_name, "zram", 4) || !strncmp(de->d_name, "fd", 2))
            continue;
        char path[256], szbuf[64] = "0";
        snprintf(path, sizeof(path), "/sys/block/%s/size", de->d_name);
        FILE *f = fopen(path, "r");
        if (f) { if (fgets(szbuf, sizeof(szbuf), f)) { /* read */ } fclose(f); }
        unsigned long long sectors = strtoull(szbuf, NULL, 10);
        double gb = (double)sectors * 512.0 / 1073741824.0;
        char model[64] = "";
        snprintf(path, sizeof(path), "/sys/block/%s/device/model", de->d_name);
        f = fopen(path, "r");
        if (f) { if (fgets(model, sizeof(model), f)) { char *nl = strchr(model, '\n'); if (nl) *nl = 0; } fclose(f); }
        snprintf(disk_list.items[disk_list.count], sizeof(disk_list.items[0]),
                 "/dev/%-11s %7.1f GB  %s", de->d_name, gb, model);
        disk_list.count++;
    }
    closedir(d);
}

/* ---- presets for convenience lists --------------------------------------- */
static void fill_lists(void) {
    const char *langs[] = {
        "English (en_US.UTF-8)", "German (de_DE.UTF-8)", "French (fr_FR.UTF-8)",
        "Spanish (es_ES.UTF-8)", "Italian (it_IT.UTF-8)", "Portuguese (pt_PT.UTF-8)",
        "Dutch (nl_NL.UTF-8)", "Turkish (tr_TR.UTF-8)", "Russian (ru_RU.UTF-8)",
        "Arabic (ar_SA.UTF-8)", "Persian (fa_IR.UTF-8)", "Japanese (ja_JP.UTF-8)",
        "Chinese (zh_CN.UTF-8)"
    };
    lang_list.count = sizeof(langs) / sizeof(langs[0]);
    for (int i = 0; i < lang_list.count; i++)
        snprintf(lang_list.items[i], sizeof(lang_list.items[0]), "%s", langs[i]);
    lang_list.sel = lang_list.top = 0;

    const char *kbds[] = {
        "US English (us)", "German (de)", "French (fr)", "British (gb)",
        "Spanish (es)", "Italian (it)", "Portuguese (pt)", "Turkish (tr)",
        "Russian (ru)", "Arabic (ar)", "Persian (fa)", "Japanese (jp)",
        "Custom (enter X layout)"
    };
    kbd_list.count = sizeof(kbds) / sizeof(kbds[0]);
    for (int i = 0; i < kbd_list.count; i++)
        snprintf(kbd_list.items[i], sizeof(kbd_list.items[0]), "%s", kbds[i]);
    kbd_list.sel = kbd_list.top = 0;

    const char *tzs[] = {
        "UTC", "UTC +1 (Berlin/Paris/Rome)", "UTC +2 (Istanbul/Athens)",
        "UTC +3 (Moscow, Nairobi)", "UTC +3:30 (Tehran)", "UTC +4 (Dubai/Baku)",
        "UTC +5:30 (Mumbai)", "UTC +7 (Bangkok/Hanoi)", "UTC +8 (Beijing/Singapore)",
        "UTC +9 (Tokyo/Seoul)", "UTC -5 (New York)", "UTC -6 (Chicago)",
        "UTC -7 (Denver)", "UTC -8 (Los Angeles)", "UTC +0 - Custom (enter POSIX TZ)"
    };
    tz_list.count = sizeof(tzs) / sizeof(tzs[0]);
    for (int i = 0; i < tz_list.count; i++)
        snprintf(tz_list.items[i], sizeof(tz_list.items[0]), "%s", tzs[i]);
    tz_list.sel = tz_list.top = 0;

    const char *desks[] = { "GUI desktop (Openbox + welcome login screen)", "Headless (CLI terminal only)" };
    desk_list.count = 2;
    for (int i = 0; i < 2; i++)
        snprintf(desk_list.items[i], sizeof(desk_list.items[0]), "%s", desks[i]);
    desk_list.sel = desk_list.top = 0;
    desktop_gui = 1;
}

/* ---- drawing ------------------------------------------------------------- */
static void draw_ui(cairo_t *cr, cairo_surface_t *surf) {
    cairo_set_source_rgb(cr, 0.91, 0.91, 0.88);
    cairo_rectangle(cr, 0, 0, WIN_W, WIN_H);
    cairo_fill(cr);

    /* header */
    cairo_set_source_rgb(cr, 0.13, 0.24, 0.40);
    cairo_rectangle(cr, 0, 0, WIN_W, 44);
    cairo_fill(cr);
    cairo_select_font_face(cr, "sans-serif", CAIRO_FONT_SLANT_NORMAL, CAIRO_FONT_WEIGHT_BOLD);
    cairo_set_font_size(cr, 15.0);
    cairo_set_source_rgb(cr, 1.0, 1.0, 1.0);
    cairo_move_to(cr, 14, 28);
    cairo_show_text(cr, "FreeLinX Installer");
    cairo_set_font_size(cr, 11.0);
    cairo_move_to(cr, 210, 27);
    cairo_show_text(cr, page_title(page));
    char step[32];
    snprintf(step, sizeof(step), "Step %d/%d", page + 1, 11);
    cairo_move_to(cr, WIN_W - 80, 27);
    cairo_show_text(cr, step);

    const double cy = 58;
    const double ch = 372;

    if (page == PG_WELCOME) {
        cairo_select_font_face(cr, "sans-serif", CAIRO_FONT_SLANT_NORMAL, CAIRO_FONT_WEIGHT_BOLD);
        cairo_set_font_size(cr, 14.0);
        cairo_set_source_rgb(cr, 0.10, 0.10, 0.10);
        cairo_move_to(cr, 28, 100);
        cairo_show_text(cr, "Install FreeLinX onto this computer.");
        cairo_select_font_face(cr, "sans-serif", CAIRO_FONT_SLANT_NORMAL, CAIRO_FONT_WEIGHT_NORMAL);
        cairo_set_font_size(cr, 11.5);
        cairo_set_source_rgb(cr, 0.25, 0.25, 0.25);
        cairo_move_to(cr, 28, 132);
        cairo_show_text(cr, "Answer a few simple questions (language, users, hostname,");
        cairo_move_to(cr, 28, 150);
        cairo_show_text(cr, "WiFi, desktop mode), then pick the target disk and install.");
        cairo_move_to(cr, 28, 172);
        cairo_show_text(cr, "WARNING: the target disk is WIPED during installation.");
        cairo_move_to(cr, 28, 204);
        cairo_show_text(cr, "Navigate with the Back / Next buttons, arrow keys and Enter.");
        cairo_set_source_rgb(cr, 0.45, 0.45, 0.45);
        cairo_move_to(cr, 28, 240);
        cairo_show_text(cr, "A fresh root password is recommended (blank keeps the live default).");
    } else if (page == PG_LANG) {
        draw_list(cr, &lang_list, 40, cy, WIN_W - 80, ch, "Choose language");
    } else if (page == PG_KBD) {
        draw_list(cr, &kbd_list, 40, cy, WIN_W - 80, ch, "Choose keyboard layout");
    } else if (page == PG_TZ) {
        draw_list(cr, &tz_list, 40, cy, WIN_W - 80, ch, "Choose timezone (UTC offset)");
    } else if (page == PG_HOST) {
        draw_text_field(cr, 90, 150, 380, 28, "Hostname", hostname, 0, active_field == 0, 1);
        cairo_select_font_face(cr, "sans-serif", CAIRO_FONT_SLANT_NORMAL, CAIRO_FONT_WEIGHT_NORMAL);
        cairo_set_font_size(cr, 10.5);
        cairo_set_source_rgb(cr, 0.45, 0.45, 0.45);
        cairo_move_to(cr, 90, 210);
        cairo_show_text(cr, "The machine name on the network (letters, digits, dashes).");
    } else if (page == PG_ROOTPW) {
        draw_text_field(cr, 90, 150, 380, 28, "Root password", rootpw, 1, active_field == 0, 1);
        cairo_select_font_face(cr, "sans-serif", CAIRO_FONT_SLANT_NORMAL, CAIRO_FONT_WEIGHT_NORMAL);
        cairo_set_font_size(cr, 10.5);
        cairo_set_source_rgb(cr, 0.45, 0.45, 0.45);
        cairo_move_to(cr, 90, 210);
        cairo_show_text(cr, "Leave EMPTY to keep the live default (root / flx).");
        cairo_move_to(cr, 90, 228);
        cairo_show_text(cr, "Pick something private on a real install!");
    } else if (page == PG_USER) {
        draw_check(cr, 90, 92, user_en, "Create a user account");
        draw_text_field(cr, 120, 140, 380, 28, "Username", username, 0, active_field == 0, user_en);
        draw_text_field(cr, 120, 205, 380, 28, "Full name", realname, 0, active_field == 1, user_en);
        draw_text_field(cr, 120, 270, 380, 28, "Password", userpw, 1, active_field == 2, user_en);
        cairo_select_font_face(cr, "sans-serif", CAIRO_FONT_SLANT_NORMAL, CAIRO_FONT_WEIGHT_NORMAL);
        cairo_set_font_size(cr, 10.5);
        cairo_set_source_rgb(cr, 0.45, 0.45, 0.45);
        cairo_move_to(cr, 120, 330);
        cairo_show_text(cr, "The user home lives on the persistent FLX_HOME partition.");
    } else if (page == PG_WIFI) {
        draw_check(cr, 90, 92, wifi_en, "Configure a WiFi network");
        draw_text_field(cr, 120, 140, 380, 28, "Network name (SSID)", wifissid, 0, active_field == 0, wifi_en);
        draw_text_field(cr, 120, 205, 380, 28, "Password (blank = open)", wifipass, 1, active_field == 1, wifi_en);
        cairo_select_font_face(cr, "sans-serif", CAIRO_FONT_SLANT_NORMAL, CAIRO_FONT_WEIGHT_NORMAL);
        cairo_set_font_size(cr, 10.5);
        cairo_set_source_rgb(cr, 0.45, 0.45, 0.45);
        cairo_move_to(cr, 120, 265);
        cairo_show_text(cr, "Optional - skip if this machine uses Ethernet.");
    } else if (page == PG_DESK) {
        draw_list(cr, &desk_list, 40, cy, WIN_W - 80, 120, "Select desktop environment");
        cairo_select_font_face(cr, "sans-serif", CAIRO_FONT_SLANT_NORMAL, CAIRO_FONT_WEIGHT_NORMAL);
        cairo_set_font_size(cr, 10.5);
        cairo_set_source_rgb(cr, 0.45, 0.45, 0.45);
        cairo_move_to(cr, 40, cy + 140);
        cairo_show_text(cr, "GUI: Openbox desktop with a welcome login screen.");
        cairo_move_to(cr, 40, cy + 158);
        cairo_show_text(cr, "Headless: pure CLI - perfect for servers.");
    } else if (page == PG_DISK) {
        draw_list(cr, &disk_list, 40, cy, WIN_W - 80, 210, "Select target disk (WILL BE WIPED)");
        cairo_select_font_face(cr, "sans-serif", CAIRO_FONT_SLANT_NORMAL, CAIRO_FONT_WEIGHT_BOLD);
        cairo_set_font_size(cr, 11.0);
        cairo_set_source_rgb(cr, 0.62, 0.15, 0.15);
        cairo_move_to(cr, 40, cy + 238);
        if (disk_list.count > 0)
            cairo_show_text(cr, "All data on the selected disk will be PERMANENTLY ERASED!");
        cairo_set_source_rgb(cr, 0.30, 0.30, 0.30);
        cairo_set_font_size(cr, 10.5);
        cairo_move_to(cr, 40, cy + 260);
        cairo_show_text(cr, "Arrow keys to choose, then click Next.");
    } else if (page == PG_CONFIRM) {
        cairo_select_font_face(cr, "sans-serif", CAIRO_FONT_SLANT_NORMAL, CAIRO_FONT_WEIGHT_BOLD);
        cairo_set_font_size(cr, 11.0);
        cairo_set_source_rgb(cr, 0.10, 0.10, 0.10);
        double y0 = cy + 4;
        cairo_move_to(cr, 30, y0);
        cairo_show_text(cr, "Language:");
        cairo_move_to(cr, 115, y0);
        cairo_show_text(cr, sel_lang);
        cairo_move_to(cr, 30, y0 + 18);
        cairo_show_text(cr, "Keyboard:");
        cairo_move_to(cr, 115, y0 + 18);
        cairo_show_text(cr, sel_kbd);
        cairo_move_to(cr, 30, y0 + 36);
        cairo_show_text(cr, "Timezone:");
        cairo_move_to(cr, 115, y0 + 36);
        cairo_show_text(cr, sel_tz);
        cairo_move_to(cr, 30, y0 + 54);
        cairo_show_text(cr, "Hostname:");
        cairo_move_to(cr, 115, y0 + 54);
        cairo_show_text(cr, hostname);
        cairo_move_to(cr, 30, y0 + 72);
        cairo_show_text(cr, "Root pw:");
        cairo_move_to(cr, 115, y0 + 72);
        cairo_show_text(cr, rootpw[0] ? "will be set" : "kept default");
        char line[128];
        snprintf(line, sizeof(line), "User: %s", user_en ? username : "(none)");
        cairo_move_to(cr, 30, y0 + 90);
        cairo_show_text(cr, line);
        snprintf(line, sizeof(line), "WiFi: %s", (wifi_en && wifissid[0]) ? wifissid : "(none)");
        cairo_move_to(cr, 30, y0 + 108);
        cairo_show_text(cr, line);
        snprintf(line, sizeof(line), "Desktop: %s", desktop_gui ? "GUI" : "headless");
        cairo_move_to(cr, 30, y0 + 126);
        cairo_show_text(cr, line);
        snprintf(line, sizeof(line), "Target: %s", target_disk[0] ? target_disk : "(pick a disk)");
        cairo_move_to(cr, 30, y0 + 144);
        cairo_show_text(cr, line);

        double lx = 30, ly = y0 + 152, lw = WIN_W - 60, lh = 178;
        if (inst_state == INST_IDLE) {
            cairo_set_source_rgb(cr, 0.96, 0.96, 0.94);
            cairo_rectangle(cr, lx, ly, lw, lh);
            cairo_fill(cr);
            draw_bevel(cr, lx, ly, lw, lh, 0);
            cairo_select_font_face(cr, "sans-serif", CAIRO_FONT_SLANT_ITALIC, CAIRO_FONT_WEIGHT_NORMAL);
            cairo_set_font_size(cr, 11.0);
            cairo_set_source_rgb(cr, 0.5, 0.5, 0.5);
            cairo_move_to(cr, lx + 12, ly + 22);
            cairo_show_text(cr, "Install log will appear here. Click 'Install' to begin.");
        } else {
            cairo_set_source_rgb(cr, 0.10, 0.10, 0.10);
            cairo_rectangle(cr, lx, ly, lw, lh);
            cairo_fill(cr);
            cairo_save(cr);
            cairo_rectangle(cr, lx, ly, lw, lh);
            cairo_clip(cr);
            cairo_select_font_face(cr, "monospace", CAIRO_FONT_SLANT_NORMAL, CAIRO_FONT_WEIGHT_NORMAL);
            cairo_set_font_size(cr, 9.5);
            cairo_set_source_rgb(cr, 0.70, 0.82, 0.70);
            /* render the tail of inst_log */
            int nl = 0;
            for (size_t i = 0; i < inst_log_len; i++)
                if (inst_log[i] == '\n') nl++;
            int max_lines = (int)(lh / 12);
            int skip = nl - max_lines;
            if (skip < 0) skip = 0;
            int cur = 0;
            const char *p = inst_log;
            while (*p && cur < skip) {
                if (*p == '\n') cur++;
                p++;
            }
            if (skip > 0 && *p == '\n') p++;
            double ty = ly + 10;
            while (*p && ty < ly + lh - 4) {
                const char *e = strchr(p, '\n');
                if (!e) e = inst_log + inst_log_len;
                char tmp = *e;
                *(char *)e = '\0';
                /* elide long line heads if needed */
                cairo_move_to(cr, lx + 6, ty);
                cairo_show_text(cr, p);
                *(char *)e = tmp;
                p = e;
                if (*p == '\n') p++;
                ty += 12;
            }
            cairo_restore(cr);
        }
    } else if (page == PG_DONE) {
        cairo_select_font_face(cr, "sans-serif", CAIRO_FONT_SLANT_NORMAL, CAIRO_FONT_WEIGHT_BOLD);
        cairo_set_font_size(cr, 15.0);
        cairo_set_source_rgb(cr, 0.10, 0.50, 0.10);
        cairo_move_to(cr, 40, 130);
        cairo_show_text(cr, inst_state == INST_ERROR ? "Installation encountered errors."
                                                      : "Installation finished!");
        cairo_select_font_face(cr, "sans-serif", CAIRO_FONT_SLANT_NORMAL, CAIRO_FONT_WEIGHT_NORMAL);
        cairo_set_font_size(cr, 11.5);
        cairo_set_source_rgb(cr, 0.25, 0.25, 0.25);
        cairo_move_to(cr, 40, 160);
        cairo_show_text(cr, "Remove the live media, then reboot to start FreeLinX from disk.");
        if (inst_state != INST_ERROR) {
            cairo_move_to(cr, 40, 180);
            cairo_show_text(cr, "The login screen greets you with the account you just created.");
        }
    }

    /* footer */
    cairo_set_source_rgb(cr, 0.86, 0.86, 0.84);
    cairo_rectangle(cr, 0, WIN_H - 34, WIN_W, 34);
    cairo_fill(cr);
    draw_bevel(cr, 2, WIN_H - 32, WIN_W - 4, 30, 0);
    cairo_select_font_face(cr, "sans-serif", CAIRO_FONT_SLANT_NORMAL, CAIRO_FONT_WEIGHT_NORMAL);
    cairo_set_font_size(cr, 10.0);
    cairo_set_source_rgb(cr, 0.2, 0.2, 0.2);
    cairo_move_to(cr, 8, WIN_H - 13);
    cairo_show_text(cr, status_msg);

    int can_back = (page > PG_WELCOME && page < PG_CONFIRM) ||
                   (page == PG_CONFIRM && inst_state == INST_IDLE);
    if (can_back) draw_button(cr, WIN_W - 200, WIN_H - 32, 88, 26, "Back", 1);
    if (page == PG_CONFIRM && inst_state == INST_IDLE)
        draw_button(cr, WIN_W - 100, WIN_H - 32, 90, 26, "Install", 1);
    else if (page == PG_CONFIRM && inst_state != INST_IDLE)
        draw_button(cr, WIN_W - 100, WIN_H - 32, 90, 26, "Done", inst_state != INST_RUNNING);
    else if (page == PG_DONE)
        draw_button(cr, WIN_W - 100, WIN_H - 32, 90, 26, "Reboot", 1);
    else if (page < PG_CONFIRM)
        draw_button(cr, WIN_W - 100, WIN_H - 32, 90, 26, "Next", 1);

    cairo_surface_flush(surf);
}

/* ---- helpers to copy list selection into config values ------------------- */
static void apply_lang(void) {
    const char *loc[] = { "en_US.UTF-8", "de_DE.UTF-8", "fr_FR.UTF-8", "es_ES.UTF-8",
        "it_IT.UTF-8", "pt_PT.UTF-8", "nl_NL.UTF-8", "tr_TR.UTF-8", "ru_RU.UTF-8",
        "ar_SA.UTF-8", "fa_IR.UTF-8", "ja_JP.UTF-8", "zh_CN.UTF-8" };
    if (lang_list.sel >= 0 && lang_list.sel < 13)
        snprintf(sel_lang, sizeof(sel_lang), "%s", loc[lang_list.sel]);
}
static void apply_kbd(void) {
    const char *lay[] = { "us", "de", "fr", "gb", "es", "it", "pt", "tr", "ru", "ar", "fa", "jp", "custom" };
    if (kbd_list.sel >= 0 && kbd_list.sel < 13)
        snprintf(sel_kbd, sizeof(sel_kbd), "%s", lay[kbd_list.sel]);
}
static void apply_tz(void) {
    const char *tz[] = { "UTC0", "UTC-1", "UTC-2", "UTC-3", "UTC-3:30", "UTC-4",
        "UTC-5:30", "UTC-7", "UTC-8", "UTC-9", "UTC+5", "UTC+6", "UTC+7", "UTC+8", "custom" };
    if (tz_list.sel >= 0 && tz_list.sel < 15)
        snprintf(sel_tz, sizeof(sel_tz), "%s", tz[tz_list.sel]);
}
static void apply_disk(void) {
    if (disk_list.sel >= 0 && disk_list.sel < disk_list.count) {
        const char *entry = disk_list.items[disk_list.sel];
        const char *sp = strchr(entry, ' ');
        if (sp) {
            char dev[64];
            int n = (int)(sp - entry);
            if (n >= (int)sizeof(dev)) n = (int)sizeof(dev) - 1;
            memcpy(dev, entry, n);
            dev[n] = '\0';
            snprintf(target_disk, sizeof(target_disk), "%s", dev);
        }
    }
}

/* ---- input handling ------------------------------------------------------ */
static void goto_page(int p) {
    if (p >= 0 && p < PG_COUNT) {
        page = p;
        active_field = 0;
        if (p == PG_DISK && disk_list.count == 0) scan_disks();
    }
}

static PgList *current_list(void) {
    switch (page) {
        case PG_LANG: return &lang_list;
        case PG_KBD:  return &kbd_list;
        case PG_TZ:   return &tz_list;
        case PG_DESK: return &desk_list;
        case PG_DISK: return &disk_list;
        default:      return NULL;
    }
}

static int page_nfields(void) {
    if (page == PG_HOST || page == PG_ROOTPW) return 1;
    if (page == PG_USER) return 3;
    if (page == PG_WIFI) return 2;
    return 0;
}

static void field_edit(char c) {
    char *dst = NULL;
    int cap = 0;
    if (page == PG_HOST && active_field == 0) { dst = hostname; cap = sizeof(hostname); }
    else if (page == PG_ROOTPW && active_field == 0) { dst = rootpw; cap = sizeof(rootpw); }
    else if (page == PG_USER && user_en) {
        if (active_field == 0) { dst = username; cap = sizeof(username); }
        else if (active_field == 1) { dst = realname; cap = sizeof(realname); }
        else if (active_field == 2) { dst = userpw; cap = sizeof(userpw); }
    } else if (page == PG_WIFI && wifi_en) {
        if (active_field == 0) { dst = wifissid; cap = sizeof(wifissid); }
        else if (active_field == 1) { dst = wifipass; cap = sizeof(wifipass); }
    }
    if (!dst) return;
    size_t l = strlen(dst);
    if (l < (size_t)cap - 1) { dst[l] = c; dst[l + 1] = '\0'; }
}

static void field_backspace(void) {
    char *dst = NULL;
    if (page == PG_HOST && active_field == 0) dst = hostname;
    else if (page == PG_ROOTPW && active_field == 0) dst = rootpw;
    else if (page == PG_USER && user_en && active_field == 0) dst = username;
    else if (page == PG_USER && user_en && active_field == 1) dst = realname;
    else if (page == PG_USER && user_en && active_field == 2) dst = userpw;
    else if (page == PG_WIFI && wifi_en && active_field == 0) dst = wifissid;
    else if (page == PG_WIFI && wifi_en && active_field == 1) dst = wifipass;
    if (dst && dst[0]) dst[strlen(dst) - 1] = '\0';
}

static void advance_page(void) {
    switch (page) {
        case PG_WELCOME: goto_page(PG_LANG); break;
        case PG_LANG:    apply_lang(); goto_page(PG_KBD); break;
        case PG_KBD:     apply_kbd(); goto_page(PG_TZ); break;
        case PG_TZ:      apply_tz(); goto_page(PG_HOST); break;
        case PG_HOST:    goto_page(PG_ROOTPW); break;
        case PG_ROOTPW:  goto_page(PG_USER); break;
        case PG_USER:    goto_page(PG_WIFI); break;
        case PG_WIFI:    goto_page(PG_DESK); break;
        case PG_DESK:    desktop_gui = (desk_list.sel == 0); goto_page(PG_DISK); break;
        case PG_DISK:    apply_disk(); goto_page(PG_CONFIRM); break;
        case PG_CONFIRM:
            if (inst_state == INST_IDLE) start_install();
            else if (inst_state != INST_RUNNING) goto_page(PG_DONE);
            break;
        case PG_DONE:    do_reboot(); break;
        default: break;
    }
}

static void back_page(void) {
    if (page > PG_WELCOME && page < PG_CONFIRM) goto_page(page - 1);
}

static void key_press(KeySym ks, char printable) {
    PgList *cl = current_list();
    if (ks == XK_Up) {
        if (cl && cl->sel > 0) cl->sel--;
        return;
    }
    if (ks == XK_Down) {
        if (cl && cl->sel < cl->count - 1) cl->sel++;
        return;
    }
    if (ks == XK_Left) {
        if (cl && cl->sel > 0) cl->sel--;
        return;
    }
    if (ks == XK_Right) {
        if (cl && cl->sel < cl->count - 1) cl->sel++;
        return;
    }
    if (ks == XK_BackSpace) { field_backspace(); return; }
    if (ks == XK_Tab) {
        int n = page_nfields();
        if (n > 0) active_field = (active_field + 1) % n;
        return;
    }
    if (ks == XK_Return) {
        int n = page_nfields();
        if (n > 0 && active_field < n - 1) { active_field++; return; }
        advance_page();
        return;
    }
    if (printable >= ' ' && printable <= '~') field_edit(printable);
}

int main(int argc, char **argv) {
    (void)argc; (void)argv;
    Display *dpy = XOpenDisplay(NULL);
    if (!dpy) { fprintf(stderr, "flxinstall-gui: cannot open X display\n"); return 1; }
    int screen = DefaultScreen(dpy);
    Window root = RootWindow(dpy, screen);

    XSetWindowAttributes swa;
    swa.background_pixel = WhitePixel(dpy, screen);
    swa.event_mask = ExposureMask | KeyPressMask | ButtonPressMask | StructureNotifyMask;

    Window win = XCreateWindow(dpy, root, 130, 60, WIN_W, WIN_H, 0,
                               DefaultDepth(dpy, screen), InputOutput,
                               DefaultVisual(dpy, screen),
                               CWBackPixel | CWEventMask, &swa);
    XStoreName(dpy, win, "FreeLinX Installer");
    XClassHint ch = { "flxinstall-gui", "FreeLinX" };
    XSetClassHint(dpy, win, &ch);

    XSizeHints hints;
    hints.flags = USPosition | USSize;
    hints.x = 130; hints.y = 60; hints.width = WIN_W; hints.height = WIN_H;
    XSetWMNormalHints(dpy, win, &hints);

    Atom wm_delete = XInternAtom(dpy, "WM_DELETE_WINDOW", False);
    XSetWMProtocols(dpy, win, &wm_delete, 1);

    XMapWindow(dpy, win);
    XFlush(dpy);

    cairo_surface_t *surf = cairo_xlib_surface_create(dpy, win, DefaultVisual(dpy, screen), WIN_W, WIN_H);
    cairo_t *cr = cairo_create(surf);

    fill_lists();
    scan_disks();

    while (running) {
        while (XPending(dpy)) {
            XEvent ev;
            XNextEvent(dpy, &ev);

            if (ev.type == Expose && ev.xexpose.count == 0) {
                draw_ui(cr, surf);
            } else if (ev.type == ClientMessage) {
                if ((Atom)ev.xclient.data.l[0] == wm_delete) running = 0;
            } else if (ev.type == ButtonPress) {
                int bx = ev.xbutton.x, by = ev.xbutton.y;
                int can_back = (page > PG_WELCOME && page < PG_CONFIRM) ||
                               (page == PG_CONFIRM && inst_state == INST_IDLE);
                if (can_back && bx >= WIN_W - 200 && bx <= WIN_W - 112 &&
                    by >= WIN_H - 32 && by <= WIN_H - 6) {
                    back_page();
                    continue;
                }
                /* right-side action button */
                if (bx >= WIN_W - 100 && bx <= WIN_W - 10 && by >= WIN_H - 32 && by <= WIN_H - 6) {
                    advance_page();
                    continue;
                }
                /* list row clicks */
                PgList *cl = current_list();
                double ltop = 80, lrow_h = 21;
                if (cl && by >= ltop && by <= ltop + 1000) {
                    int r = (by - ltop) / (int)lrow_h - 1 + cl->top;
                    if (r >= 0 && r < cl->count) cl->sel = r;
                }
                /* checkboxes */
                if (page == PG_USER && bx >= 90 && bx <= 106 && by >= 92 && by <= 108)
                    user_en = !user_en;
                if (page == PG_WIFI && bx >= 90 && bx <= 106 && by >= 92 && by <= 108)
                    wifi_en = !wifi_en;
                /* text field clicks */
                if (page == PG_HOST && bx >= 90 && bx <= 470 && by >= 150 && by <= 178)
                    active_field = 0;
                if (page == PG_ROOTPW && bx >= 90 && bx <= 470 && by >= 150 && by <= 178)
                    active_field = 0;
                if (page == PG_USER && user_en) {
                    if (bx >= 120 && bx <= 500 && by >= 140 && by <= 168) active_field = 0;
                    if (bx >= 120 && bx <= 500 && by >= 205 && by <= 233) active_field = 1;
                    if (bx >= 120 && bx <= 500 && by >= 270 && by <= 298) active_field = 2;
                }
                if (page == PG_WIFI && wifi_en) {
                    if (bx >= 120 && bx <= 500 && by >= 140 && by <= 168) active_field = 0;
                    if (bx >= 120 && bx <= 500 && by >= 205 && by <= 233) active_field = 1;
                }
            } else if (ev.type == KeyPress) {
                char buf[32]; KeySym ks;
                int len = XLookupString(&ev.xkey, buf, sizeof(buf), &ks, NULL);
                if (ks == XK_Escape) { running = 0; continue; }
                char c = (len > 0) ? buf[0] : 0;
                key_press(ks, c);
            }
        }
        poll_install();
        draw_ui(cr, surf);
        usleep(30000);
    }

    cairo_destroy(cr);
    cairo_surface_destroy(surf);
    XDestroyWindow(dpy, win);
    XCloseDisplay(dpy);
    return 0;
}