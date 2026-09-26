/*
 * FreeLinX flxhash - generate a strong crypt(3) password hash.
 *
 * The bundled greeter/PAM stack (linux-pam unix_chkpwd) refuses weak
 * legacy DES hashes (the 13-char output of pwhash), so installs need
 * proper $6$ (SHA-512) hashes.  This tiny static helper produces them;
 * no python3 or libxcrypt on the target required.
 *
 * Usage: flxhash <password>
 *
 * SPDX-License-Identifier: BSD-2-Clause
 * Copyright (c) 2026 FreeLinX OS Project.
 */
#define _XOPEN_SOURCE 700
/* musl exposes its entire interface unconditionally - there is no
 * _GNU_SOURCE to request, and everything used here (MS_BIND, MS_REC,
 * crypt(3)) is plain musl.  Ask for nothing. */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <fcntl.h>
#include <crypt.h>

/* crypt(3) "salt alphabet" (IEEE Std 1003.1) */
static const char salt_chars[] =
    "./0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz";

int main(int argc, char **argv) {
    const char *pw = NULL;
    char salt[8 + 16 + 1]; /* "$6$" + 16 salt chars + NUL */
    char *out;

    if (argc < 2 || argv[1][0] == '\0') {
        fprintf(stderr, "usage: flxhash <password>\n");
        return 1;
    }
    pw = argv[1];

    int fd = open("/dev/urandom", O_RDONLY);
    if (fd < 0) {
        fprintf(stderr, "flxhash: cannot open /dev/urandom\n");
        return 1;
    }
    /* 16 random salt chars */
    unsigned char rnd[16];
    ssize_t got = 0;
    while (got < (ssize_t)sizeof(rnd)) {
        ssize_t r = read(fd, rnd + got, sizeof(rnd) - got);
        if (r < 0) { close(fd); return 1; }
        if (r == 0) { close(fd); return 1; }
        got += r;
    }
    close(fd);

    snprintf(salt, sizeof(salt), "$6$");
    for (int i = 0; i < 16; i++) {
        char c = salt_chars[rnd[i] % (sizeof(salt_chars) - 1)];
        salt[3 + i] = c;
    }
    salt[3 + 16] = '\0';

    out = crypt(pw, salt);
    if (!out || strncmp(out, "$6$", 3) != 0) {
        fprintf(stderr, "flxhash: crypt failed\n");
        return 1;
    }
    printf("%s\n", out);
    return 0;
}