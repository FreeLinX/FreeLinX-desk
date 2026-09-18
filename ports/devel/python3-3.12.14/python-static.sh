#!/bin/bash
# FreeLinX/ports - devel/python3-3.12.14 static build driver.
# Runs from inside the extracted CPython tree (SRC_TREE) with the FreeLinX
# toolchain env exported by the framework. Builds:
#   1. a native host Python (bootstrap for the cross configure)
#   2. the cross-configured tree (musl static)
#   3. compiles every extension module object and links them + a generated
#      inittab (Modules/config_static.c) into one fully static python3.12
#   4. installs the self-contained tree (bin + pure stdlib) into
#      build/deps/python3-3.12.14 and stages the same into the overlay.
set -e

SRC=$(pwd)
JOBS=$(nproc)
TC_BIN=$FREELINX_TOOLCHAIN_BIN
SYSROOT=$FREELINX_SYSROOT
TRIPLE=$FREELINX_TRIPLE
DEPS=$FREELINX_BUILD_DIR/deps
PY_PREFIX=$DEPS/python3-3.12.14
STAGE=$FREELINX_STAGING_ROOT
HOST=$FREELINX_BUILD_DIR/python-host
LOG=/tmp/freelinx-python.log

echo "[py] bootstrap host python at $HOST"
rm -rf "$HOST"; mkdir -p "$HOST"
tar xzf "$FREELINX_PORTS_ROOT/dist/Python-3.12.14.tgz" -C "$HOST" --strip-components=1
(
  cd "$HOST"
  for v in CC CXX AR LD NM RANLIB STRIP CFLAGS CXXFLAGS CPPFLAGS LDFLAGS \
           PKG_CONFIG PKG_CONFIG_LIBDIR PTHON_CFLAGS; do unset $v 2>/dev/null || true; done
  ./configure --without-ensurepip --prefix="$HOST/inst" >"$LOG.hcfg" 2>&1
  make -j"$JOBS" >"$LOG.hmake" 2>&1
  echo "[py] host python: $HOST/python"
)

echo "[py] configure cross tree"
./configure \
    --host=$TRIPLE --build=x86_64-pc-linux-gnu --disable-shared \
    --without-ensurepip --with-build-python="$HOST/python" \
    --with-openssl="$DEPS/openssl-3.3.2" --prefix="$PY_PREFIX" \
    ac_cv_buggy_getaddrinfo=no ac_cv_file__dev_ptmx=yes ac_cv_file__dev_ptc=no \
    >"$LOG.cfg" 2>&1

echo "[py] disable glibc-only modules (Setup.local)"
printf '*disabled*\n_lzma\nnis\n' > Modules/Setup.local

echo "[py] build all module objects (shared-link skipped)"
make -k all BLDSHARED=true -j"$JOBS" >"$LOG.make" 2>&1 || true
[ -f libpython3.12.a ] || { echo "[py] ERROR: libpython3.12.a missing"; exit 1; }

echo "[py] generate static inittab (Modules/config_static.c)"
names="array _asyncio audioop binascii _bisect _blake2 cmath _codecs_cn _codecs_hk _codecs_iso2022 _codecs_jp _codecs_kr _codecs_tw _contextvars _crypt _csv _datetime _decimal _elementtree fcntl grp _hashlib _heapq _json _lsprof math _md5 mmap _multibytecodec _multiprocessing _opcode ossaudiodev _pickle _posixshmem _posixsubprocess pyexpat _queue _random resource select _sha1 _sha2 _sha3 _socket spwd _sqlite3 _ssl _statistics _struct syslog termios unicodedata _xxinterpchannels _xxsubinterpreters _zoneinfo zlib"
comps="Modules/rotatingtree.o:_lsprof
Modules/_hacl/Hacl_Hash_MD5.o:_md5
Modules/_hacl/Hacl_Hash_SHA1.o:_sha1
Modules/_hacl/Hacl_Hash_SHA3.o:_sha3
Modules/_blake2/blake2b_impl.o Modules/_blake2/blake2s_impl.o:_blake2
Modules/_multiprocessing/semaphore.o:_multiprocessing
Modules/_sqlite/blob.o Modules/_sqlite/connection.o Modules/_sqlite/cursor.o Modules/_sqlite/microprotocols.o Modules/_sqlite/prepare_protocol.o Modules/_sqlite/row.o Modules/_sqlite/statement.o Modules/_sqlite/util.o:_sqlite3
Modules/cjkcodecs/multibytecodec.o:_multibytecodec"

GEN=$SRC/Modules/config_static.c
objs=""
entries=""
{
echo '#include "Python.h"'
echo 'extern PyObject* PyMarshal_Init(void);'
echo 'extern PyObject* PyInit__imp(void);'
echo 'extern PyObject* PyInit_gc(void);'
echo 'extern PyObject* PyInit__ast(void);'
echo 'extern PyObject* PyInit__tokenize(void);'
echo 'extern PyObject* _PyWarnings_Init(void);'
echo 'extern PyObject* PyInit__string(void);'
echo 'extern PyObject* PyInit_atexit(void);'
echo 'extern PyObject* PyInit_faulthandler(void);'
echo 'extern PyObject* PyInit_posix(void);'
echo 'extern PyObject* PyInit__signal(void);'
echo 'extern PyObject* PyInit__tracemalloc(void);'
echo 'extern PyObject* PyInit__codecs(void);'
echo 'extern PyObject* PyInit__collections(void);'
echo 'extern PyObject* PyInit_errno(void);'
echo 'extern PyObject* PyInit__io(void);'
echo 'extern PyObject* PyInit_itertools(void);'
echo 'extern PyObject* PyInit__sre(void);'
echo 'extern PyObject* PyInit__thread(void);'
echo 'extern PyObject* PyInit_time(void);'
echo 'extern PyObject* PyInit__typing(void);'
echo 'extern PyObject* PyInit__weakref(void);'
echo 'extern PyObject* PyInit__abc(void);'
echo 'extern PyObject* PyInit__functools(void);'
echo 'extern PyObject* PyInit__locale(void);'
echo 'extern PyObject* PyInit__operator(void);'
echo 'extern PyObject* PyInit__stat(void);'
echo 'extern PyObject* PyInit__symtable(void);'
echo 'extern PyObject* PyInit_pwd(void);'
for n in $names; do
  o=$(find Modules -name '*.o' ! -name 'config.o' ! -name 'config_static.o' | while read -r f; do if $NM --defined-only "$f" 2>/dev/null | grep -q " T PyInit_$n$"; then echo "$f"; break; fi; done | head -1)
  if [ -n "$o" ]; then
    objs="$objs $o"
    echo "extern PyObject* PyInit_$n(void);"
    entries="$entries
    {\"$n\", PyInit_$n},"
    c=$(printf '%s\n' "$comps" | sed -n "s/^\(.*\):$n\$/\1/p")
    [ -n "$c" ] && objs="$objs $c"
  else
    echo "[py] WARN: no object for $n" >&2
  fi
done
echo 'struct _inittab _PyImport_Inittab[] = {'
echo '    {"marshal", PyMarshal_Init},'
echo '    {"_imp", PyInit__imp},'
echo '    {"_ast", PyInit__ast},'
echo '    {"_tokenize", PyInit__tokenize},'
echo '    {"builtins", NULL},'
echo '    {"sys", NULL},'
echo '    {"gc", PyInit_gc},'
echo '    {"_warnings", _PyWarnings_Init},'
echo '    {"_string", PyInit__string},'
echo '    {"atexit", PyInit_atexit},'
echo '    {"faulthandler", PyInit_faulthandler},'
echo '    {"posix", PyInit_posix},'
echo '    {"_signal", PyInit__signal},'
echo '    {"_tracemalloc", PyInit__tracemalloc},'
echo '    {"_codecs", PyInit__codecs},'
echo '    {"_collections", PyInit__collections},'
echo '    {"errno", PyInit_errno},'
echo '    {"_io", PyInit__io},'
echo '    {"itertools", PyInit_itertools},'
echo '    {"_sre", PyInit__sre},'
echo '    {"_thread", PyInit__thread},'
echo '    {"time", PyInit_time},'
echo '    {"_typing", PyInit__typing},'
echo '    {"_weakref", PyInit__weakref},'
echo '    {"_abc", PyInit__abc},'
echo '    {"_functools", PyInit__functools},'
echo '    {"_locale", PyInit__locale},'
echo '    {"_operator", PyInit__operator},'
echo '    {"_stat", PyInit__stat},'
echo '    {"_symtable", PyInit__symtable},'
echo '    {"pwd", PyInit_pwd},'
printf '%s' "$entries"
echo '    {0, 0}'
echo '};'
} > "$GEN"

echo "[py] compile inittab"
$CC $CFLAGS -fPIC -I"$SRC/Include" -I"$SRC" -I"$SRC/Modules" -c "$GEN" -o Modules/config_static.o

echo "[py] final static link"
objs_uniq=$(echo $objs | tr ' ' '\n' | sed '/^$/d' | sort -u)
$CC $LDFLAGS -o python-static \
  Programs/python.o Modules/config_static.o \
  $objs_uniq \
  -Wl,--start-group \
    -L. -lpython3.12 \
    Modules/expat/libexpat.a \
    Modules/_decimal/libmpdec/libmpdec.a \
    Modules/_hacl/libHacl_Hash_SHA2.a \
    -lssl -lcrypto -lz -lffi -lsqlite3 -lcrypt \
    -lm -pthread -ldl \
  -Wl,--end-group

echo "[py] install layout (deps + staging overlay)"
mkdir -p "$PY_PREFIX/bin" "$PY_PREFIX/lib/python3.12"
cp python-static "$PY_PREFIX/bin/python3.12"
cp -a Lib/. "$PY_PREFIX/lib/python3.12/"
mkdir -p "$PY_PREFIX/lib/python3.12/lib-dynload"
[ -f "$PY_PREFIX/bin/python3.12" ]

echo "[py] fix multiarch tag linux-gnu -> linux-musl"
grep -rl 'x86_64-linux-gnu' "$PY_PREFIX/lib/python3.12/_sysconfigdata"* 2>/dev/null \
  | while read -r f; do sed -i 's/x86_64-linux-gnu/x86_64-linux-musl/g' "$f"; done
grep -rl 'x86_64-linux-gnu' "$SRC/Lib/_sysconfigdata"* 2>/dev/null \
  | while read -r f; do sed -i 's/x86_64-linux-gnu/x86_64-linux-musl/g' "$f"; done

echo "[py] stage overlay"
mkdir -p "$STAGE/bin" "$STAGE/lib/python3.12"
cp python-static "$STAGE/bin/python3.12"
cp -a Lib/. "$STAGE/lib/python3.12/"
mkdir -p "$STAGE/lib/python3.12/lib-dynload"
grep -rl 'x86_64-linux-gnu' "$STAGE/lib/python3.12/_sysconfigdata"* 2>/dev/null \
  | while read -r f; do sed -i 's/x86_64-linux-gnu/x86_64-linux-musl/g' "$f"; done

echo "[py] smoke test"
"$PY_PREFIX/bin/python3.12" -VV
"$PY_PREFIX/bin/python3.12" -c "import ssl,hashlib,zlib,sqlite3,threading; print('static python OK;', hashlib.sha256(b'static').hexdigest()[:8], ssl.OPENSSL_VERSION)" | tail -1

echo "[py] done"