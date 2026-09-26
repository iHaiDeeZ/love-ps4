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

/**
 * The C heap for PS4.
 *
 * The OpenOrbis libc creates its heap lazily on the first malloc by reserving 2.5 GiB and
 * mapping it as *system* flexible memory. When that mapping fails (it does on retail consoles),
 * malloc falls through to sceLibcMspaceMalloc(NULL, ...) and crashes at address 0x38 - which
 * happens in the very first C++ static constructor that allocates, before main().
 *
 * So the malloc family is redirected here with the linker's --wrap (see
 * platform/ps4/dependencies.cmake). The heap is an mspace over regular flexible memory, sized
 * from what the process can actually get, and created on the first allocation.
 **/

#include "config.h"

#ifdef LOVE_PS4

#include <stddef.h>
#include <stdint.h>
#include <stdio.h>

// Declared by hand: the toolchain headers give these the wrong (or no) prototypes.
extern "C"
{
int32_t sceKernelDebugOutText(int32_t channel, const char *fmt, ...);
int32_t sceKernelAvailableFlexibleMemorySize(size_t *size);
int32_t sceKernelReserveVirtualRange(void **addr, size_t len, int32_t flags, size_t alignment);
int32_t sceKernelMapNamedFlexibleMemory(void **addr, size_t len, int32_t prot, int32_t flags, const char *name);
int32_t sceKernelMapNamedSystemFlexibleMemory(void **addr, size_t len, int32_t prot, int32_t flags, const char *name);
size_t sceKernelGetDirectMemorySize(void);
int32_t sceKernelAvailableDirectMemorySize(int64_t start, int64_t end, size_t alignment, int64_t *startOut, size_t *sizeOut);

void *sceLibcMspaceCreate(const char *name, void *base, size_t capacity, unsigned int flags);
void *sceLibcMspaceMalloc(void *msp, size_t size);
void sceLibcMspaceFree(void *msp, void *ptr);
void *sceLibcMspaceCalloc(void *msp, size_t nelem, size_t size);
void *sceLibcMspaceRealloc(void *msp, void *ptr, size_t size);
void *sceLibcMspaceMemalign(void *msp, size_t alignment, size_t size);
}

namespace
{

const size_t MB = 1024 * 1024;

// sceKernelDebugOutText doesn't format its arguments, so format here (snprintf doesn't allocate).
template <typename... Args>
void heapLog(const char *fmt, Args... args)
{
	char line[256];
	snprintf(line, sizeof(line), fmt, args...);
	sceKernelDebugOutText(0, line);
}
const size_t PAGE = 16 * 1024;

// When the heap has to come out of the app's regular flexible memory, leave this much for Piglet
// (OpenGL ES): SDL configures it with 256 MiB of shared system memory plus command buffers, and
// with 256 MiB left eglGetDisplay still failed on hardware.
const size_t RESERVE_FOR_SYSTEM = 320 * MB;

const int32_t PROT_CPU_RW = 0x3;
const int32_t MAP_FIXED_FLAG = 0x10;

void *heap = nullptr;

void *mapAndCreate(bool systemPool, size_t size)
{
	void *base = nullptr;
	if (sceKernelReserveVirtualRange(&base, size, 0, PAGE) != 0)
		return nullptr;

	int32_t ret = systemPool
		? sceKernelMapNamedSystemFlexibleMemory(&base, size, PROT_CPU_RW, MAP_FIXED_FLAG, "love heap")
		: sceKernelMapNamedFlexibleMemory(&base, size, PROT_CPU_RW, MAP_FIXED_FLAG, "love heap");
	if (ret != 0)
	{
		// The leaked VA reservation doesn't matter in a 47-bit address space.
		heapLog("[love] heap: mapping %zu MiB of %s flexible memory failed (0x%x)\n",
			size / MB, systemPool ? "system" : "regular", ret);
		return nullptr;
	}

	void *msp = sceLibcMspaceCreate("love heap", base, size, 0);
	if (msp != nullptr)
		heapLog("[love] heap: %zu MiB of %s flexible memory at %p\n", size / MB, systemPool ? "system" : "regular", base);
	return msp;
}

void *createHeap()
{
	size_t available = 0;
	int32_t ret = sceKernelAvailableFlexibleMemorySize(&available);
	heapLog("[love] heap: available flexible memory: %zu MiB (ret 0x%x)\n", available / MB, ret);

	// Preferred: the system flexible memory pool, like the libc heap (which asks for an
	// impossible 2.5 GiB). That leaves all of the regular flexible memory to Piglet.
	const size_t systemSizes[] = {1024 * MB, 768 * MB, 512 * MB, 384 * MB, 256 * MB, 192 * MB, 128 * MB};
	for (size_t size : systemSizes)
	{
		if (void *msp = mapAndCreate(true, size))
			return msp;
	}

	// Fallback: regular flexible memory, keeping enough back for Piglet.
	size_t size = 0;
	if (ret == 0 && available > RESERVE_FOR_SYSTEM + 32 * MB)
		size = (available - RESERVE_FOR_SYSTEM) & ~(PAGE - 1);
	for (; size >= 32 * MB; size = (size / 2) & ~(PAGE - 1))
	{
		if (void *msp = mapAndCreate(false, size))
			return msp;
	}

	heapLog("[love] heap: could not create a heap, out of memory\n");
	return nullptr;
}

inline void *getHeap()
{
	// The first allocation happens in a static constructor, before any threads exist.
	if (heap == nullptr)
		heap = createHeap();
	return heap;
}

} // anonymous namespace

namespace love
{
namespace ps4
{

void log(const char *fmt, ...);

void logMemory()
{
	size_t flexible = 0;
	sceKernelAvailableFlexibleMemorySize(&flexible);
	int64_t directStart = 0;
	size_t directFree = 0;
	size_t directTotal = sceKernelGetDirectMemorySize();
	sceKernelAvailableDirectMemorySize(0, (int64_t) directTotal, 0, &directStart, &directFree);
	log("memory: flexible available %zu MiB; direct %zu MiB total, largest free block %zu MiB",
		flexible / MB, directTotal / MB, directFree / MB);
}

} // ps4
} // love

extern "C"
{

void *__wrap_malloc(size_t size)
{
	return sceLibcMspaceMalloc(getHeap(), size);
}

void __wrap_free(void *ptr)
{
	if (ptr != nullptr)
		sceLibcMspaceFree(getHeap(), ptr);
}

void *__wrap_calloc(size_t nelem, size_t size)
{
	return sceLibcMspaceCalloc(getHeap(), nelem, size);
}

void *__wrap_realloc(void *ptr, size_t size)
{
	if (ptr == nullptr)
		return sceLibcMspaceMalloc(getHeap(), size);
	if (size == 0)
	{
		sceLibcMspaceFree(getHeap(), ptr);
		return nullptr;
	}
	return sceLibcMspaceRealloc(getHeap(), ptr, size);
}

void *__wrap_memalign(size_t alignment, size_t size)
{
	return sceLibcMspaceMemalign(getHeap(), alignment, size);
}

// posix_memalign and aligned_alloc in libc.a are built on __memalign.
void *__wrap___memalign(size_t alignment, size_t size)
{
	return sceLibcMspaceMemalign(getHeap(), alignment, size);
}

} // extern "C"

#endif // LOVE_PS4
