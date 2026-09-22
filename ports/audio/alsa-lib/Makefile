# FreeLinX/ports - audio/alsa-lib : ALSA userspace library (libasound).
#
# alsa-lib provides the low-level ALSA interface (libasound.so / libasound.a).
# It communicates with the kernel ALSA subsystem via /dev/snd/* device nodes.
# No GNU libc-specific code is used; musl is fully compatible.
#
# Toolchain: clang + LLD + musl (no GCC, no glibc).
#
# Configure flags explained:
#   --without-versioned-symbols   avoids GNU symbol versioning (LLD compat)
#   --disable-shared              static library only (FreeLinX policy)
#   --enable-static               build libasound.a
#   --disable-python              no Python binding (build-host only anyway)
#   --disable-rawmidi             reduces footprint (initramfs target)
#   --disable-seq                 reduces footprint (no MIDI sequencer needed)
#   --disable-mixer-abst          disable deprecated abstraction layer
#   --with-alsa-devdir=/dev/snd   standard Linux ALSA device path
#
# The resulting libasound.a is staged to:
#   staging/lib/libasound.a
#   staging/include/alsa/

NAME    := alsa-lib
VERSION := 1.2.13
CATEGORY := audio
TARGET  := $(FREELINX_TRIPLE)
LICENSE := LGPL-2.1
DEPENDENCIES :=

INSTALL_BIN    := libasound.a
INSTALL_RELPATH := lib/$(INSTALL_BIN)

ALSA_LIB_PREFIX := $(FREELINX_BUILD_DIR)/deps/alsa-lib

PROJECT_BIN  := $(ALSA_LIB_PREFIX)/lib/libasound.a
BUILD_BIN    := $(PROJECT_BIN)

FLX_PROJECT_CFLAGS   := -O2 -fPIC
FLX_PROJECT_CPPFLAGS :=
FLX_PROJECT_LDFLAGS  :=
FLX_PROJECT_LIBS     :=

include ../../mk/project-port.mk

PROJECT_CFG_CMDS = \
	./configure \
		--host="$(FREELINX_TRIPLE)" \
		--prefix="$(ALSA_LIB_PREFIX)" \
		--enable-static \
		--disable-shared \
		--without-versioned-symbols \
		--disable-python \
		--disable-rawmidi \
		--disable-seq \
		--with-alsa-devdir=/dev/snd

BUILD_CMDS = \
	$(MAKE) $(if $(FREELINX_JOBS),-j$(FREELINX_JOBS),) && \
	$(MAKE) install && \
	mkdir -p "$(FREELINX_STAGING_ROOT)/lib" \
	         "$(FREELINX_STAGING_ROOT)/include" && \
	cp -f "$(ALSA_LIB_PREFIX)/lib/libasound.a" \
	      "$(FREELINX_STAGING_ROOT)/lib/libasound.a" && \
	cp -r "$(ALSA_LIB_PREFIX)/include/alsa" \
	      "$(FREELINX_STAGING_ROOT)/include/alsa"
