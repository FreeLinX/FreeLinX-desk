#!/bin/sh
# FreeLinX - verify that a rootfs tree carries no GNU toolchain or glibc output.
#
# Usage: ./check-nognu.sh [ROOTFS]     (default: src/rootfs)
#
# Every ELF file is checked for:
#   gcc     .comment names a GCC compiler (object code from GCC got linked in)
#   interp  program interpreter is not musl's /lib/ld-musl-x86_64.so.1
#   needed  DT_NEEDED on glibc / GCC runtimes (libc.so.6, libgcc_s, libstdc++)
#   glibc   GLIBC_x.y symbol versions (built against glibc headers/libs)
#   file    a GCC runtime library is present at all (libgcc_s.so*)
#
# Exit status is the number of offending files (capped at 125), so a build
# script can refuse to package a tree that is not clean.  Known offenders that
# are still being rebuilt can be listed, one path per line relative to the
# rootfs, in check-nognu.allow; they are reported but do not fail the check.
set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOTFS="${1:-${SCRIPT_DIR}/src/rootfs}"
ALLOW="${SCRIPT_DIR}/check-nognu.allow"
READELF="${READELF:-}"
if [ -z "$READELF" ]; then
    for r in "${SCRIPT_DIR}/../toolchain/bin/llvm-readelf" llvm-readelf readelf; do
        command -v "$r" >/dev/null 2>&1 && { READELF="$r"; break; }
    done
fi
[ -n "$READELF" ] || { echo "check-nognu: no readelf found" >&2; exit 125; }
[ -d "$ROOTFS" ] || { echo "check-nognu: no such rootfs: $ROOTFS" >&2; exit 125; }

allowed() {
    [ -f "$ALLOW" ] && grep -qxF "$1" "$ALLOW"
}

bad=0
waived=0
report() { # path reason
    if allowed "$1"; then
        printf 'waived  %-8s %s\n' "$2" "$1"
        waived=$((waived + 1))
    else
        printf 'FAIL    %-8s %s\n' "$2" "$1"
        bad=$((bad + 1))
    fi
}

TMP="${TMPDIR:-/tmp}/check-nognu.$$"
trap 'rm -f "$TMP"' EXIT INT TERM

cd "$ROOTFS" || exit 125
find . -xdev -type f -size +100c | sed 's|^\./||' | while IFS= read -r f; do
    # ELF magic only.
    [ "$(head -c 4 "$f" 2>/dev/null | od -An -tx1 | tr -d ' \n')" = "7f454c46" ] || continue
    echo "$f"
done > "$TMP"

while IFS= read -r f; do
    reason=""
    case "$f" in
        */libgcc_s.so*|libgcc_s.so*) reason="file" ;;
    esac
    if [ -z "$reason" ] && "$READELF" -p .comment "$f" 2>/dev/null | grep -q 'GCC: ('; then
        reason="gcc"
    fi
    if [ -z "$reason" ]; then
        interp=$("$READELF" -l "$f" 2>/dev/null | sed -n 's/.*interpreter: \([^]]*\)\].*/\1/p')
        if [ -n "$interp" ] && [ "$interp" != "/lib/ld-musl-x86_64.so.1" ]; then
            reason="interp"
        fi
    fi
    if [ -z "$reason" ] && "$READELF" -d "$f" 2>/dev/null \
        | grep -qE 'NEEDED.*\[(libc\.so\.6|libgcc_s\.so[.0-9]*|libstdc\+\+\.so[.0-9]*|libm\.so\.6|libpthread\.so\.0|ld-linux[^]]*)\]'; then
        reason="needed"
    fi
    if [ -z "$reason" ] && "$READELF" -V "$f" 2>/dev/null | grep -q 'GLIBC_[0-9]'; then
        reason="glibc"
    fi
    [ -n "$reason" ] && report "$f" "$reason"
done < "$TMP" > "$TMP.out"

cat "$TMP.out"
bad=$(grep -c '^FAIL' "$TMP.out" 2>/dev/null) || bad=0
waived=$(grep -c '^waived' "$TMP.out" 2>/dev/null) || waived=0
rm -f "$TMP.out"
total=$(wc -l < "$TMP")
echo "check-nognu: $total ELF files, $bad failing, $waived waived."
[ "$bad" -gt 125 ] && bad=125
exit "$bad"
