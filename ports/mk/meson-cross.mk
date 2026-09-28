# -*- makefile -*-
# FreeLinX/ports - mk/meson-cross.mk : render port-local meson cross files.
#
# WHY THIS EXISTS
# ---------------
# meson only expands its @DIRNAME@ (and @GLOBAL_SOURCE_ROOT@) placeholders for
# cross/native files that live *inside* the project source tree.  FreeLinX
# keeps its cross files next to the port recipe in the ports tree instead, so
# the placeholder reached meson verbatim and every meson port aborted with:
#
#   meson.build:26:0: ERROR: Unknown compiler(s):
#   [['@DIRNAME@/../../../../toolchain/bin/clang', ...]]
#
# That single bug is why no port under graphics/ had ever produced a package:
# they were all written, none of them had ever been run.  This helper renders
# the template into the build dir with the port directory substituted, so all
# of them work without touching the per-port recipes.
#
# USAGE
#   include ../../mk/meson-cross.mk
#   FLX_MESON_CROSS         -> generated cross file   (--cross-file)
#   FLX_MESON_CROSS_NATIVE  -> generated native file  (--native-file)
#
# Templates may use either @DIRNAME@ (the port directory, which keeps the
# existing "../../../../toolchain/..." chains working) or the canonical tokens
# below, which are anchored to FREELINX_TOOLCHAIN_* so a port never has to
# hard-code a developer path:
#   @TOOLCHAIN_DIR@  @TOOLCHAIN_BIN@  @SYSROOT@  @PORTS_ROOT@

FLX_MESON_CROSS_TEMPLATE ?= $(CURDIR)/meson-cross.ini
FLX_MESON_NATIVE_TEMPLATE?= $(CURDIR)/meson-native.ini

FLX_MESON_CROSS         ?= $(OBJ_DIR)/flx-meson-cross.ini
FLX_MESON_CROSS_NATIVE  ?= $(OBJ_DIR)/flx-meson-native.ini

# $(1) = template, $(2) = output file.  No-op when the template is absent so
# ports without meson need no special-casing.
define flx_render_meson_file
	@if [ -f "$(1)" ]; then \
		mkdir -p "$(dir $(2))"; \
		sed -e 's|@DIRNAME@|$(CURDIR)|g' \
		    -e 's|@TOOLCHAIN_DIR@|$(FREELINX_TOOLCHAIN_DIR)|g' \
		    -e 's|@TOOLCHAIN_BIN@|$(FREELINX_TOOLCHAIN_BIN)|g' \
		    -e 's|@SYSROOT@|$(FREELINX_SYSROOT)|g' \
		    -e 's|@PORTS_ROOT@|$(FREELINX_PORTS_ROOT)|g' \
		    "$(1)" > "$(2)"; \
		printf '[FreeLinX/ports] meson file: %s -> %s\n' "$(1)" "$(2)"; \
	fi
endef

.PHONY: do-render-meson
do-render-meson:
	$(call flx_render_meson_file,$(FLX_MESON_CROSS_TEMPLATE),$(FLX_MESON_CROSS))
	$(call flx_render_meson_file,$(FLX_MESON_NATIVE_TEMPLATE),$(FLX_MESON_CROSS_NATIVE))
