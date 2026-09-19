# FreeLinX/ports - BSD-style ports framework.
#
# Top-level interface. Like FreeLinX/src, this Makefile wires up the scripts
# in scripts/ rather than duplicating build logic. The actual port recipes
# live in per-port Makefiles under base/ and shells/.
#
# The framework works with a configurable external FreeLinX toolchain; no
# hard-coded developer paths. See config/default.conf and README.md.

SHELL := /bin/sh

PWD_ := $(CURDIR)

.PHONY: all build install clean fetch check list package check-nognu help

## build - build PORT (e.g. make build PORT=netbsd-sh); default all ports
build:
	./scripts/build.sh $(PORT)

## install - stage PORT; add -r to copy into FreeLinX/src rootfs
install:
	./scripts/install.sh $(INSTALL_FLAGS) $(PORT)

## clean - remove generated artifacts (build/, staging/, dist/, .config.mk)
clean:
	./scripts/clean.sh

## fetch - download+verify upstream source for PORT (or all)
fetch:
	./scripts/fetch.sh $(PORT)

## check - report toolchain/config state without building
check:
	./scripts/check.sh

## list - list available ports and their metadata
list:
	@sh scripts/list.sh

## package - build .xpkg packages for the desktop tools (dwm, dmenu, slstatus,
##            nsxiv, xclip, xinit, xorg-server) into packages/ + index.json
package:
	./scripts/package.sh $(PORT)

## check-nognu - verify the desktop tool binaries are musl/no-GNU
check-nognu:
	./scripts/check-nognu.sh $(PORT)

## help - show this help
help:
	@echo 'FreeLinX/ports targets:'
	@echo '  build  [PORT=name] - build a port (default: all). PORT e.g. netbsd-sh or base/cat'
	@echo '  install [PORT=name] - stage a port; add INSTALL_FLAGS=-r to copy into src rootfs'
	@echo '  fetch  [PORT=name] - download + verify upstream source'
	@echo '  check  - report config/toolchain/port state (read-only)'
	@echo '  list   - list ports and metadata'
	@echo '  package [PORT=name] - package desktop tools into .xpkg + index.json'
	@echo '  check-nognu [PORT=name] - verify the desktop tools are musl/no-GNU'
	@echo '  clean  - remove generated artifacts'
	@echo
	@echo 'Configuration: FREELINX_* env vars override config/default.conf'
	@echo 'See README.md for details.'
