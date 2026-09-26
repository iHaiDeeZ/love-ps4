#!/usr/bin/env bash
#
# Builds LÖVE for PS4 (OpenOrbis toolchain via PacBrew).
#
#   platform/ps4/build.sh deps    build third-party libraries not provided by PacBrew
#   platform/ps4/build.sh love    configure + build love (eboot.bin / love.self)
#   platform/ps4/build.sh pkg     build an installable .pkg (optionally with a game, see README)
#   platform/ps4/build.sh all     all of the above (default)
#
# Requirements: pacman packages ps4-openorbis and ps4-openorbis-portlibs from PacBrew,
# plus a host gcc/make/cmake/curl (see README.md).
#
# Environment:
#   LOVE_PS4_BUILD   build directory (default: <repo>/build/ps4)
#   LOVE_PS4_GAME    path to a .love file or game folder to bundle into the pkg (optional)
#   JOBS             parallel jobs (default: nproc)

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
BUILD="${LOVE_PS4_BUILD:-$ROOT/build/ps4}"
SRC="$BUILD/src"
PREFIX="$BUILD/prefix"
JOBS="${JOBS:-$(nproc)}"

OPENORBIS="${OPENORBIS:-/opt/pacbrew/ps4/openorbis}"
if [ ! -f "$OPENORBIS/ps4vars.sh" ]; then
	echo "error: OpenOrbis toolchain not found at $OPENORBIS (install ps4-openorbis from PacBrew)" >&2
	exit 1
fi
# shellcheck disable=SC1091
source "$OPENORBIS/ps4vars.sh"

# The PacBrew clang 12 build links against libxml2.so.2; newer distros only ship libxml2.so.16
# (same C API, no symbol versioning), so give ld.lld a private compat link if needed.
if ldd "$OPENORBIS/bin/ld.lld" | grep -q "libxml2.so.2 => not found"; then
	compat=$(ls /usr/lib/x86_64-linux-gnu/libxml2.so.* 2>/dev/null | grep -E 'libxml2\.so\.[0-9]+$' | head -1)
	if [ -n "$compat" ]; then
		mkdir -p "$BUILD/host-compat"
		ln -sf "$compat" "$BUILD/host-compat/libxml2.so.2"
		export LD_LIBRARY_PATH="$BUILD/host-compat${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
	fi
fi

# Our own prefix comes first so our SDL2 build wins over PacBrew's.
export PKG_CONFIG_PATH="$PREFIX/lib/pkgconfig:$PKG_CONFIG_PATH"
export PKG_CONFIG_SYSROOT_DIR=""

# CMake with the OpenOrbis toolchain file. ps4vars.sh also exports CFLAGS/CXXFLAGS/LDFLAGS for
# makefile projects; CMake would prepend those to the toolchain's own flags, and the exported
# CXXFLAGS put the libc++ headers behind the C headers (breaks <cmath>). So clear them here and
# pass per-project extras through EXTRA_CFLAGS / EXTRA_CXXFLAGS instead.
ps4_cmake() {
	env -u CFLAGS -u CXXFLAGS -u CPPFLAGS -u LDFLAGS -u LIBS \
		CFLAGS="${EXTRA_CFLAGS:-}" CXXFLAGS="${EXTRA_CXXFLAGS:-}" \
		cmake -DCMAKE_TOOLCHAIN_FILE="$OPENORBIS/cmake/ps4.cmake" \
		-DCMAKE_BUILD_TYPE=Release \
		-DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
		-DCMAKE_INSTALL_PREFIX="$PREFIX" \
		-DCMAKE_PREFIX_PATH="$PREFIX" \
		-DCMAKE_FIND_ROOT_PATH="$PREFIX;$OPENORBIS;$OPENORBIS/usr" \
		"$@"
}

# Pinned dependency versions.
SDL2_COMMIT=bf797a5315c7dbc0757d8ae7228e2dff1bf370cb   # PacBrew/SDL, same as ps4-openorbis-sdl2 2.0.18
OPENAL_VERSION=1.21.1
LUAJIT_COMMIT=v2.1
THEORA_VERSION=1.1.1

mkdir -p "$SRC" "$PREFIX"

log() { printf '\n\033[1;34m==> %s\033[0m\n' "$*"; }

fetch() { # url dest-archive dir-inside-archive target-dir
	local url="$1" archive="$SRC/$2" inner="$3" dir="$SRC/$4"
	[ -d "$dir" ] && return
	[ -f "$archive" ] || curl -fsSL -o "$archive" "$url"
	tar -C "$SRC" -xf "$archive"
	[ "$SRC/$inner" != "$dir" ] && mv "$SRC/$inner" "$dir"
	return 0
}

stamp() { [ -f "$BUILD/.stamp-$1" ]; }
mark() { touch "$BUILD/.stamp-$1"; }

build_sdl2() {
	stamp sdl2 && return
	log "SDL2 (PacBrew PS4 fork $SDL2_COMMIT)"
	fetch "https://github.com/PacBrew/SDL/archive/$SDL2_COMMIT.tar.gz" sdl2.tar.gz "SDL-$SDL2_COMMIT" sdl2
	if [ ! -f "$SRC/sdl2/.patched" ]; then
		patch -d "$SRC/sdl2" -Np1 -i "$HERE/patches/sdl2-ps4.patch"
		touch "$SRC/sdl2/.patched"
	fi
	ps4_cmake -S "$SRC/sdl2" -B "$BUILD/sdl2" -G "Unix Makefiles" >/dev/null
	make -C "$BUILD/sdl2" -j"$JOBS" --quiet
	make -C "$BUILD/sdl2" install >/dev/null
	mark sdl2
}

build_openal() {
	stamp openal && return
	log "OpenAL Soft $OPENAL_VERSION (SDL2 backend)"
	fetch "https://github.com/kcat/openal-soft/archive/refs/tags/$OPENAL_VERSION.tar.gz" \
		openal-soft.tar.gz "openal-soft-$OPENAL_VERSION" openal-soft
	if [ -f "$HERE/patches/openal-soft-ps4.patch" ] && [ ! -f "$SRC/openal-soft/.patched" ]; then
		patch -d "$SRC/openal-soft" -Np1 -i "$HERE/patches/openal-soft-ps4.patch"
		touch "$SRC/openal-soft/.patched"
	fi
	# This libc++ has no float overloads of std::sin & co, which trips -Wc++11-narrowing.
	EXTRA_CXXFLAGS="-Wno-c++11-narrowing -I$PREFIX/include" \
	ps4_cmake -S "$SRC/openal-soft" -B "$BUILD/openal-soft" -G "Unix Makefiles" \
		-DLIBTYPE=STATIC \
		-DALSOFT_UTILS=OFF -DALSOFT_EXAMPLES=OFF -DALSOFT_INSTALL_EXAMPLES=OFF -DALSOFT_INSTALL_UTILS=OFF \
		-DALSOFT_INSTALL_CONFIG=OFF -DALSOFT_INSTALL_HRTF_DATA=OFF -DALSOFT_INSTALL_AMBDEC_PRESETS=OFF \
		-DALSOFT_EMBED_HRTF_DATA=OFF \
		-DALSOFT_NO_CONFIG_UTIL=ON \
		-DALSOFT_BACKEND_SDL2=ON -DALSOFT_REQUIRE_SDL2=ON \
		-DALSOFT_BACKEND_ALSA=OFF -DALSOFT_BACKEND_OSS=OFF -DALSOFT_BACKEND_PULSEAUDIO=OFF \
		-DALSOFT_BACKEND_JACK=OFF -DALSOFT_BACKEND_PORTAUDIO=OFF -DALSOFT_BACKEND_SNDIO=OFF \
		-DALSOFT_BACKEND_SOLARIS=OFF -DALSOFT_BACKEND_WAVE=OFF -DALSOFT_BACKEND_OPENSL=OFF \
		-DALSOFT_BACKEND_OBOE=OFF -DALSOFT_BACKEND_PIPEWIRE=OFF \
		-DSDL2_DIR="$PREFIX/lib/cmake/SDL2" >/dev/null
	make -C "$BUILD/openal-soft" -j"$JOBS" --quiet 2>&1 | grep -E "error|Error" || true
	test -f "$BUILD/openal-soft/libopenal.a"
	make -C "$BUILD/openal-soft" install >/dev/null
	mark openal
}

build_luajit() {
	stamp luajit && return
	log "LuaJIT $LUAJIT_COMMIT (interpreter only, official PS4 target)"
	fetch "https://github.com/LuaJIT/LuaJIT/archive/refs/heads/$LUAJIT_COMMIT.tar.gz" \
		luajit.tar.gz "LuaJIT-${LUAJIT_COMMIT#v}" luajit
	# Same configuration as LuaJIT's own src/ps4build.bat, minus the FFI restriction.
	local xcflags="-DLUAJIT_DISABLE_JIT -DLUAJIT_USE_SYSMALLOC -DLUAJIT_NO_UNWIND"
	# LuaJIT also builds host tools (minilua, buildvm), so keep the target flags out of the environment.
	local target_flags="$CFLAGS"
	local ljmake=(env -u CFLAGS -u CXXFLAGS -u CPPFLAGS -u LDFLAGS -u LIBS
		make -C "$SRC/luajit/src"
		HOST_CC="gcc" CC="$CC" TARGET_AR="$AR rcus" TARGET_STRIP="$STRIP"
		TARGET_SYS=Other BUILDMODE=static
		TARGET_FLAGS="$target_flags" XCFLAGS="$xcflags")
	"${ljmake[@]}" clean >/dev/null
	"${ljmake[@]}" -j"$JOBS" libluajit.a >/dev/null
	mkdir -p "$PREFIX/include/luajit-2.1" "$PREFIX/lib/pkgconfig"
	cp "$SRC/luajit/src/libluajit.a" "$PREFIX/lib/libluajit-5.1.a"
	cp "$SRC/luajit/src/"{lua.h,luaconf.h,lualib.h,lauxlib.h,lua.hpp,luajit.h} "$PREFIX/include/luajit-2.1/"
	cat > "$PREFIX/lib/pkgconfig/luajit.pc" <<-EOPC
		prefix=$PREFIX
		Name: LuaJIT
		Description: Just-in-time compiler for Lua (interpreter only on PS4)
		Version: 2.1.0
		Libs: -L\${prefix}/lib -lluajit-5.1 -lSceRandom
		Cflags: -I\${prefix}/include/luajit-2.1
	EOPC
	mark luajit
}

build_theora() {
	stamp theora && return
	log "libtheora $THEORA_VERSION"
	fetch "https://downloads.xiph.org/releases/theora/libtheora-$THEORA_VERSION.tar.gz" \
		theora.tar.gz "libtheora-$THEORA_VERSION" theora
	# Only the decoder is needed (love.video). Its 2009 autotools setup can't cross-link test
	# programs for this target, so compile the decoder sources directly (portable C, no asm).
	local sources="apiwrapper bitpack decapiwrapper decinfo decode dequant fragment huffdec idct info internal quant state"
	rm -rf "$BUILD/theora" && mkdir -p "$BUILD/theora"
	for f in $sources; do
		"$CC" $CFLAGS -w -I"$SRC/theora/include" -c "$SRC/theora/lib/$f.c" -o "$BUILD/theora/$f.o" &
	done
	wait
	"$AR" rcs "$BUILD/theora/libtheoradec.a" "$BUILD/theora/"*.o
	mkdir -p "$PREFIX/include/theora" "$PREFIX/lib"
	cp "$BUILD/theora/libtheoradec.a" "$PREFIX/lib/"
	cp "$SRC/theora/include/theora/"*.h "$PREFIX/include/theora/"
	mark theora
}

build_deps() {
	build_sdl2
	build_openal
	build_luajit
	build_theora
}

build_love() {
	log "LÖVE"
	ps4_cmake -S "$ROOT" -B "$BUILD/love" -G "Unix Makefiles" \
		-DLOVE_PS4_PREFIX="$PREFIX" >/dev/null
	make -C "$BUILD/love" -j"$JOBS"
}

build_pkg() {
	log "Package"
	"$HERE/package.sh" "$BUILD"
}

case "${1:-all}" in
	deps) build_deps ;;
	love) build_love ;;
	pkg) build_pkg ;;
	all) build_deps; build_love; build_pkg ;;
	*) echo "usage: $0 [deps|love|pkg|all]" >&2; exit 1 ;;
esac
