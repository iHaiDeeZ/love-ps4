# Turns the love ELF into a signed-for-homebrew eboot.bin (fake SELF).
# The .pkg itself is assembled by platform/ps4/package.sh, which can also bundle a game.

add_self(${LOVE_EXE_NAME})
