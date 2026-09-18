# FreeLinX/ports - graphics/noto-fonts-sans : Noto Sans TTF (monthly release).
#
# Data-only port: 4 static Hinted TTF styles (Regular/Bold/Italic/BoldItalic)
# staged at /usr/share/fonts/TTF for fontconfig, plus the SIL OFL 1.1 license.
# Source is the notofonts/notofonts.github.io repo at the tagged monthly
# release; files are pulled individually via the jsDelivr CDN (the whole
# release zipball is hundreds of MB, unfit for the dist archive model).
# Downloads happen in PROJECT_CFG_CMDS (into SRC_TREE) and each file's SHA256
# is verified.  No distinfo archive is used.
NAME    := noto-fonts-sans
VERSION := noto-monthly-release-2026.09.01
CATEGORY:= graphics
LICENSE := SIL Open Font License 1.1
DEPENDENCIES:=
BUILD_DEPENDENCIES:=
TARGET  := $(FREELINX_TRIPLE)
PREFIX  := /

include ../../mk/project-port.mk

FONT_PREFIX = $(FREELINX_BUILD_DIR)/deps/$(NAME)
SRC_TREE = $(FREELINX_BUILD_DIR)/work/$(NAME)/files
NOTO_BASE = https://cdn.jsdelivr.net/gh/notofonts/notofonts.github.io@$(VERSION)/fonts/NotoSans/hinted/ttf
OFL_BASE  = https://cdn.jsdelivr.net/gh/google/fonts@main/ofl/notosans

PROJECT_BIN = $(FONT_PREFIX)/usr/share/fonts/TTF/NotoSans-Regular.ttf
BUILD_BIN   = $(PROJECT_BIN)

# No upstream tar archive; create the work tree ourselves.
do-fetch:
	@printf '[FreeLinX/ports] %s: self-fetching fonts (no dist archive)\n' "$(NAME)"

do-extract:
	@mkdir -p "$(SRC_TREE)"

PROJECT_CFG_CMDS = \
	for f in \
		'NotoSans-Regular.ttf 478c558ea716033cd60c03438f628dfa75694dcf6b5f6d505a2f05fd2b4f3823' \
		'NotoSans-Bold.ttf 1df075a380fc7cb898acf64c1f7b3b4dd780de3caa860178bf929de35817a913' \
		'NotoSans-Italic.ttf 467e3f89eeca4108bb8710a2b9e0cf2281ac56d5b0609211a83776d0505eecb5' \
		'NotoSans-BoldItalic.ttf 1b602a9d6353be42c91df097a4857b69fa2696f26703d7a33b54a15d87c2622c'; do \
		set -- $$f; \
		[ -f "$$1" ] || curl -fL -o "$$1" "$(NOTO_BASE)/$$1" || exit 1; \
		h=$$(sha256sum "$$1" | awk '{print $$1}'); \
		[ "$$h" = "$$2" ] || { echo "sha256 mismatch for $$1: got $$h"; exit 1; }; \
	done && \
	{ [ -f OFL.txt ] || curl -fL -o OFL.txt "$(OFL_BASE)/OFL.txt"; } && \
	h=$$(sha256sum OFL.txt | awk '{print $$1}'); \
	[ "$$h" = "cee9892f9f0cc8fe882c9e9537ee6a89621d86ee7ceaf70b02e2b2b1c25c061a" ] || \
		{ echo "sha256 mismatch for OFL.txt: got $$h"; exit 1; }

BUILD_CMDS = \
	mkdir -p "$(FONT_PREFIX)/usr/share/fonts/TTF" && \
	cp "$(SRC_TREE)"/NotoSans-*.ttf "$(FONT_PREFIX)/usr/share/fonts/TTF/" && \
	cp "$(SRC_TREE)/OFL.txt" "$(FONT_PREFIX)/usr/share/fonts/TTF/NOTO-OFL.txt"