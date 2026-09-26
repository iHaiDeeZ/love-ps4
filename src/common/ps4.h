/**
 * Copyright (c) 2006-2022 LOVE Development Team
 *
 * This software is provided 'as-is', without any express or implied
 * warranty.  In no event will the authors be held liable for any damages
 * arising from the use of this software.
 *
 * Permission is granted to anyone to use this software for any purpose,
 * including commercial applications, and to alter it and redistribute it
 * freely, subject to the following restrictions:
 *
 * 1. The origin of this software must not be misrepresented; you must not
 *    claim that you wrote the original software. If you use this software
 *    in a product, an acknowledgment in the product documentation would be
 *    appreciated but is not required.
 * 2. Altered source versions must be plainly marked as such, and must not be
 *    misrepresented as being the original software.
 * 3. This notice may not be removed or altered from any source distribution.
 **/

#ifndef LOVE_PS4_H
#define LOVE_PS4_H

#include "config.h"

#ifdef LOVE_PS4

#include <string>

struct lua_State;

namespace love
{
namespace ps4
{

/**
 * Early platform setup, called at the top of main():
 *  - points SDL at the Piglet + shader compiler modules, if they can be found
 *  - makes exit() return to the home screen instead of issuing a blocked syscall
 *  - if no game was passed on the command line, finds one (see findGame) and
 *    appends it to argv.
 **/
void init(int &argc, char **&argv);

/**
 * Where a game is looked for, in order:
 *   /app0/game.love, /app0/game/main.lua (bundled in the pkg)
 *   /data/love/game.love, /data/love/game/main.lua (side-loaded, no repack needed)
 * Returns an empty string if there is none (love then shows its no-game screen).
 **/
std::string findGame();

std::string getExecutablePath();

// Root for save data: /data (saves end up in /data/love/<identity>).
std::string getAppdataDirectory();

// Fallback for GL entry points that SDL_GL_GetProcAddress (eglGetProcAddress) doesn't return.
void *getGLProcAddress(const char *name);

// Logs EGL error state and free memory; called when the window/GL context can't be created.
void logGraphicsDiagnostics();

// Replaces Lua's print with one that writes to the log (stdout goes nowhere on PS4).
void installLuaPrint(lua_State *L);

// Logs the names of all loaded modules.
void logModules();

// Logs free flexible and direct memory.
void logMemory();

// printf-style logging to klog and /data/love/log.txt.
void log(const char *fmt, ...);

// Closes the app and returns to the PS4 home screen. Never returns.
[[noreturn]] void exit(int status);

} // ps4
} // love

#endif // LOVE_PS4

#endif // LOVE_PS4_H
