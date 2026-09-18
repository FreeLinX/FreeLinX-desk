# FreeLinX/ports - graphics/xclip : xclip 0.13 (X11 clipboard utility).
#
# Set the PRIMARY/CLIPBOARD selections from stdin, or dump them.  The
# smallest of the Priority-2 trio: plain autotools, Xlib + libXmu only,
# no imlib.  autoconf/autoreconf run the host-side `bootstrap` (autoreconf -i);
# the delivered link is a plain static clang+lld+musl closure over the
# deps/x11 tree.
NAME:=xclip
VERSION:=0.13
CATEGORY:=graphics
TARGET:=$(FREELINX_TRIPLE)
LICENSE:=GPL-2.0+
DEPENDENCIES:=
BUILD_DEPENDENCIES:=libXmu-1.2.1, libXt-1.3.1, libSM-1.2.5, libICE-1.1.2

XC_PREFIX=$(FREELINX_BUILD_DIR)/deps/xclip
FLX_PREFIX=$(FREELINX_BUILD_DIR)/deps/x11
SRC_TREE=$(FREELINX_BUILD_DIR)/work/$(NAME)/$(DISTINFO_NAME)
PROJECT_BIN=$(XC_PREFIX)/bin/xclip
BUILD_BIN=$(PROJECT_BIN)
INSTALL_RELPATH=bin/xclip

# Pure-C stack: drop the default C++/unwind link closure, and steer the
# configure probes (headers + AC_CHECK_LIB) into the deps/x11 tree.
FLX_PROJECT_LIBS?=
FLX_PROJECT_CPPFLAGS=-I$(FLX_PREFIX)/include
FLX_PROJECT_LDFLAGS=-L$(FLX_PREFIX)/lib

include ../../mk/project-port.mk

PROJECT_CFG_CMDS = \
	autoreconf -i && \
	\
	ac_cv_lib_Xmu_XmuClientWindow=yes \
	./configure \
		--host=x86_64-linux-musl \
		--prefix="$(XC_PREFIX)" \
		--x-includes="$(FLX_PREFIX)/include" \
		--x-libraries="$(FLX_PREFIX)/lib"

BUILD_CMDS = \
	sed -i 's|-lX11 -lXmu|-lX11 -lXmu -lXt -lSM -lICE -lXext -lXau -lXdmcp -lxcb|' Makefile && \
	make && \
	mkdir -p "$(XC_PREFIX)/bin" && \
	cp -f xclip "$(XC_PREFIX)/bin/xclip"