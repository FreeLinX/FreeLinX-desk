#!/bin/sh
# Replicate the GUEST dmenu_path EXACTLY on host, with guest binaries,
# fully controlled temp PATH. Proves whether the cache logic yields data.
cd /home/devuan/FreeLinX/Desktop-test
SH=src/rootfs/bin/sh
STEST=src/rootfs/bin/stest
TESTDIR=/tmp/dprep/cache
export HOME=/root

# controlled PATH: two dirs with a few executables; one is a toybox-style symlink
rm -rf /tmp/dprep && mkdir -p /tmp/dprep/a /tmp/dprep/b
cp /bin/ls /tmp/dprep/a/aa_alpha
cp /bin/cat /tmp/dprep/b/bb_beta
ln -sf /tmp/dprep/a/aa_alpha /tmp/dprep/b/bb_sym
CPATH="/tmp/dprep/a:/tmp/dprep/b"

echo "=== guest stest -n on MISSING cache (first cold run): which branch? ==="
rm -rf /root/.cache && echo "removed /root/.cache"
env PATH="$CPATH" HOME=/root $SH -c '
	cachedir="${XDG_CACHE_HOME:-"$HOME/.cache"}"
	cache="$cachedir/dmenu_run"
	[ ! -e "$cachedir" ] && mkdir -p "$cachedir"
	IFS=:
	if stest -dqr -n "$cache" $PATH; then
		echo "[BRANCH=rebuild-stest-flx]"
		stest -flx $PATH | sort -u | tee "$cache"
	else
		echo "[BRANCH=cat]"
		cat "$cache"
	fi
	echo "cache-lines-after=$(wc -l < $cache 2>/dev/null || echo NA)"
	echo "cache-bytes=$(stat -c%s "$cache" 2>/dev/null || echo NA)"
' 2>&1
echo
echo "=== second run (cache now exists): which branch? + stdin bytes fed to dmenu ==="
env PATH="$CPATH" HOME=/root $SH -c '
	cache="${XDG_CACHE_HOME:-"$HOME/.cache"}/dmenu_run"
	IFS=:
	if stest -dqr -n "$cache" $PATH; then
		stest -flx $PATH | sort -u | tee "$cache"
	else
		cat "$cache"
	fi
' 2>&1
echo "=== GUEST-də toybox sh colon-split həqiqətən: for loop over \$PATH count ==="
env PATH="$CPATH" HOME=/root $SH -c 'IFS=:; n=0; for d in $PATH; do n=$((n+1)); done; echo "split-dirs=$n"'
