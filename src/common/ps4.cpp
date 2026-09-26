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

#include "ps4.h"

#ifdef LOVE_PS4

#include <SDL.h>

#include <orbis/libkernel.h>
#include <orbis/SystemService.h>
#include <orbis/Sysmodule.h>

extern "C"
{
#include <lua.h>
#include <lauxlib.h>
}

#include <sys/stat.h>
#include <pthread.h>
#include <stdarg.h>
#include <stdio.h>
#include <unistd.h>
#include <stdlib.h>
#include <string.h>
#include <vector>

// libc++abi runs thread_local destructors through __cxa_thread_atexit_impl, which the PS4 libc
// doesn't provide (and create-fself refuses unresolved imports). Keep a per-thread list of
// destructors and run it from a pthread key destructor when the thread exits.
namespace
{

struct ThreadDtor
{
	void (*dtor)(void *);
	void *obj;
	ThreadDtor *next;
};

pthread_key_t threadDtorKey;
pthread_once_t threadDtorOnce = PTHREAD_ONCE_INIT;

void runThreadDtors(void *p)
{
	ThreadDtor *head = (ThreadDtor *) p;
	while (head != nullptr)
	{
		ThreadDtor *next = head->next;
		head->dtor(head->obj);
		free(head);
		head = next;
	}
}

void createThreadDtorKey()
{
	pthread_key_create(&threadDtorKey, runThreadDtors);
}

} // anonymous namespace

extern "C" int __cxa_thread_atexit_impl(void (*dtor)(void *), void *obj, void * /*dso_symbol*/)
{
	pthread_once(&threadDtorOnce, createThreadDtorKey);

	ThreadDtor *entry = (ThreadDtor *) malloc(sizeof(ThreadDtor));
	if (entry == nullptr)
		return -1;

	// Destructors run in reverse order of registration, so push to the front.
	entry->dtor = dtor;
	entry->obj = obj;
	entry->next = (ThreadDtor *) pthread_getspecific(threadDtorKey);
	pthread_setspecific(threadDtorKey, entry);
	return 0;
}

namespace love
{
namespace ps4
{

static FILE *logFile = nullptr;

void log(const char *fmt, ...)
{
	char buffer[1024];
	va_list args;
	va_start(args, fmt);
	vsnprintf(buffer, sizeof(buffer), fmt, args);
	va_end(args);

	// Drop trailing newlines, SDL adds its own.
	size_t len = strlen(buffer);
	while (len > 0 && (buffer[len - 1] == '\n' || buffer[len - 1] == '\r'))
		buffer[--len] = '\0';

	// klog (visible with GoldHEN's klog redirect: nc <ps4-ip> 3232). It doesn't format
	// arguments, so hand it the finished line.
	char line[1100];
	snprintf(line, sizeof(line), "[love] %s\n", buffer);
	sceKernelDebugOutText(0, line);
	if (logFile != nullptr)
		fputs(line, logFile);
}

// System libraries are only usable once their module is loaded; calling into one that isn't
// kills the app with PRX_NOT_RESOLVED_FUNCTION. SDL loads the video, audio and pad ones itself
// when it starts, the rest are loaded here.
static void loadSystemModules()
{
	struct Module
	{
		const char *name;
		bool internal;
		uint32_t id;
	};

	const Module modules[] = {
		{"SystemService", true, ORBIS_SYSMODULE_INTERNAL_SYSTEM_SERVICE}, // exit, before SDL starts
		{"Random", false, ORBIS_SYSMODULE_RANDOM},                        // LuaJIT seeds its PRNG
		{"Net", true, ORBIS_SYSMODULE_INTERNAL_NET},                      // DNS for luasocket/enet
		{"VideoOut", true, ORBIS_SYSMODULE_INTERNAL_VIDEO_OUT},           // Piglet scans out through it
	};

	for (const Module &m : modules)
	{
		int32_t ret = m.internal
			? (int32_t) sceSysmoduleLoadModuleInternal((OrbisSysModuleInternal) m.id)
			: sceSysmoduleLoadModule((OrbisSysModule) m.id);
		if (ret != 0)
			log("loading system module %s failed (0x%08x)", m.name, (unsigned) ret);
	}
}

// Everything also goes to /data/love/log.txt (unbuffered, so it survives a crash), including
// stdout/stderr (Lua's print) and SDL's own log, which covers the Piglet/shader compiler setup.
static void openLog()
{
	mkdir("/data/love", 0777);
	logFile = fopen("/data/love/log.txt", "w");
	if (logFile == nullptr)
		return;

	setvbuf(logFile, nullptr, _IONBF, 0);
	fflush(stdout);
	fflush(stderr);
	dup2(fileno(logFile), STDOUT_FILENO);
	dup2(fileno(logFile), STDERR_FILENO);
	setvbuf(stdout, nullptr, _IONBF, 0);
	setvbuf(stderr, nullptr, _IONBF, 0);
}

static void sdlLogOutput(void * /*userdata*/, int /*category*/, SDL_LogPriority /*priority*/, const char *message)
{
	log("SDL: %s", message);
}

std::string findGame();

// Same output format as Lua's own print (tab-separated tostring of each argument).
static int w_print(lua_State *L)
{
	int n = lua_gettop(L);
	std::string line;
	lua_getglobal(L, "tostring");
	for (int i = 1; i <= n; i++)
	{
		lua_pushvalue(L, -1);
		lua_pushvalue(L, i);
		lua_call(L, 1, 1);
		const char *str = lua_tostring(L, -1);
		if (str == nullptr)
			return luaL_error(L, "'tostring' must return a string to 'print'");
		if (i > 1)
			line += '\t';
		line += str;
		lua_pop(L, 1);
	}
	lua_pop(L, 1);

	// Long output (tracebacks) is split into lines so klog doesn't truncate it.
	size_t start = 0;
	while (start <= line.size())
	{
		size_t end = line.find('\n', start);
		if (end == std::string::npos)
			end = line.size();
		log("%s", line.substr(start, end - start).c_str());
		start = end + 1;
	}
	return 0;
}

void installLuaPrint(lua_State *L)
{
	lua_pushcfunction(L, w_print);
	lua_setglobal(L, "print");
}

static bool fileExists(const std::string &path)
{
	struct stat st;
	return stat(path.c_str(), &st) == 0;
}

// Piglet (OpenGL ES) can only compile GLSL at runtime when the devkit shader compiler module
// is loaded next to a matching Piglet module. SDL loads both from SDL_PS4_PIGLET_MODULES_PATH.
// These are Sony system files and can't be distributed with love; see platform/ps4/README.md.
static void setupPigletModules()
{
	// Diagnostic switch: use the console's own Piglet (no runtime shader compiler) for the
	// bare runtime when this file exists. Shaders won't compile, but it shows whether EGL starts.
	if (fileExists("/data/love/use_system_piglet") && findGame().empty())
	{
		log("use_system_piglet: not loading the shader compiler modules");
		return;
	}

	const char *dirs[] = {
		"/app0/sce_module",               // bundled into the pkg at build time
		"/data/love/modules",             // user-provided, shared by all love games
		"/data/self/system/common/lib",   // same location RetroArch and friends use
	};

	for (const char *dir : dirs)
	{
		std::string d = dir;
		if (fileExists(d + "/libScePigletv2VSH.sprx") && fileExists(d + "/libSceShaccVSH.sprx"))
		{
			log("shader compiler modules found in %s", dir);
			SDL_SetHint(SDL_HINT_PS4_PIGLET_MODULES_PATH, dir);
			return;
		}
	}

	log("libSceShaccVSH.sprx / libScePigletv2VSH.sprx not found: shaders can't be compiled, graphics will fail to start. "
	    "See platform/ps4/README.md.");
}

static void onExit()
{
	// The raw process exit syscall is not allowed for apps; ask the system to close us instead.
	log("exiting");
	sceSystemServiceLoadExec("exit", nullptr);
	for (;;)
		sceKernelUsleep(100000);
}

void logModules()
{
	OrbisKernelModule handles[256];
	size_t count = 0;
	if (sceKernelGetModuleList(handles, 256, &count) != 0)
		return;

	std::string names;
	for (size_t i = 0; i < count; i++)
	{
		OrbisKernelModuleInfo info;
		memset(&info, 0, sizeof(info));
		info.size = sizeof(info);
		if (sceKernelGetModuleInfo(handles[i], &info) == 0)
			names += std::string(i > 0 ? ", " : "") + info.name;
	}
	log("loaded modules (%zu): %s", count, names.c_str());
}

std::string findGame()
{
	const char *candidates[] = {
		"/app0/game.love",
		"/app0/game",
		"/data/love/game.love",
		"/data/love/game",
	};

	for (const char *path : candidates)
	{
		std::string p = path;
		bool isLoveFile = p.size() > 5 && p.compare(p.size() - 5, 5, ".love") == 0;
		if (isLoveFile ? fileExists(p) : fileExists(p + "/main.lua"))
			return p;
	}

	return "";
}

void init(int &argc, char **&argv)
{
	openLog();
	SDL_LogSetOutputFunction(sdlLogOutput, nullptr);
	log("LOVE for PS4 starting");
	loadSystemModules();

	atexit(onExit);
	setupPigletModules();

	// Games that check love._os / love.system.getOS() see "PS4". No window manager: always fullscreen.
	SDL_SetHint(SDL_HINT_VIDEO_MINIMIZE_ON_FOCUS_LOSS, "0");

	if (argc > 1)
		return;

	std::string game = findGame();
	if (game.empty())
	{
		log("no game found, showing the no-game screen");
		return;
	}

	log("game: %s", game.c_str());

	static std::vector<char *> args;
	static std::string gamearg;
	gamearg = game;
	args.clear();
	args.push_back(argc > 0 ? argv[0] : (char *) "/app0/eboot.bin");
	args.push_back(&gamearg[0]);
	args.push_back(nullptr);

	argc = 2;
	argv = args.data();
}

std::string getExecutablePath()
{
	return "/app0/eboot.bin";
}

std::string getAppdataDirectory()
{
	return "/data";
}

void exit(int status)
{
	log("quit (status %d)", status);
	onExit();
}

} // ps4
} // love

#endif // LOVE_PS4
