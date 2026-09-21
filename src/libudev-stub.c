/*
 * libudev-stub.c - Minimal libudev.so.1 stub for FreeLinX musl environment.
 *
 * modesetting_drv.so requires libudev.so.1 for hotplug monitoring.
 * Since FreeLinX has no udev daemon, this stub satisfies the linker
 * dependency with no-op implementations. Xorg modesetting uses udev
 * only for GPU hotplug events; the initial DRM device open uses libdrm
 * directly, so the stub is safe.
 */

#include <stdlib.h>
#include <unistd.h>

struct udev { int refcount; };
struct udev_monitor { struct udev *udev; int fd[2]; };
struct udev_device { int dummy; };

struct udev *udev_new(void) {
    struct udev *u = calloc(1, sizeof(*u));
    if (u) u->refcount = 1;
    return u;
}
struct udev *udev_unref(struct udev *u) {
    if (!u) return NULL;
    if (--u->refcount <= 0) free(u);
    return NULL;
}
struct udev_monitor *udev_monitor_new_from_netlink(struct udev *u, const char *name) {
    (void)name;
    struct udev_monitor *m = calloc(1, sizeof(*m));
    if (!m) return NULL;
    m->udev = u;
    m->fd[0] = m->fd[1] = -1;
    pipe(m->fd);
    return m;
}
int udev_monitor_filter_add_match_subsystem_devtype(struct udev_monitor *m, const char *s, const char *d) {
    (void)m; (void)s; (void)d; return 0;
}
int udev_monitor_enable_receiving(struct udev_monitor *m) { (void)m; return 0; }
int udev_monitor_get_fd(struct udev_monitor *m) { return m ? m->fd[0] : -1; }
struct udev *udev_monitor_get_udev(struct udev_monitor *m) { return m ? m->udev : NULL; }
struct udev_device *udev_monitor_receive_device(struct udev_monitor *m) { (void)m; return NULL; }
struct udev_monitor *udev_monitor_unref(struct udev_monitor *m) {
    if (!m) return NULL;
    if (m->fd[0] >= 0) close(m->fd[0]);
    if (m->fd[1] >= 0) close(m->fd[1]);
    free(m); return NULL;
}
struct udev_device *udev_device_unref(struct udev_device *d) { free(d); return NULL; }
