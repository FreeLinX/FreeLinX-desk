#!/bin/bash
# MINIMAL ground truth: does toybox sh split $PATH (IFS=:) into SEPARATE
# args when it execs stest? If yes, guest dmenu_path -flx $PATH sees real dirs.
GBABC="/home/devuan/FreeLinX/Desktop-test/src/rootfs/bin"
GUABC="/home/devuan/FreeLinX/Desktop-test/src/rootfs/usr/bin"
SH="/home/devuan/FreeLinX/Desktop-test/src/rootfs/bin/sh"
STEST="/home/devuan/FreeLinX/Desktop-test/src/rootfs/bin/stest"
# 1) guest-like short PATH with two real dirs
P2="$GBABC:$GUABC"
echo "=== A) stest -flx with $PATH unquoted (toybox sh decides split) ==="
env PATH="$P2" "$SH" -c 'IFS=:; stest -flx $PATH | wc -l'
echo "=== B) control: same but stop stest after split by using sh to count $# ==="
env PATH="$P2" "$SH" -c 'IFS=:; set -- $PATH; echo "toybox-sh got $# path-args after IFS=: split  (1 => NO split = the bug)"'
echo "=== C) stest -flx given the dirs as EXPLICIT two args ==="
"$STEST" -flx "$GBABC" "$GUABC" | wc -l
echo "=== D) cold dmenu_path EXACT (full) on host-side toybox sh, fresh cache ==="
rm -rf /tmp/dpc; mkdir -p /tmp/dpc/.cache
env PATH="$P2" XDG_CACHE_HOME=/tmp/dpc/.cache HOME=/tmp/dpc "$SH" -c '
cachedir=/tmp/dpc/.cache; cache="$cachedir/dmenu_run"
IFS=:
if stest -dqr -n "$cache" $PATH; then
	echo "BRANCH=REBUILD"; stest -flx $PATH | sort -u | tee "$cache" | wc -l
else
	echo "BRANCH=CAT"; wc -l < "$cache"
fi'
echo "=== E) WARM re-run (cache exists now): should CAT a NON-EMPTY file ==="
env PATH="$P2" XDG_CACHE_HOME=/tmp/dpc/.cache HOME=/tmp/dpc "$SH" -c '
cachedir=/tmp/dpc/.cache; cache="$cachedir/dmenu_run"; IFS=:
if stest -dqr -n "$cache" $PATH; then echo "BRANCH=REBUILD-again"; else echo "BRANCH=CAT"; wc -l < "$cache"; fi'
echo "=== F) what the REAL guest dmenu_run reads: byte size of cache ==="
stat -c 'cache-bytes=%s' /tmp/dpc/.cache/dmenu_run