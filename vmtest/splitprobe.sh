#!/bin/bash
# Decisive root-cause test: does GUEST toybox sh word-split $PATH (IFS=:)
# into SEPARATE dir args when calling stest -flx $PATH ?
# If toybox sh does NOT split → stest sees 1 colon-joined dir → empty cache.
cd /home/devuan/FreeLinX/Desktop-test
SH=src/rootfs/bin/sh
S=src/rootfs/bin/stest
cleanPATH="/usr/share/X11/xtree/bin:/usr/bin:/bin"

echo "### A) stest with colon-joined SINGLE arg (what happens if sh does NOT split) ###"
$S -flx "$cleanPATH" | wc -l

echo "### B) stest with SEPARATE args (expected, 3 dirs) ###"
$S -flx /usr/share/X11/xtree/bin /usr/bin /bin 2>/dev/null | wc -l
echo "### B2) toybox stest dir-exists only? count real dirs ###"
n=0; for d in ${cleanPATH//:/ }; do [ -d "$d" ] && n=$((n+1)); done; echo "real dirs=$n"

echo "### C) GUEST toybox sh: IFS=: ; stest -flx \$PATH  (unquoted) → how many lines? ###"
env PATH="$cleanPATH" $SH -c 'IFS=:; stest -flx $PATH 2>/dev/null | wc -l'

echo "### D) control: toybox sh for-loop over \$PATH proves sh CAN split ###"
env PATH="$cleanPATH" $SH -c 'IFS=:; n=0; for d in $PATH; do n=$((n+1)); done; echo "for-loop iterations=$n"'

echo "### E) captive: use toybox sh to actually prune the cache pipeline vs dmenu ###"
rm -f /tmp/ctest/cache; mkdir -p /tmp/ctest
env PATH="$cleanPATH" HOME=/root $SH -c '
cachedir=/root/.cache; cache=$cachedir/dmenu_run
[ ! -e "$cachedir" ] && mkdir -p "$cachedir"
IFS=:
if stest -dqr -n "$cache" $PATH; then
	# print how many stest would give per split-dir
	stest -flx /usr/share/X11/xtree/bin /usr/bin /bin 2>/dev/null | sort -u | tee "$cache" >/dev/null
else
	cat "$cache"
fi
echo "cache-lines=$(wc -l < "$cache" 2>/dev/null || echo MISSING)"
'
echo "### F) does the stub dmenu binary get cache via stdin? dump guest serial tail ###"
