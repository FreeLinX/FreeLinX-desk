/*
 * FreeLinX flxbind - bind-mount helper for the FLX_SYS persistent overlay.
 *
 * The toybox mount(1) bundled in the initramfs cannot perform bind mounts
 * ("No such device"), so /init uses this tiny static helper instead.  It
 * binds the persistent copies of /usr /etc /var /root (stored on the ext4
 * FLX_SYS partition) over their base (initramfs) locations at every boot.
 *
 * Usage: flxbind <src> <dst> [<src> <dst> ...]
 *
 * SPDX-License-Identifier: BSD-2-Clause
 * Copyright (c) 2026 FreeLinX OS Project.
 */
/* musl exposes its entire interface unconditionally - there is no
 * _GNU_SOURCE to request, and everything used here (MS_BIND, MS_REC,
 * crypt(3)) is plain musl.  Ask for nothing. */
#include <stdio.h>
#include <string.h>
#include <errno.h>
#include <sys/mount.h>

int main(int argc, char **argv) {
    if (argc < 3 || ((argc - 1) % 2) != 0) {
        fprintf(stderr, "usage: flxbind <src> <dst> [<src> <dst> ...]\n");
        return 1;
    }

    int fail = 0;
    for (int i = 1; i + 1 < argc; i += 2) {
        if (mount(argv[i], argv[i + 1], NULL, MS_BIND | MS_REC, NULL) < 0) {
            fprintf(stderr, "flxbind: %s -> %s: %s\n",
                    argv[i], argv[i + 1], strerror(errno));
            fail = 1;
        } else {
            fprintf(stderr, "flxbind: bound %s -> %s\n",
                    argv[i], argv[i + 1]);
        }
    }
    return fail;
}