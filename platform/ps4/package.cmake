# Turns the love ELF into a signed-for-homebrew eboot.bin (fake SELF).
# The .pkg itself is assembled by platform/ps4/package.sh, which can also bundle a game.
#
# Same as the toolchain's add_self(), except for the program authority ID (PAID). The system
# Piglet (libScePigletv2VSH, the shell's OpenGL ES) only gives a display to processes with a
# system authority ID: with PacBrew's default 0x3800000000000035, eglGetDisplay returns
# EGL_NO_DISPLAY. 0x3100000000000002 is what RetroArch for PS4 uses with the same modules.

set(LOVE_PS4_PAID "0x3100000000000002" CACHE STRING "Program authority ID of eboot.bin")

set(LOVE_PS4_AUTH_INFO "000000000000000000000000001C004000FF000000000080000000000000000000000000000000000000008000400040000000000000008000000000000000080040FFFF000000F000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000")

add_custom_command(
	OUTPUT "${LOVE_EXE_NAME}.self"
	COMMAND ${CMAKE_COMMAND} -E env "OO_PS4_TOOLCHAIN=${OPENORBIS}" "${OPENORBIS}/bin/create-fself"
		"-in=${LOVE_EXE_NAME}" "-out=${LOVE_EXE_NAME}.oelf" "--eboot" "eboot.bin"
		"--paid" "${LOVE_PS4_PAID}" "--authinfo" "${LOVE_PS4_AUTH_INFO}"
	VERBATIM
	DEPENDS "${LOVE_EXE_NAME}"
)
add_custom_target("${LOVE_EXE_NAME}_self" ALL DEPENDS "${LOVE_EXE_NAME}.self")
