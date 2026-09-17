/*
 * FreeLinX Network Manager (flxnetmgr)
 * 100% Independent Non-GNU Musl X11 + Cairo Graphical Network Manager
 * Provides interface status, DHCP management, WiFi scanning, and connection.
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
#include <sys/socket.h>
#include <sys/ioctl.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <net/if.h>
#include <time.h>
#include <errno.h>

#include <X11/Xlib.h>
#include <X11/Xutil.h>
#include <X11/Xatom.h>
#include <X11/keysym.h>

#include <cairo/cairo.h>
#include <cairo/cairo-xlib.h>

#define WIN_W 490
#define WIN_H 330

#define TAB_INTERFACES 0
#define TAB_WIFI       1
#define TAB_TOOLS      2

typedef struct {
    char name[32];
    int is_up;
    int is_wireless;
    char ip[32];
    char mac[32];
    char rx_bytes[32];
    char tx_bytes[32];
} IfaceInfo;

typedef struct {
    char bssid[32];
    int signal;
    char flags[64];
    char ssid[64];
} WifiAP;

static int current_tab = TAB_INTERFACES;

static IfaceInfo ifaces[16];
static int iface_count = 0;
static int selected_iface = 0;

static WifiAP ap_list[64];
static int ap_count = 0;
static int selected_ap = -1;

static char wifi_pass[64] = "";
static int pass_input_active = 0;

static char status_message[128] = "System ready. All network services operational.";
static char ping_result[128] = "Ping not tested yet.";
static char dns_servers[128] = "";
static char default_gw[64] = "";

/* Retro UI helpers */
static void draw_bevel(cairo_t *cr, double x, double y, double w, double h, int raised) {
    cairo_set_line_width(cr, 1.0);
    if (raised) {
        cairo_set_source_rgb(cr, 1.0, 1.0, 1.0);
    } else {
        cairo_set_source_rgb(cr, 0.40, 0.40, 0.40);
    }
    cairo_move_to(cr, x, y + h);
    cairo_line_to(cr, x, y);
    cairo_line_to(cr, x + w, y);
    cairo_stroke(cr);

    if (raised) {
        cairo_set_source_rgb(cr, 0.40, 0.40, 0.40);
    } else {
        cairo_set_source_rgb(cr, 1.0, 1.0, 1.0);
    }
    cairo_move_to(cr, x + w, y);
    cairo_line_to(cr, x + w, y + h);
    cairo_line_to(cr, x, y + h);
    cairo_stroke(cr);
}

static void draw_button(cairo_t *cr, double x, double y, double w, double h, const char *label, int pressed) {
    cairo_set_source_rgb(cr, 0.88, 0.88, 0.86);
    cairo_rectangle(cr, x, y, w, h);
    cairo_fill(cr);
    draw_bevel(cr, x, y, w, h, !pressed);

    cairo_select_font_face(cr, "sans-serif", CAIRO_FONT_SLANT_NORMAL, CAIRO_FONT_WEIGHT_BOLD);
    cairo_set_font_size(cr, 10.5);
    cairo_set_source_rgb(cr, 0.15, 0.15, 0.15);

    cairo_text_extents_t ext;
    cairo_text_extents(cr, label, &ext);
    double tx = x + (w - ext.width) / 2.0;
    double ty = y + (h + ext.height) / 2.0 - 1.0;
    if (pressed) { tx += 1; ty += 1; }
    cairo_move_to(cr, tx, ty);
    cairo_show_text(cr, label);
}

/* Network backend queries */
static void scan_interfaces(void) {
    iface_count = 0;
    DIR *d = opendir("/sys/class/net");
    if (!d) return;

    int sock = socket(AF_INET, SOCK_DGRAM, 0);

    struct dirent *de;
    while ((de = readdir(d)) != NULL && iface_count < 16) {
        if (de->d_name[0] == '.') continue;

        IfaceInfo *inf = &ifaces[iface_count];
        memset(inf, 0, sizeof(IfaceInfo));
        strncpy(inf->name, de->d_name, sizeof(inf->name) - 1);

        /* Check operstate */
        char path[256];
        snprintf(path, sizeof(path), "/sys/class/net/%s/operstate", de->d_name);
        FILE *f = fopen(path, "r");
        if (f) {
            char st[32] = {0};
            if (fgets(st, sizeof(st), f)) {
                if (strncmp(st, "up", 2) == 0) inf->is_up = 1;
                else if (strncmp(st, "down", 4) == 0) inf->is_up = 0;
                else inf->is_up = 0;
            }
            fclose(f);
        }

        /* Check flags via ioctl */
        if (sock >= 0) {
            struct ifreq ifr;
            memset(&ifr, 0, sizeof(ifr));
            strncpy(ifr.ifr_name, de->d_name, IFNAMSIZ - 1);
            if (ioctl(sock, SIOCGIFFLAGS, &ifr) >= 0) {
                if (ifr.ifr_flags & IFF_UP) inf->is_up = 1;
            }

            /* IP address */
            memset(&ifr, 0, sizeof(ifr));
            strncpy(ifr.ifr_name, de->d_name, IFNAMSIZ - 1);
            ifr.ifr_addr.sa_family = AF_INET;
            if (ioctl(sock, SIOCGIFADDR, &ifr) >= 0) {
                struct sockaddr_in *sin = (struct sockaddr_in *)&ifr.ifr_addr;
                strncpy(inf->ip, inet_ntoa(sin->sin_addr), sizeof(inf->ip) - 1);
            } else {
                strcpy(inf->ip, "No IP");
            }
        }

        /* MAC Address */
        snprintf(path, sizeof(path), "/sys/class/net/%s/address", de->d_name);
        f = fopen(path, "r");
        if (f) {
            if (fgets(inf->mac, sizeof(inf->mac), f)) {
                char *nl = strchr(inf->mac, '\n');
                if (nl) *nl = '\0';
            }
            fclose(f);
        }

        /* Check wireless */
        snprintf(path, sizeof(path), "/sys/class/net/%s/wireless", de->d_name);
        if (access(path, F_OK) == 0 || strncmp(de->d_name, "wl", 2) == 0) {
            inf->is_wireless = 1;
        }

        iface_count++;
    }
    if (sock >= 0) close(sock);
    closedir(d);

    /* Read DNS from /etc/resolv.conf */
    FILE *rf = fopen("/etc/resolv.conf", "r");
    dns_servers[0] = '\0';
    if (rf) {
        char line[128];
        while (fgets(line, sizeof(line), rf)) {
            if (strncmp(line, "nameserver", 10) == 0) {
                char ns[64] = {0};
                if (sscanf(line, "nameserver %63s", ns) == 1) {
                    if (dns_servers[0]) strncat(dns_servers, ", ", sizeof(dns_servers) - strlen(dns_servers) - 1);
                    strncat(dns_servers, ns, sizeof(dns_servers) - strlen(dns_servers) - 1);
                }
            }
        }
        fclose(rf);
    }
    if (!dns_servers[0]) strcpy(dns_servers, "1.1.1.1, 8.8.8.8");

    /* Default gateway from /proc/net/route */
    FILE *gf = fopen("/proc/net/route", "r");
    default_gw[0] = '\0';
    if (gf) {
        char line[256];
        fgets(line, sizeof(line), gf); // header
        while (fgets(line, sizeof(line), gf)) {
            char ifn[32];
            unsigned long dest, gw;
            if (sscanf(line, "%31s %lx %lx", ifn, &dest, &gw) >= 3) {
                if (dest == 0 && gw != 0) {
                    struct in_addr addr;
                    addr.s_addr = gw;
                    strncpy(default_gw, inet_ntoa(addr), sizeof(default_gw) - 1);
                    break;
                }
            }
        }
        fclose(gf);
    }
    if (!default_gw[0]) strcpy(default_gw, "Not set");
}

static void trigger_wifi_scan(void) {
    snprintf(status_message, sizeof(status_message), "Scanning WiFi networks via flxwifi...");
    system("/sbin/flxwifi scan > /tmp/flx_wifi_scan.txt 2>&1 &");
}

static void load_wifi_results(void) {
    ap_count = 0;
    FILE *f = fopen("/tmp/flx_wifi_scan.txt", "r");
    if (!f) return;

    char line[256];
    int line_num = 0;
    while (fgets(line, sizeof(line), f) && ap_count < 64) {
        line_num++;
        if (line_num <= 2) continue; // skip header lines

        WifiAP *ap = &ap_list[ap_count];
        memset(ap, 0, sizeof(WifiAP));
        int freq = 0;
        char flags[64] = {0};
        char ssid[64] = {0};
        char bssid[32] = {0};
        int signal = -100;

        if (sscanf(line, "%31s %d %d %63s %63[^\n]", bssid, &freq, &signal, flags, ssid) >= 4) {
            strncpy(ap->bssid, bssid, sizeof(ap->bssid) - 1);
            ap->signal = signal;
            strncpy(ap->flags, flags, sizeof(ap->flags) - 1);
            strncpy(ap->ssid, ssid, sizeof(ap->ssid) - 1);
            if (ap->ssid[0] == '\0') strcpy(ap->ssid, "<Hidden>");
            ap_count++;
        }
    }
    fclose(f);
    if (ap_count > 0) {
        snprintf(status_message, sizeof(status_message), "WiFi scan: found %d network(s)", ap_count);
    }
}

static void connect_selected_wifi(void) {
    if (selected_ap < 0 || selected_ap >= ap_count) {
        snprintf(status_message, sizeof(status_message), "Select a WiFi network first.");
        return;
    }
    WifiAP *ap = &ap_list[selected_ap];
    snprintf(status_message, sizeof(status_message), "Connecting to '%s'...", ap->ssid);
    
    char cmd[512];
    if (strlen(wifi_pass) > 0) {
        snprintf(cmd, sizeof(cmd), "/sbin/flxwifi connect \"%s\" \"%s\" > /tmp/flx_wifi_conn.log 2>&1 &", ap->ssid, wifi_pass);
    } else {
        snprintf(cmd, sizeof(cmd), "/sbin/flxwifi connect \"%s\" > /tmp/flx_wifi_conn.log 2>&1 &", ap->ssid);
    }
    system(cmd);
}

static void disconnect_wifi(void) {
    snprintf(status_message, sizeof(status_message), "Disconnecting WiFi...");
    system("/sbin/flxwifi disconnect > /dev/null 2>&1 &");
}

static void renew_dhcp(const char *iface) {
    snprintf(status_message, sizeof(status_message), "Requesting DHCP lease on %s...", iface);
    char cmd[256];
    snprintf(cmd, sizeof(cmd), "/sbin/dhcpcd -q -n %s > /dev/null 2>&1 &", iface);
    system(cmd);
}

static void toggle_iface(const char *iface, int up) {
    char cmd[256];
    snprintf(cmd, sizeof(cmd), "/sbin/flxifconfig %s %s", iface, up ? "up" : "down");
    system(cmd);
    scan_interfaces();
}

static void test_ping(void) {
    snprintf(ping_result, sizeof(ping_result), "Testing ping to 1.1.1.1...");
    int res = system("/bin/ping -c 1 -W 2 1.1.1.1 > /dev/null 2>&1");
    if (res == 0) {
        snprintf(ping_result, sizeof(ping_result), "Ping OK (1.1.1.1 reachable) - Online");
    } else {
        snprintf(ping_result, sizeof(ping_result), "Ping Failed (1.1.1.1 unreachable) - Offline");
    }
}

/* Rendering */
static void draw_ui(cairo_t *cr) {
    // Window background
    cairo_set_source_rgb(cr, 0.90, 0.90, 0.88);
    cairo_paint(cr);

    // Title / banner area
    cairo_set_source_rgb(cr, 0.12, 0.24, 0.38);
    cairo_rectangle(cr, 0, 0, WIN_W, 30);
    cairo_fill(cr);

    cairo_select_font_face(cr, "sans-serif", CAIRO_FONT_SLANT_NORMAL, CAIRO_FONT_WEIGHT_BOLD);
    cairo_set_font_size(cr, 11.5);
    cairo_set_source_rgb(cr, 1.0, 1.0, 1.0);
    cairo_move_to(cr, 10, 20);
    cairo_show_text(cr, "FreeLinX Network Manager (non-GNU musl)");

    // Tabs
    const char *tabs[] = {"Interfaces", "Wireless / WiFi", "Tools & DNS"};
    double tx = 10;
    for (int i = 0; i < 3; i++) {
        double tw = 110;
        int active = (current_tab == i);
        cairo_set_source_rgb(cr, active ? 0.94 : 0.84, active ? 0.94 : 0.84, active ? 0.92 : 0.82);
        cairo_rectangle(cr, tx, 38, tw, 24);
        cairo_fill(cr);
        draw_bevel(cr, tx, 38, tw, 24, active);

        cairo_select_font_face(cr, "sans-serif", CAIRO_FONT_SLANT_NORMAL, active ? CAIRO_FONT_WEIGHT_BOLD : CAIRO_FONT_WEIGHT_NORMAL);
        cairo_set_font_size(cr, 10.0);
        cairo_set_source_rgb(cr, active ? 0.0 : 0.3, active ? 0.0 : 0.3, active ? 0.0 : 0.3);

        cairo_text_extents_t ext;
        cairo_text_extents(cr, tabs[i], &ext);
        cairo_move_to(cr, tx + (tw - ext.width) / 2.0, 54);
        cairo_show_text(cr, tabs[i]);
        tx += tw + 4;
    }

    // Tab content container
    double cy = 62;
    double cw = WIN_W - 20;
    double ch = WIN_H - 100;
    cairo_set_source_rgb(cr, 0.94, 0.94, 0.92);
    cairo_rectangle(cr, 10, cy, cw, ch);
    cairo_fill(cr);
    draw_bevel(cr, 10, cy, cw, ch, 1);

    if (current_tab == TAB_INTERFACES) {
        // Table Header
        cairo_set_source_rgb(cr, 0.82, 0.82, 0.80);
        cairo_rectangle(cr, 16, cy + 8, cw - 12, 20);
        cairo_fill(cr);
        draw_bevel(cr, 16, cy + 8, cw - 12, 20, 1);

        cairo_select_font_face(cr, "sans-serif", CAIRO_FONT_SLANT_NORMAL, CAIRO_FONT_WEIGHT_BOLD);
        cairo_set_font_size(cr, 10.0);
        cairo_set_source_rgb(cr, 0.2, 0.2, 0.2);
        cairo_move_to(cr, 24, cy + 22); cairo_show_text(cr, "Interface");
        cairo_move_to(cr, 105, cy + 22); cairo_show_text(cr, "Status");
        cairo_move_to(cr, 175, cy + 22); cairo_show_text(cr, "IP Address");
        cairo_move_to(cr, 290, cy + 22); cairo_show_text(cr, "MAC Address");
        cairo_move_to(cr, 440, cy + 22); cairo_show_text(cr, "Type");

        // Interface items
        double iy = cy + 32;
        for (int i = 0; i < iface_count; i++) {
            IfaceInfo *inf = &ifaces[i];
            if (i == selected_iface) {
                cairo_set_source_rgb(cr, 0.22, 0.40, 0.65);
                cairo_rectangle(cr, 16, iy - 2, cw - 12, 19);
                cairo_fill(cr);
                cairo_set_source_rgb(cr, 1.0, 1.0, 1.0);
            } else {
                cairo_set_source_rgb(cr, 0.15, 0.15, 0.15);
            }

            cairo_select_font_face(cr, "sans-serif", CAIRO_FONT_SLANT_NORMAL, CAIRO_FONT_WEIGHT_NORMAL);
            cairo_set_font_size(cr, 10.0);

            cairo_move_to(cr, 24, iy + 12);
            cairo_show_text(cr, inf->name);

            // Status indicator
            cairo_move_to(cr, 105, iy + 12);
            if (inf->is_up) {
                cairo_show_text(cr, "UP");
            } else {
                cairo_show_text(cr, "DOWN");
            }

            cairo_move_to(cr, 175, iy + 12);
            cairo_show_text(cr, inf->ip);

            cairo_move_to(cr, 290, iy + 12);
            cairo_show_text(cr, inf->mac);

            cairo_move_to(cr, 440, iy + 12);
            cairo_show_text(cr, inf->is_wireless ? "Wireless" : "Ethernet");

            iy += 21;
        }

        // Action Buttons for selected interface
        double by = cy + ch - 38;
        draw_button(cr, 20, by, 90, 26, "Bring UP", 0);
        draw_button(cr, 120, by, 90, 26, "Take DOWN", 0);
        draw_button(cr, 220, by, 110, 26, "Renew DHCP", 0);
        draw_button(cr, 340, by, 85, 26, "Refresh", 0);

    } else if (current_tab == TAB_WIFI) {
        // WiFi Header
        cairo_set_source_rgb(cr, 0.82, 0.82, 0.80);
        cairo_rectangle(cr, 16, cy + 8, cw - 12, 20);
        cairo_fill(cr);
        draw_bevel(cr, 16, cy + 8, cw - 12, 20, 1);

        cairo_select_font_face(cr, "sans-serif", CAIRO_FONT_SLANT_NORMAL, CAIRO_FONT_WEIGHT_BOLD);
        cairo_set_font_size(cr, 10.0);
        cairo_set_source_rgb(cr, 0.2, 0.2, 0.2);
        cairo_move_to(cr, 24, cy + 22); cairo_show_text(cr, "SSID");
        cairo_move_to(cr, 220, cy + 22); cairo_show_text(cr, "Signal");
        cairo_move_to(cr, 300, cy + 22); cairo_show_text(cr, "Security");
        cairo_move_to(cr, 420, cy + 22); cairo_show_text(cr, "BSSID");

        double wy = cy + 32;
        if (ap_count == 0) {
            cairo_select_font_face(cr, "sans-serif", CAIRO_FONT_SLANT_ITALIC, CAIRO_FONT_WEIGHT_NORMAL);
            cairo_set_font_size(cr, 10.5);
            cairo_set_source_rgb(cr, 0.5, 0.5, 0.5);
            cairo_move_to(cr, 30, wy + 20);
            cairo_show_text(cr, "No WiFi scan results yet. Click 'Scan WiFi' below to discover networks.");
        } else {
            for (int i = 0; i < ap_count && i < 7; i++) {
                WifiAP *ap = &ap_list[i];
                if (i == selected_ap) {
                    cairo_set_source_rgb(cr, 0.22, 0.40, 0.65);
                    cairo_rectangle(cr, 16, wy - 2, cw - 12, 19);
                    cairo_fill(cr);
                    cairo_set_source_rgb(cr, 1.0, 1.0, 1.0);
                } else {
                    cairo_set_source_rgb(cr, 0.15, 0.15, 0.15);
                }

                cairo_select_font_face(cr, "sans-serif", CAIRO_FONT_SLANT_NORMAL, CAIRO_FONT_WEIGHT_NORMAL);
                cairo_set_font_size(cr, 10.0);

                cairo_move_to(cr, 24, wy + 12);
                cairo_show_text(cr, ap->ssid);

                char sig_str[32];
                snprintf(sig_str, sizeof(sig_str), "%d dBm", ap->signal);
                cairo_move_to(cr, 220, wy + 12);
                cairo_show_text(cr, sig_str);

                char sec_str[32] = "Open";
                if (strstr(ap->flags, "WPA2")) strcpy(sec_str, "WPA2-PSK");
                else if (strstr(ap->flags, "WPA")) strcpy(sec_str, "WPA-PSK");
                cairo_move_to(cr, 300, wy + 12);
                cairo_show_text(cr, sec_str);

                cairo_move_to(cr, 420, wy + 12);
                cairo_show_text(cr, ap->bssid);

                wy += 21;
            }
        }

        // WiFi Password Input Field
        double py = cy + ch - 72;
        cairo_select_font_face(cr, "sans-serif", CAIRO_FONT_SLANT_NORMAL, CAIRO_FONT_WEIGHT_BOLD);
        cairo_set_font_size(cr, 10.0);
        cairo_set_source_rgb(cr, 0.2, 0.2, 0.2);
        cairo_move_to(cr, 20, py + 14);
        cairo_show_text(cr, "Password:");

        cairo_set_source_rgb(cr, 1.0, 1.0, 1.0);
        cairo_rectangle(cr, 85, py, 230, 22);
        cairo_fill(cr);
        draw_bevel(cr, 85, py, 230, 22, 0);

        cairo_select_font_face(cr, "monospace", CAIRO_FONT_SLANT_NORMAL, CAIRO_FONT_WEIGHT_NORMAL);
        cairo_set_font_size(cr, 11.0);
        cairo_set_source_rgb(cr, 0.1, 0.1, 0.1);
        cairo_move_to(cr, 92, py + 15);
        if (strlen(wifi_pass) > 0) {
            char stars[64];
            memset(stars, '*', strlen(wifi_pass));
            stars[strlen(wifi_pass)] = '\0';
            cairo_show_text(cr, stars);
        } else if (pass_input_active) {
            cairo_set_source_rgb(cr, 0.6, 0.6, 0.6);
            cairo_show_text(cr, "(type password...)");
        }

        // WiFi Action Buttons
        double by = cy + ch - 38;
        draw_button(cr, 20, by, 95, 26, "Scan WiFi", 0);
        draw_button(cr, 125, by, 85, 26, "Connect", 0);
        draw_button(cr, 220, by, 95, 26, "Disconnect", 0);

    } else if (current_tab == TAB_TOOLS) {
        cairo_select_font_face(cr, "sans-serif", CAIRO_FONT_SLANT_NORMAL, CAIRO_FONT_WEIGHT_BOLD);
        cairo_set_font_size(cr, 11.0);
        cairo_set_source_rgb(cr, 0.15, 0.15, 0.15);

        cairo_move_to(cr, 24, cy + 30);
        cairo_show_text(cr, "Network Configuration Summary:");

        cairo_select_font_face(cr, "sans-serif", CAIRO_FONT_SLANT_NORMAL, CAIRO_FONT_WEIGHT_NORMAL);
        cairo_set_font_size(cr, 10.5);

        cairo_move_to(cr, 30, cy + 55);
        cairo_show_text(cr, "Default Gateway:");
        cairo_move_to(cr, 150, cy + 55);
        cairo_show_text(cr, default_gw);

        cairo_move_to(cr, 30, cy + 80);
        cairo_show_text(cr, "DNS Nameservers:");
        cairo_move_to(cr, 150, cy + 80);
        cairo_show_text(cr, dns_servers);

        cairo_move_to(cr, 30, cy + 105);
        cairo_show_text(cr, "Internet Status:");
        cairo_move_to(cr, 150, cy + 105);
        cairo_show_text(cr, ping_result);

        double by = cy + 140;
        draw_button(cr, 30, by, 130, 26, "Test Ping (1.1.1.1)", 0);
        draw_button(cr, 170, by, 130, 26, "Reload Resolv.conf", 0);
    }

    // Status Bar at bottom
    double sy = WIN_H - 28;
    cairo_set_source_rgb(cr, 0.86, 0.86, 0.84);
    cairo_rectangle(cr, 0, sy, WIN_W, 28);
    cairo_fill(cr);
    draw_bevel(cr, 2, sy + 2, WIN_W - 4, 24, 0);

    cairo_select_font_face(cr, "sans-serif", CAIRO_FONT_SLANT_NORMAL, CAIRO_FONT_WEIGHT_NORMAL);
    cairo_set_font_size(cr, 10.0);
    cairo_set_source_rgb(cr, 0.2, 0.2, 0.2);
    cairo_move_to(cr, 8, sy + 17);
    cairo_show_text(cr, status_message);
}

int main(int argc, char **argv) {
    Display *dpy = XOpenDisplay(NULL);
    if (!dpy) {
        fprintf(stderr, "flxnetmgr: cannot open X display\n");
        return 1;
    }

    int screen = DefaultScreen(dpy);
    Window root = RootWindow(dpy, screen);

    XSetWindowAttributes swa;
    swa.background_pixel = WhitePixel(dpy, screen);
    swa.event_mask = ExposureMask | KeyPressMask | ButtonPressMask | StructureNotifyMask;

    Window win = XCreateWindow(dpy, root, 495, 415, WIN_W, WIN_H, 0,
                               DefaultDepth(dpy, screen), InputOutput,
                               DefaultVisual(dpy, screen),
                               CWBackPixel | CWEventMask, &swa);

    XStoreName(dpy, win, "FreeLinX Network Manager");
    XClassHint ch = {"flxnetmgr", "FreeLinX"};
    XSetClassHint(dpy, win, &ch);

    XSizeHints hints;
    hints.flags = USPosition | USSize;
    hints.x = 495;
    hints.y = 415;
    hints.width = WIN_W;
    hints.height = WIN_H;
    XSetWMNormalHints(dpy, win, &hints);

    Atom wm_delete = XInternAtom(dpy, "WM_DELETE_WINDOW", False);
    XSetWMProtocols(dpy, win, &wm_delete, 1);

    XMapWindow(dpy, win);
    XFlush(dpy);

    cairo_surface_t *surf = cairo_xlib_surface_create(dpy, win, DefaultVisual(dpy, screen), WIN_W, WIN_H);
    cairo_t *cr = cairo_create(surf);

    scan_interfaces();

    int running = 1;
    while (running) {
        while (XPending(dpy)) {
            XEvent ev;
            XNextEvent(dpy, &ev);

            if (ev.type == Expose && ev.xexpose.count == 0) {
                draw_ui(cr);
                cairo_surface_flush(surf);
            } else if (ev.type == ClientMessage) {
                if ((Atom)ev.xclient.data.l[0] == wm_delete) {
                    running = 0;
                }
            } else if (ev.type == ButtonPress) {
                int bx = ev.xbutton.x;
                int by = ev.xbutton.y;

                // Tab clicks
                if (by >= 38 && by <= 62) {
                    if (bx >= 10 && bx <= 120) { current_tab = TAB_INTERFACES; scan_interfaces(); }
                    else if (bx >= 124 && bx <= 234) { current_tab = TAB_WIFI; load_wifi_results(); }
                    else if (bx >= 238 && bx <= 348) { current_tab = TAB_TOOLS; }
                }

                double cy = 62;
                double ch = WIN_H - 100;
                double btn_y = cy + ch - 38;

                if (current_tab == TAB_INTERFACES) {
                    // Click on interface row
                    if (by >= cy + 30 && by < btn_y) {
                        int row = (by - (cy + 30)) / 21;
                        if (row >= 0 && row < iface_count) {
                            selected_iface = row;
                        }
                    }
                    // Button clicks
                    if (by >= btn_y && by <= btn_y + 26) {
                        if (bx >= 20 && bx <= 110 && selected_iface < iface_count) {
                            toggle_iface(ifaces[selected_iface].name, 1);
                        } else if (bx >= 120 && bx <= 210 && selected_iface < iface_count) {
                            toggle_iface(ifaces[selected_iface].name, 0);
                        } else if (bx >= 220 && bx <= 330 && selected_iface < iface_count) {
                            renew_dhcp(ifaces[selected_iface].name);
                        } else if (bx >= 340 && bx <= 425) {
                            scan_interfaces();
                            snprintf(status_message, sizeof(status_message), "Interfaces refreshed.");
                        }
                    }
                } else if (current_tab == TAB_WIFI) {
                    // Click on wifi row
                    if (by >= cy + 30 && by < cy + ch - 75) {
                        int row = (by - (cy + 30)) / 21;
                        if (row >= 0 && row < ap_count) {
                            selected_ap = row;
                        }
                    }
                    // Password input click
                    double py = cy + ch - 72;
                    if (by >= py && by <= py + 22 && bx >= 85 && bx <= 315) {
                        pass_input_active = 1;
                    } else {
                        pass_input_active = 0;
                    }
                    // WiFi Buttons
                    if (by >= btn_y && by <= btn_y + 26) {
                        if (bx >= 20 && bx <= 115) {
                            trigger_wifi_scan();
                        } else if (bx >= 125 && bx <= 210) {
                            connect_selected_wifi();
                        } else if (bx >= 220 && bx <= 315) {
                            disconnect_wifi();
                        }
                    }
                } else if (current_tab == TAB_TOOLS) {
                    double t_by = cy + 140;
                    if (by >= t_by && by <= t_by + 26) {
                        if (bx >= 30 && bx <= 160) {
                            test_ping();
                        } else if (bx >= 170 && bx <= 300) {
                            scan_interfaces();
                            snprintf(status_message, sizeof(status_message), "Configuration reloaded.");
                        }
                    }
                }

                draw_ui(cr);
                cairo_surface_flush(surf);
            } else if (ev.type == KeyPress) {
                if (pass_input_active) {
                    char buf[32];
                    KeySym ks;
                    int len = XLookupString(&ev.xkey, buf, sizeof(buf), &ks, NULL);
                    if (ks == XK_BackSpace) {
                        size_t l = strlen(wifi_pass);
                        if (l > 0) wifi_pass[l - 1] = '\0';
                    } else if (ks == XK_Return) {
                        pass_input_active = 0;
                        connect_selected_wifi();
                    } else if (len > 0 && buf[0] >= 32 && buf[0] <= 126) {
                        size_t l = strlen(wifi_pass);
                        if (l < sizeof(wifi_pass) - 1) {
                            wifi_pass[l] = buf[0];
                            wifi_pass[l + 1] = '\0';
                        }
                    }
                    draw_ui(cr);
                    cairo_surface_flush(surf);
                }
            }
        }

        // Periodic check for wifi scan results if active
        static time_t last_check = 0;
        time_t now = time(NULL);
        if (now != last_check) {
            last_check = now;
            if (current_tab == TAB_WIFI && access("/tmp/flx_wifi_scan.txt", F_OK) == 0) {
                load_wifi_results();
                draw_ui(cr);
                cairo_surface_flush(surf);
            }
        }

        usleep(30000); // 30ms sleep for event loop
    }

    cairo_destroy(cr);
    cairo_surface_destroy(surf);
    XDestroyWindow(dpy, win);
    XCloseDisplay(dpy);
    return 0;
}
