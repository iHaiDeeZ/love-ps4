# LÖVE for PS4

A port of [LÖVE](https://love2d.org) 11.4 to PS4 homebrew, built with the open-source
[OpenOrbis](https://github.com/OpenOrbis/OpenOrbis-PS4-Toolchain) toolchain (via
[PacBrew](https://github.com/PacBrew/pacbrew-packages)). No Sony SDK is involved.

It runs unmodified LÖVE 11.x games, with the platform differences listed below.

> **Status:** builds and packages. **Not yet tested on real hardware.**

Requirements for running: a PS4 with a homebrew-enabled firmware and GoldHEN (or similar)
to install fake-signed packages.

## What works / what's different on PS4

| | |
|---|---|
| Graphics | OpenGL ES 2.0 via Piglet. **Needs the shader compiler modules**, see below. The window is always fullscreen at the TV resolution (1920×1080); `love.window.setMode` sizes are ignored, and games should scale to `love.graphics.getDimensions()`. |
| Input | Up to 4 DualShock 4 controllers through the gamepad API (`love.gamepadpressed`, `Joystick:isGamepadDown`, …). No keyboard, mouse or touch. |
| Audio | OpenAL Soft on SDL2 audio; Ogg Vorbis, MP3, tracker modules and WAV. |
| Lua | LuaJIT 2.1, **interpreter only**. Consoles don't allow JIT code, so `jit.status()` returns false and `jit.on()` raises an error. The `bit` library and FFI data types (`ffi.new`, `ffi.cast`) are available; `ffi.C` symbol lookup isn't. |
| Filesystem | The game is read from the package (`/app0`). Saves go to `/data/love/<identity>`. |
| Other modules | physics, video (Theora), thread, math, data, image, font, timer, system (`getOS()` returns `"PS4"`), luasocket and enet are all built in. |
| Quitting | `love.event.quit()` returns to the home screen. The error screen quits with Options. |

### Controller mapping

SDL gamepad names, as seen by `love.gamepadpressed(joystick, button)`:

| DualShock 4 | LÖVE |
|---|---|
| Cross / Circle / Square / Triangle | `a` / `b` / `x` / `y` |
| Options | `start` |
| Touchpad click | `back` |
| L1 / R1 | `leftshoulder` / `rightshoulder` |
| L3 / R3 | `leftstick` / `rightstick` |
| D-pad | `dpup` `dpdown` `dpleft` `dpright` |
| Sticks | axes `leftx` `lefty` `rightx` `righty` |
| L2 / R2 | axes `triggerleft` / `triggerright` (0 … 1) |

The Share and PS buttons are reserved by the system.

## Shader compiler modules (required)

LÖVE compiles its GLSL shaders when it starts. Retail PS4 firmware ships Piglet (the OpenGL ES
implementation) **without** its runtime shader compiler, so two modules from the **4.74 devkit**
firmware are needed. These are the same files RetroArch for PS4 uses:

- `libScePigletv2VSH.sprx`
- `libSceShaccVSH.sprx`

They are Sony files and are **not included here**. Obtain them yourself, then either:

- put them in `platform/ps4/modules/` before packaging, and they'll be bundled into the pkg
  (that folder's contents are git-ignored), or
- copy them to the console, into `/data/love/modules/` or `/data/self/system/common/lib/`.

LÖVE looks in `/app0/sce_module`, then `/data/love/modules`, then `/data/self/system/common/lib`.
It logs to klog which one it used. Without the modules, graphics fail to start.

## Building

On Ubuntu (26.04 tested; WSL2 works):

```bash
sudo platform/ps4/setup-toolchain.sh     # once: host tools + PacBrew OpenOrbis toolchain
platform/ps4/build.sh                    # deps + love + pkg
```

`build.sh` steps can be run on their own: `deps`, `love` or `pkg`. The first `deps` run builds
SDL2 (PacBrew's PS4 fork, patched), OpenAL Soft, LuaJIT and the Theora decoder into
`build/ps4/prefix`. Everything else comes from PacBrew's `ps4-openorbis-portlibs`.

Set `LOVE_PS4_BUILD=/some/dir` to build elsewhere. On WSL a Linux-side directory is much faster
than `/mnt/c`.

### Packaging a game

```bash
LOVE_PS4_GAME=path/to/game.love \
LOVE_PS4_TITLE="My Game" LOVE_PS4_TITLE_ID=MYGM00001 LOVE_PS4_VERSION=01.00 \
LOVE_PS4_ICON=path/to/icon0.png \
platform/ps4/build.sh pkg
```

`LOVE_PS4_GAME` can also be a folder with a `main.lua`. Give every game its own `TITLE_ID`:
4 letters plus 5 digits. The icon has to be a 512×512 PNG.

Without `LOVE_PS4_GAME` you get a plain LÖVE runtime. It runs `/data/love/game.love` (or
`/data/love/game/main.lua`) if present, so you can iterate on a game over FTP without
repackaging. Otherwise it shows the no-game screen.

## Debugging

Enable GoldHEN's klog redirect and read the log from your PC:

```bash
nc <ps4-ip> 3232
```

LÖVE's own messages start with `[love]`. Lua `print` output goes there as well.

## Porting notes

All PS4 changes are guarded by `LOVE_PS4`, defined in `src/common/config.h` when compiling with
`__ORBIS__`. The platform glue is in `src/common/ps4.cpp`. `git log` on this repo shows everything
changed relative to the upstream 11.4 import (tag `upstream-11.4`).

Things done differently from other platforms:

- `__cxa_thread_atexit_impl` is implemented in `ps4.cpp`: the PS4 libc lacks it, and
  `create-fself` rejects unresolved imports.
- The Piglet core GLES2 entry points are also available from a static table (`ps4_gl.cpp`),
  since `eglGetProcAddress` isn't required to return them.
- SDL2 is rebuilt from PacBrew's PS4 fork with `patches/sdl2-ps4.patch`, which puts Options on
  `start` (it was swapped with the touchpad) and reports released triggers as 0 from the first
  frame.
