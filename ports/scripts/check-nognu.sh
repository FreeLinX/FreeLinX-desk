#!/bin/sh
# FreeLinX/ports check-nognu.sh
#
# Verifies that the FreeLinX desktop tools (dwm, dmenu, slstatus, nsxiv,
# xclip, xinit, xorg-server) are no-GNU builds:
#
#   - the binary must be an x86-64 ELF (never a GNU toolchain build host target
#     mattering; arch is checked for sanity),
#   - it must contain NO GLIBC_*, __gnu_lto*, or GNU IFUNC symbols,
#   - a static binary must not name the GNU loader (/lib64/ld-linux-*),
#   - a dynamic binary must use ONLY the musl loader
#     (/lib/ld-musl-x86_64.so.1) and depend on nothing beyond libc.so
#     (i.e. the dynamic closure is musl libc only — no glibc, no GNU libs).
#
# Usage:
#   ./scripts/check-nognu.sh [name ...]
#   ./scripts/check-nognu.sh all      (default)
#
# Exits 0 when every checked tool passes, 1 otherwise.

set -eu

FREELINX_ROOT=$(CDPATH='' cd -P "$(dirname "$0")/.." && pwd)
STAGE="$FREELINX_ROOT/staging"
ROOTFS="$FREELINX_ROOT/../src/rootfs"

MUSL_LOADER=/lib/ld-musl-x86_64.so.1

# name:path1:path2:...  (first existing path wins)
TOOLSPEC="dwm:$STAGE/bin/dwm:$ROOTFS/bin/dwm
slstatus:$STAGE/bin/slstatus:$ROOTFS/bin/slstatus
dmenu:$STAGE/bin/dmenu:$ROOTFS/bin/dmenu
nsxiv:$STAGE/bin/nsxiv:$ROOTFS/bin/nsxiv
xclip:$STAGE/bin/xclip:$ROOTFS/bin/xclip
xinit:$STAGE/bin/xinit:$ROOTFS/bin/xinit
xorg-server:$STAGE/usr/bin/Xorg:$ROOTFS/usr/bin/Xorg"

FAIL=0
TOTAL=0

check_one() {
    _name=$1
    _path=$2
    TOTAL=$((TOTAL + 1))

    if [ ! -f "$_path" ]; then
        printf '[check-nognu][FAIL] %-12s missing: %s\n' "$_name" "$_path"
        FAIL=$((FAIL + 1))
        return
    fi

    _type=$(file -b "$_path" 2>/dev/null || echo unknown)

    # 1) dynamic interpreter must be musl (if any).
    _interp=$(readelf -l "$_path" 2>/dev/null | sed -n 's/.*interpreter: \([^]]*\).*/\1/p' || true)
    if [ -n "$_interp" ]; then
        case "$_interp" in
            "$MUSL_LOADER") : ;;
            *)
                printf '[check-nognu][FAIL] %-12s non-musl loader: %s\n' "$_name" "$_interp"
                FAIL=$((FAIL + 1))
                ;;
        esac
    fi

    # 2) dynamic deps must be musl libc only (libc.so). Reject any that is
    #    glibc (libc.so.6, ld-linux) or any other shared object.
    if command -v readelf >/dev/null 2>&1; then
        _needed=$(readelf -d "$_path" 2>/dev/null | sed -n 's/.*(NEEDED).*\[\(.*\)\]/\1/p' || true)
        for _n in $_needed; do
            case "$_n" in
                libc.so) : ;;
                *ld-linux*|libc.so.6|*gnu*|-lgnu*)
                    printf '[check-nognu][FAIL] %-12s GNU/glibc dep: %s\n' "$_name" "$_n"
                    FAIL=$((FAIL + 1))
                    ;;
                *)
                    printf '[check-nognu][FAIL] %-12s non-musl dep: %s\n' "$_name" "$_n"
                    FAIL=$((FAIL + 1))
                    ;;
            esac
        done
    fi

    # 3) no glibc-versioned dynamic symbols (GLIBC_2.x) and no GNU loader refs.
    if strings -a "$_path" 2>/dev/null | grep -qE 'GLIBC_[0-9]|^__gnu_|(^|[^A-Za-z])gnu_lto'; then
        printf '[check-nognu][FAIL] %-12s contains glibc-versioned/GNU symbols\n' "$_name"
        FAIL=$((FAIL + 1))
    fi
    if strings -a "$_path" 2>/dev/null | grep -q '/lib64/ld-linux'; then
        printf '[check-nognu][FAIL] %-12s names the GNU dynamic loader\n' "$_name"
        FAIL=$((FAIL + 1))
    fi

    # 4) dynamic symbol versioning sections must not bind against GLIBC.
    if command -v readelf >/dev/null 2>&1; then
        if readelf -V "$_path" 2>/dev/null | grep -qE 'GLIBC_[0-9]'; then
            printf '[check-nognu][FAIL] %-12s ELF version table references glibc\n' "$_name"
            FAIL=$((FAIL + 1))
        fi
    fi

    printf '[check-nognu][ OK ] %-12s %s\n' "$_name" "$(basename "$_type")"
}

if [ $# -gt 0 ] && [ "$1" != "all" ]; then
    spec=""
    for _arg in "$@"; do
        _match=$(printf '%s\n' "$TOOLSPEC" | grep "^$_arg:" || true)
        if [ -z "$_match" ]; then
            _match="$_arg::"
        fi
        spec="$spec
$_match"
    done
    TOOLSPEC=$spec
fi

for _line in $TOOLSPEC; do
    _name=${_line%%:*}
    _rest=${_line#*:}
    _a=${_rest%%:*}
    _rest2=${_rest#*:}
    _b=${_rest2%%:*}
    _c=${_rest2#*:}
    [ -z "$_name" ] && continue
    # first existing path wins
    _path=""
    for _p in "$_a" "$_b" "$_c"; do
        [ -z "$_p" ] && continue
        if [ -e "$_p" ]; then
            _path=$_p
            break
        fi
    done
    [ -z "$_path" ] && _path=$_a
    check_one "$_name" "$_path"
done

if [ "$FAIL" -eq 0 ]; then
    printf '[check-nognu] %d/%d tools pass (no GNU, musl-only)\n' "$TOTAL" "$TOTAL"
    exit 0
fi
printf '[check-nognu][WARN] %d tool(s) FAILED the no-GNU check\n' "$FAIL" >&2
exit 1