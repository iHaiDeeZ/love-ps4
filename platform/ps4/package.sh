#!/usr/bin/env bash
#
# Assembles an installable PS4 .pkg from a built eboot.bin.
# Usually run through `platform/ps4/build.sh pkg`.
#
#   package.sh <build-dir>
#
# Environment (all optional):
#   LOVE_PS4_GAME      .love file or game folder to bundle (launches straight into it)
#   LOVE_PS4_TITLE     title shown on the home screen   (default: "LÖVE" or the game's name)
#   LOVE_PS4_TITLE_ID  4 letters + 5 digits, unique per app (default: LOVE00000)
#   LOVE_PS4_VERSION   XX.YY                               (default: 01.00)
#   LOVE_PS4_ICON      512x512 PNG                          (default: LÖVE logo)
#   LOVE_PS4_CONTENT_LABEL  16-char A-Z/0-9 part of the content ID (default: from the title)
#   LOVE_PS4_OUT       where to write the .pkg              (default: <build-dir>)
#
# Files in platform/ps4/modules/*.sprx (not in git, see README) are bundled into sce_module/,
# e.g. libScePigletv2VSH.sprx + libSceShaccVSH.sprx for runtime shader compilation.

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD="${1:?usage: package.sh <build-dir>}"
OPENORBIS="${OPENORBIS:-/opt/pacbrew/ps4/openorbis}"
TOOLS="$OPENORBIS/bin/linux"
export DOTNET_SYSTEM_GLOBALIZATION_INVARIANT=1

EBOOT="$BUILD/love/eboot.bin"
[ -f "$EBOOT" ] || { echo "error: $EBOOT not found, run build.sh love first" >&2; exit 1; }

GAME="${LOVE_PS4_GAME:-}"
if [ -n "$GAME" ]; then
	GAME_NAME="$(basename "${GAME%/}" .love)"
	DEFAULT_TITLE="$GAME_NAME"
else
	DEFAULT_TITLE="LÖVE"
fi
TITLE="${LOVE_PS4_TITLE:-$DEFAULT_TITLE}"
TITLE_ID="${LOVE_PS4_TITLE_ID:-LOVE00000}"
VERSION="${LOVE_PS4_VERSION:-01.00}"
ICON="${LOVE_PS4_ICON:-$HERE/sce_sys/icon0.png}"
OUT="${LOVE_PS4_OUT:-$BUILD}"

if ! [[ "$TITLE_ID" =~ ^[A-Z]{4}[0-9]{5}$ ]]; then
	echo "error: LOVE_PS4_TITLE_ID must be 4 uppercase letters followed by 5 digits (got $TITLE_ID)" >&2
	exit 1
fi
if ! [[ "$VERSION" =~ ^[0-9]{2}\.[0-9]{2}$ ]]; then
	echo "error: LOVE_PS4_VERSION must look like 01.00 (got $VERSION)" >&2
	exit 1
fi

# Content ID: IV0000-<TITLE_ID>_00-<16 chars A-Z0-9>
label="$(printf '%s' "${LOVE_PS4_CONTENT_LABEL:-$TITLE}" | sed 's/[Öö]/O/g' | tr '[:lower:]' '[:upper:]' | tr -cd 'A-Z0-9')"
label="$(printf '%-16s' "${label:0:16}" | tr ' ' '0')"
CONTENT_ID="IV0000-${TITLE_ID}_00-${label}"

STAGE="$BUILD/pkg-stage"
rm -rf "$STAGE"
mkdir -p "$STAGE/sce_sys/about" "$STAGE/sce_module"

cp "$EBOOT" "$STAGE/eboot.bin"
cp "$ICON" "$STAGE/sce_sys/icon0.png"
# Stock files shipped with the OpenOrbis samples.
cp "$OPENORBIS/samples/piglet/sce_sys/about/right.sprx" "$STAGE/sce_sys/about/"
cp "$OPENORBIS/samples/piglet/sce_module/"*.prx "$STAGE/sce_module/"

shopt -s nullglob
modules=("$HERE"/modules/*.sprx)
shopt -u nullglob
for m in "${modules[@]}"; do
	echo "bundling module $(basename "$m")"
	cp "$m" "$STAGE/sce_module/"
done

if [ -n "$GAME" ]; then
	if [ -d "$GAME" ]; then
		[ -f "$GAME/main.lua" ] || { echo "error: $GAME has no main.lua" >&2; exit 1; }
		echo "bundling game folder $GAME as game.love"
		(cd "$GAME" && zip -qr -9 "$STAGE/game.love" . -x '.git/*' '.github/*' '*/.DS_Store')
	else
		echo "bundling $GAME as game.love"
		cp "$GAME" "$STAGE/game.love"
	fi
fi

sfo="$STAGE/sce_sys/param.sfo"
"$TOOLS/PkgTool.Core" sfo_new "$sfo"
set_sfo() { "$TOOLS/PkgTool.Core" sfo_setentry "$sfo" "$1" --type "$2" --maxsize "$3" --value "$4" >/dev/null; }
# Launch parameters copied from RetroArch for PS4, which uses Piglet with the same modules. With
# the OpenOrbis sample values (category gd, app type 1, no attributes) the shell's Piglet never
# returned an EGL display on retail hardware.
set_sfo APP_TYPE Integer 4 0
set_sfo APP_VER Utf8 8 "$VERSION"
set_sfo ATTRIBUTE Integer 4 0x20814016
set_sfo ATTRIBUTE2 Integer 4 0x6
set_sfo CATEGORY Utf8 4 gde
set_sfo CONTENT_ID Utf8 48 "$CONTENT_ID"
set_sfo DOWNLOAD_DATA_SIZE Integer 4 0
set_sfo FORMAT Utf8 4 obs
set_sfo SYSTEM_VER Integer 4 0x3fc
set_sfo TITLE Utf8 128 "$TITLE"
set_sfo TITLE_ID Utf8 12 "$TITLE_ID"
set_sfo VERSION Utf8 8 "$VERSION"

(cd "$STAGE" && "$TOOLS/create-gp4" -out pkg.gp4 --content-id="$CONTENT_ID" --path .) >/dev/null
mkdir -p "$OUT"
(cd "$STAGE" && "$TOOLS/PkgTool.Core" pkg_build pkg.gp4 "$OUT") >/dev/null

echo
echo "  title:      $TITLE ($TITLE_ID, v$VERSION)"
echo "  content id: $CONTENT_ID"
echo "  package:    $OUT/$CONTENT_ID.pkg"
