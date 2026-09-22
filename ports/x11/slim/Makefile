# FreeLinX/ports - x11/slim : Simple Login Manager (SLiM).
#
# SLiM is a lightweight desktop graphical login manager (Display Manager).
# Built with C++ / CMake against musl + LLVM libc++ + PAM + X11 + libpng + Xft.
# ZERO GNOME / GNU glibc dependency.
#
# Configure flags (CMake):
#   -DUSE_PAM=ON             enable PAM authentication
#   -DUSE_CONSOLEKIT=OFF     disable ConsoleKit (not used in FreeLinX)
#   -DCMAKE_INSTALL_PREFIX   destination path

NAME    := slim
VERSION := 1.4.0
CATEGORY := x11
TARGET  := $(FREELINX_TRIPLE)
LICENSE := GPL-2.0
DEPENDENCIES := security/linux-pam, x11/libX11-1.8.10, x11/libXft-2.3.8, \
                x11/libXrender-0.9.11, x11/libXext-1.3.6, graphics/libpng

BUILD_DEPENDENCIES := cmake, pkgconf

INSTALL_BIN    := slim
INSTALL_RELPATH := bin/$(INSTALL_BIN)

SLIM_PREFIX  := $(FREELINX_BUILD_DIR)/deps/slim
PAM_PREFIX   := $(FREELINX_BUILD_DIR)/deps/linux-pam
X11_PREFIX   := $(FREELINX_BUILD_DIR)/deps/x11
PNG_PREFIX   := $(FREELINX_BUILD_DIR)/deps/libpng

PROJECT_BIN := $(SLIM_PREFIX)/bin/slim
BUILD_BIN   := $(PROJECT_BIN)

FLX_PROJECT_CXXFLAGS := -O2 -stdlib=libc++ -std=c++17
FLX_PROJECT_CPPFLAGS := \
	-I$(PAM_PREFIX)/include \
	-I$(X11_PREFIX)/include \
	-I$(PNG_PREFIX)/include

FLX_PROJECT_LDFLAGS := \
	-L$(PAM_PREFIX)/lib \
	-L$(X11_PREFIX)/lib \
	-L$(PNG_PREFIX)/lib

include ../../mk/project-port.mk

SLIM_BUILD_DIR := $(FREELINX_BUILD_DIR)/obj/slim-build

PROJECT_CFG_CMDS = \
	mkdir -p "$(SLIM_BUILD_DIR)" && \
	cd "$(SLIM_BUILD_DIR)" && \
	cmake "$(SRC_TREE)" \
		-DCMAKE_SYSTEM_NAME=Linux \
		-DCMAKE_C_COMPILER="$(CC)" \
		-DCMAKE_CXX_COMPILER="$(CXX)" \
		-DCMAKE_C_FLAGS="$(CFLAGS)" \
		-DCMAKE_CXX_FLAGS="$(CXXFLAGS)" \
		-DCMAKE_INSTALL_PREFIX="$(SLIM_PREFIX)" \
		-DUSE_PAM=ON \
		-DUSE_CONSOLEKIT=OFF

BUILD_CMDS = \
	$(MAKE) -C "$(SLIM_BUILD_DIR)" $(if $(FREELINX_JOBS),-j$(FREELINX_JOBS),) && \
	$(MAKE) -C "$(SLIM_BUILD_DIR)" install && \
	$(STRIP) "$(PROJECT_BIN)"
