#!/bin/sh
cd /home/devuan/FreeLinX/Desktop-test
rm -rf /tmp/chr
cp -a src/rootfs /tmp/chr
mkdir -p /tmp/chr/dev /tmp/chr/proc /tmp/chr/sys /tmp/chr/tmp
C=/usr/sbin/chroot
R=/tmp/chr
# ensure stest executes
$C $R /bin/stest -flx /bin /usr/bin > /tmp/chr_stest_flx.txt 2>&1
echo "flx-lines: $(wc -l < /tmp/chr_stest_flx.txt)"
echo "first4:"
head -4 /tmp/chr_stest_flx.txt
echo "--- elx ---"
$C $R /bin/stest -elx /bin /usr/bin 2>&1 | wc -l
echo "--- simulate dmenu_path cold: stest -dqr -n missing cache ---"
rm -f /tmp/chr/root/.cache/dmenu_run
$C $R /bin/sh -c 'PATH=/bin:/usr/bin; export PATH; rm -rf /root/.cache; mkdir -p /root/.cache; v=$(/bin/stest -flx $PATH | sort -u); echo "items=$(printf "%s\n" "$v" | grep -c .)"; echo "first4: $(printf "%s\n" "$v" | head -4 | tr "\n" " ")"; mkdir -p /root/.cache; printf "%s\n" "$v" > /root/.cache/dmenu_run; echo "cachebytes=$(wc -c < /root/.cache/dmenu_run)"' 2>&1
echo "--- AFTER cache written: stest -dqr -n (second run branch?) ---"
$C $R /bin/sh -c 'PATH=/bin:/usr/bin; export PATH; /bin/stest -dqr -n /root/.cache/dmenu_run $PATH; echo "rc=$? (0=>rebuild/tee, else=>cat cache)"' 2>&1
