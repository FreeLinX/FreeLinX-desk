# FreeLinX/ports - audio/alsa-utils : ALSA userspace utilities.
#
# Provides: aplay, arecord, amixer, alsamixer, alsactl, aconnect, aseqdump,
#           aseqnet, speaker-test, aserver.
#
# Depends on audio/alsa-lib (libasound.a) built first.
# Toolchain: clang + LLD + musl (no GCC, no glibc).
#
# alsamixer requires ncurses; we use netbsd-curses (no GNU curses required).
#
# Configure flags:
#   --disable-alsaconf     no Perl-based config helper
#   --disable-alsatest     no test tool
#   --disable-bat          no bit-accurate test (avoids fftw3 dependency)
#   --disable-nls          no gettext / GNU NLS (keeps it GNU-free)
#   --disable-xmlto        no man page regeneration
#   --disable-alsa-topology  simplifies build graph
#   --with-curses=ncurses  specify curses implementation

NAME    := alsa-utils
VERSION := 1.2.13
CATEGORY := audio
TARGET  := $(FREELINX_TRIPLE)
LICENSE := GPL-2.0
DEPENDENCIES := audio/alsa-lib, devel/netbsd-curses

INSTALL_BIN    := alsamixer
INSTALL_RELPATH := bin/$(INSTALL_BIN)

ALSA_UTILS_PREFIX  := $(FREELINX_BUILD_DIR)/deps/alsa-utils
ALSA_LIB_PREFIX    := $(FREELINX_BUILD_DIR)/deps/alsa-lib
NCURSES_PREFIX     := $(FREELINX_BUILD_DIR)/deps/netbsd-curses

PROJECT_BIN := $(ALSA_UTILS_PREFIX)/bin/alsamixer
BUILD_BIN   := $(PROJECT_BIN)

FLX_PROJECT_CPPFLAGS := \
	-I$(ALSA_LIB_PREFIX)/include \
	-I$(NCURSES_PREFIX)/include

FLX_PROJECT_LDFLAGS := \
	-L$(ALSA_LIB_PREFIX)/lib \
	-L$(NCURSES_PREFIX)/lib

FLX_PROJECT_LIBS :=

include ../../mk/project-port.mk

PROJECT_CFG_CMDS = \
	./configure \
		--host="$(FREELINX_TRIPLE)" \
		--prefix="$(ALSA_UTILS_PREFIX)" \
		--enable-static \
		--disable-shared \
		--disable-alsaconf \
		--disable-alsatest \
		--disable-bat \
		--disable-nls \
		--disable-xmlto \
		--disable-alsa-topology \
		--with-curses=ncurses \
		CPPFLAGS="$(FLX_PROJECT_CPPFLAGS)" \
		LDFLAGS="$(LDFLAGS) -lasound -lncursesw" \
		LIBS="-lasound -lncursesw -ltinfo -lm"

# Build only core utilities; install all then copy the key binaries to staging.
BUILD_CMDS = \
	$(MAKE) $(if $(FREELINX_JOBS),-j$(FREELINX_JOBS),) && \
	$(MAKE) install && \
	mkdir -p "$(FREELINX_STAGING_ROOT)/bin" \
	         "$(FREELINX_STAGING_ROOT)/sbin" && \
	for _b in alsamixer amixer aplay arecord alsactl speaker-test; do \
		if [ -f "$(ALSA_UTILS_PREFIX)/bin/$$_b" ]; then \
			$(STRIP) "$(ALSA_UTILS_PREFIX)/bin/$$_b"; \
			cp -f "$(ALSA_UTILS_PREFIX)/bin/$$_b" \
			      "$(FREELINX_STAGING_ROOT)/bin/$$_b"; \
		fi; \
	done
