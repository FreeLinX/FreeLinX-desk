#!/bin/sh
# FreeLinX - collect the license texts of everything the desktop image ships
# into <root>/usr/share/licenses/<component>/.
#
#   stack/collect-licenses.sh [ROOT]      (default: ../src/rootfs)
#
# BSD/MIT-style licenses ask that binary distributions reproduce the
# copyright notice and license; the (L)GPL ones (kernel, FFmpeg, GTK, ...)
# that the license text travels with the program.  Sources: the unpacked
# stack sources (work/src), the kernel tree, and the NetBSD base userland.
set -eu
HERE="$(cd "$(dirname "$0")" && pwd)"
TOP="$(cd "$HERE/.." && pwd)"
W="$HERE/work"
R="${1:-$TOP/src/rootfs}"
L="$R/usr/share/licenses"
rm -rf "$L"
mkdir -p "$L"

lic_files() { # source dir -> license files at its top (and one level down)
    find "$1" -maxdepth 1 -type f \( -iname 'COPYING*' -o -iname 'LICEN[CS]E*' \
        -o -iname 'COPYRIGHT*' -o -iname 'NOTICE*' -o -iname 'AUTHORS' \) 2>/dev/null
    find "$1"/LICENSES -maxdepth 1 -type f 2>/dev/null || :
}

header_of() { # file -> its first comment block holding a copyright/license
    awk '/\/\*/ { blk = ""; inb = 1 }
         inb { blk = blk $0 "\n" }
         inb && /\*\// { inb = 0
             if (blk ~ /[Cc]opyright|[Pp]ermission|[Rr]edistribution/) { printf "%s", blk; exit } }' "$1"
}

n=0
for s in "$W"/src/*; do
    name=$(basename "$s")
    top=$(find "$s" -mindepth 1 -maxdepth 1 -type d | head -1)
    [ -n "$top" ] || top="$s"
    mkdir -p "$L/$name"
    files=$(lic_files "$top")
    case "$name" in
        mesa) files="$files $top/docs/license.rst" ;;
        llvm-rt) files="$top/libcxx/LICENSE.TXT" ;;
        llvm18) files="$top/llvm/LICENSE.TXT" ;;
        sqlite) printf 'SQLite is in the public domain: https://sqlite.org/copyright.html\n' > "$L/$name/COPYRIGHT" ;;
        libdrm) header_of "$top/xf86drm.c" > "$L/$name/COPYRIGHT" ;;
        elftoolchain) header_of "$top/libelf/elf.c" > "$L/$name/COPYRIGHT" ;;
        mesa-demos) header_of "$top/src/xdemos/glxinfo.c" > "$L/$name/COPYRIGHT" ;;
    esac
    for f in $files; do
        [ -f "$f" ] && cp "$f" "$L/$name/$(basename "$f")"
    done
    if [ -z "$(ls -A "$L/$name")" ]; then
        echo "collect-licenses: no license text found for $name" >&2
        rmdir "$L/$name"
        continue
    fi
    n=$((n + 1))
done

# the kernel
K="$(ls -d "$W"/src/linux/linux-* 2>/dev/null | sort -V | tail -1)"
if [ -f "$K/COPYING" ]; then
    mkdir -p "$L/linux"
    cp "$K/COPYING" "$L/linux/COPYING"
    cp -r "$K/LICENSES/preferred" "$L/linux/LICENSES"
    n=$((n + 1))
fi

# the NetBSD base userland: every utility keeps its own BSD license header;
# this is the NetBSD Foundation's, which most of them carry
mkdir -p "$L/netbsd"
cat > "$L/netbsd/COPYRIGHT" <<'EOF'
The FreeLinX base utilities (/bin, /sbin, /usr/bin) are built from the
NetBSD 10.1 sources (https://www.NetBSD.org/).  Each source file carries its
own copyright notice and BSD license; most of them use the following one.

Copyright (c) The NetBSD Foundation, Inc.
All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions
are met:
1. Redistributions of source code must retain the above copyright
   notice, this list of conditions and the following disclaimer.
2. Redistributions in binary form must reproduce the above copyright
   notice, this list of conditions and the following disclaimer in the
   documentation and/or other materials provided with the distribution.

THIS SOFTWARE IS PROVIDED BY THE NETBSD FOUNDATION, INC. AND CONTRIBUTORS
``AS IS'' AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED
TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL THE FOUNDATION OR CONTRIBUTORS
BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
POSSIBILITY OF SUCH DAMAGE.
EOF
n=$((n + 1))

cat > "$L/SOURCES" <<'EOF'
Where the source code is

FreeLinX is built entirely from source by the scripts in
https://github.com/FreeLinX (desktop: FreeLinX-desk, base utilities: ports,
kernel configuration: kernel, toolchain: toolchain, package manager: xpkg).
Every upstream source is listed with its download URL and SHA-256 checksum
in FreeLinX-desk/stack/sources.txt and in the ports' distinfo files; the
FreeLinX changes to them are the patches next to those lists.

Every upstream source archive, byte for byte as the build used it, is
mirrored with its SHA-256 at https://huggingface.co/datasets/FreeLinX/sources
- this covers the corresponding source of the GPL and LGPL components (the
Linux kernel, FFmpeg, GTK, GLib, alsa-lib, mpv, Dillo, Xfe, MuPDF, ...).  If you cannot obtain them, open an issue
at https://github.com/FreeLinX/FreeLinX/issues and they will be provided.
EOF
echo "collect-licenses: $n components in $L"
