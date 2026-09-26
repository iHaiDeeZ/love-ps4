# Third-party libraries for the PS4 build.
#
# Libraries PacBrew doesn't provide (or that we need patched) are built by
# platform/ps4/build.sh into LOVE_PS4_PREFIX; everything else comes from the
# ps4-openorbis-portlibs packages in ${OPENORBIS}/usr.

if(NOT LOVE_PS4_PREFIX)
	message(FATAL_ERROR "LOVE_PS4_PREFIX is not set. Build with platform/ps4/build.sh.")
endif()

set(PS4_PORTLIBS ${OPENORBIS}/usr)

message(STATUS "PS4 dependency prefix: ${LOVE_PS4_PREFIX}")

# Our prefix first so our SDL2 build wins over PacBrew's.
set(LOVE_INCLUDE_DIRS
	${LOVE_PS4_PREFIX}/include
	${LOVE_PS4_PREFIX}/include/SDL2
	${LOVE_PS4_PREFIX}/include/luajit-2.1
	${PS4_PORTLIBS}/include
	${PS4_PORTLIBS}/include/freetype2
)

set(LOVE_LUA_LIBRARY ${LOVE_PS4_PREFIX}/lib/libluajit-5.1.a)

set(LOVE_LINK_LIBRARIES
	${LOVE_PS4_PREFIX}/lib/libSDL2.a
	${LOVE_PS4_PREFIX}/lib/libopenal.a
	${LOVE_PS4_PREFIX}/lib/libtheoradec.a
	${LOVE_LUA_LIBRARY}
	${PS4_PORTLIBS}/lib/libfreetype.a
	${PS4_PORTLIBS}/lib/libpng16.a
	${PS4_PORTLIBS}/lib/libbz2.a
	${PS4_PORTLIBS}/lib/libmodplug.a
	${PS4_PORTLIBS}/lib/libvorbisfile.a
	${PS4_PORTLIBS}/lib/libvorbis.a
	${PS4_PORTLIBS}/lib/libogg.a
	${PS4_PORTLIBS}/lib/libz.a
	${PS4_PORTLIBS}/lib/libsamplerate.a
	# System module stubs (from the OpenOrbis toolchain).
	SceSystemService
	SceSysUtil
	SceSysmodule
	SceUserService
	SceAudioOut
	ScePad
	ScePigletv2VSH
	SceVideoOut
	SceRandom
	SceNet
	pthread
	m
)

if(LOVE_MPG123)
	set(LOVE_LINK_LIBRARIES ${LOVE_LINK_LIBRARIES} ${PS4_PORTLIBS}/lib/libmpg123.a)
endif()

# The libc heap can't initialize on retail consoles; route the malloc family to our own
# (src/common/ps4_heap.cpp). ps4.cmake links with ld.lld directly, so these are raw linker flags.
foreach(fn malloc free calloc realloc memalign __memalign)
	string(APPEND CMAKE_EXE_LINKER_FLAGS " --wrap=${fn}")
endforeach()

# Required for enet.
add_definitions(-DHAS_SOCKLEN_T -DHAS_FCNTL)
