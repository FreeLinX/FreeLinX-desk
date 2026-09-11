# FreeLinX/ports - mk/pkgconfig-libdir.mk : aggregate pkg-config search dirs
# from every installed dependency tree under $(FREELINX_BUILD_DIR)/deps/*.
# Built live so no developer-specific path is ever hard-coded; both
# lib/pkgconfig and share/pkgconfig trees are picked up.

_empty :=
_space := $(_empty) $(_empty)

_flx_pc_dirs := \
	$(wildcard $(FREELINX_BUILD_DIR)/deps/*/lib/pkgconfig) \
	$(wildcard $(FREELINX_BUILD_DIR)/deps/*/share/pkgconfig)

export PKG_CONFIG_LIBDIR:=$(strip $(subst $(_space),:,$(_flx_pc_dirs)))