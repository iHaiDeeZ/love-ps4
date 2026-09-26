# LÖVE for PS4

Play [LÖVE](https://love2d.org) games on a PlayStation 4.

LÖVE is a free framework for making 2D games in Lua. This project brings LÖVE 11.4 to PS4 homebrew,
so games made with it can run on your console with a DualShock 4.

Ported to PS4 by **ShiroKlein**. This is an unofficial port and isn't affiliated with the LÖVE team.

## What you need

- A PS4 with homebrew enabled (GoldHEN or similar) so you can install `.pkg` files.
- Two system files, `libScePigletv2VSH.sprx` and `libSceShaccVSH.sprx`, from the 4.74 devkit
  firmware. LÖVE needs them to draw anything. They belong to Sony, so they can't be included here;
  they're the same files RetroArch for PS4 uses.
- A way to copy files to the console, for example GoldHEN's FTP server.

## Installing

1. On the console, create the folder `/data/love/modules/` and copy both `.sprx` files into it.
2. Download the latest `.pkg` from the [Releases](https://github.com/iHaiDeeZ/love-ps4/releases) page:
   - **LÖVE** is the player for your games.
   - **LÖVE PS4 Test** is a small test app. Use it to check that everything works.
3. Install the packages with GoldHEN's Package Installer.
4. Start **LÖVE PS4 Test**. You should see three green "OK" lines, a moving square, and your
   controller's sticks and buttons updating live. Hold **Options** for two seconds to quit.

## Playing a game

LÖVE games come as `.love` files.

1. Rename the game to `game.love`.
2. Copy it to `/data/love/game.love` on the console.
3. Start **LÖVE**.

Without a game, LÖVE shows its "no game" screen with a floating balloon.

Games that were made for PC usually need small changes to work well with a controller and a TV. If
you make games, see [Packaging your own game](#for-game-makers) below.

## Controllers

- Up to 4 DualShock 4 controllers are supported.
- Each controller has to be signed in to a user or a guest; the PS4 asks when you turn a controller
  on. You can add controllers while a game is running.
- The PS and Share buttons are used by the system, not the game.

## Saves and logs

- Game saves are stored in `/data/love/<game name>/`.
- If a game misbehaves, the log is in `/data/love/log.txt`. It's the first thing to check, and the
  file to include when reporting a problem.

## Troubleshooting

| Problem | What to try |
|---|---|
| The app goes straight back to the home screen | Check that both `.sprx` files are in `/data/love/modules/` with exactly those names. |
| Blue screen with an error message | The game hit an error; the message says where. Press **Options** to quit. |
| A controller doesn't respond | Make sure it's signed in to a user or guest. |
| Anything else | Look at `/data/love/log.txt`. |

## For game makers

Your game runs mostly unchanged, with a few PS4 differences:

- The screen is always 1920×1080. Scale your game to `love.graphics.getDimensions()`.
- Use the gamepad functions (`love.gamepadpressed`, `Joystick:isGamepadDown`). There's no keyboard,
  mouse or touch.
- `love.system.getOS()` returns `"PS4"`, so your game can detect the console.

To turn your game into its own installable `.pkg` with its own title and icon, see the
[developer documentation](platform/ps4/README.md). It also covers building LÖVE for PS4 from source.

## Credits and license

- PS4 port: **ShiroKlein**.
- [LÖVE](https://love2d.org) by the LÖVE Development Team, under the zlib license (see
  [license.txt](license.txt)). This repository is a modified version of LÖVE 11.4. The unmodified
  original is the first commit, tagged `upstream-11.4`.
- Built with the open-source [OpenOrbis](https://github.com/OpenOrbis/OpenOrbis-PS4-Toolchain)
  toolchain and [PacBrew](https://github.com/PacBrew/pacbrew-packages) packages. No Sony SDK was used.
