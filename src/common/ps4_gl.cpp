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

// Kept apart from ps4.cpp: the system GLES2 header conflicts with glad's declarations.

#include "config.h"

#ifdef LOVE_PS4

#include <GLES2/gl2.h>
#include <EGL/egl.h>
#include <string.h>

#include "ps4.h"

namespace love
{
namespace ps4
{

struct GLEntry
{
	const char *name;
	void *proc;
};

#define ENTRY(f) {#f, (void *) &f},

// Every core OpenGL ES 2.0 entry point, linked directly against libScePigletv2VSH.
static const GLEntry glEntries[] =
{
	ENTRY(glActiveTexture)
	ENTRY(glAttachShader)
	ENTRY(glBindAttribLocation)
	ENTRY(glBindBuffer)
	ENTRY(glBindFramebuffer)
	ENTRY(glBindRenderbuffer)
	ENTRY(glBindTexture)
	ENTRY(glBlendColor)
	ENTRY(glBlendEquation)
	ENTRY(glBlendEquationSeparate)
	ENTRY(glBlendFunc)
	ENTRY(glBlendFuncSeparate)
	ENTRY(glBufferData)
	ENTRY(glBufferSubData)
	ENTRY(glCheckFramebufferStatus)
	ENTRY(glClear)
	ENTRY(glClearColor)
	ENTRY(glClearDepthf)
	ENTRY(glClearStencil)
	ENTRY(glColorMask)
	ENTRY(glCompileShader)
	ENTRY(glCompressedTexImage2D)
	ENTRY(glCompressedTexSubImage2D)
	ENTRY(glCopyTexImage2D)
	ENTRY(glCopyTexSubImage2D)
	ENTRY(glCreateProgram)
	ENTRY(glCreateShader)
	ENTRY(glCullFace)
	ENTRY(glDeleteBuffers)
	ENTRY(glDeleteFramebuffers)
	ENTRY(glDeleteProgram)
	ENTRY(glDeleteRenderbuffers)
	ENTRY(glDeleteShader)
	ENTRY(glDeleteTextures)
	ENTRY(glDepthFunc)
	ENTRY(glDepthMask)
	ENTRY(glDepthRangef)
	ENTRY(glDetachShader)
	ENTRY(glDisable)
	ENTRY(glDisableVertexAttribArray)
	ENTRY(glDrawArrays)
	ENTRY(glDrawElements)
	ENTRY(glEnable)
	ENTRY(glEnableVertexAttribArray)
	ENTRY(glFinish)
	ENTRY(glFlush)
	ENTRY(glFramebufferRenderbuffer)
	ENTRY(glFramebufferTexture2D)
	ENTRY(glFrontFace)
	ENTRY(glGenBuffers)
	ENTRY(glGenFramebuffers)
	ENTRY(glGenRenderbuffers)
	ENTRY(glGenTextures)
	ENTRY(glGenerateMipmap)
	ENTRY(glGetActiveAttrib)
	ENTRY(glGetActiveUniform)
	ENTRY(glGetAttachedShaders)
	ENTRY(glGetAttribLocation)
	ENTRY(glGetBooleanv)
	ENTRY(glGetBufferParameteriv)
	ENTRY(glGetError)
	ENTRY(glGetFloatv)
	ENTRY(glGetFramebufferAttachmentParameteriv)
	ENTRY(glGetIntegerv)
	ENTRY(glGetProgramInfoLog)
	ENTRY(glGetProgramiv)
	ENTRY(glGetRenderbufferParameteriv)
	ENTRY(glGetShaderInfoLog)
	ENTRY(glGetShaderPrecisionFormat)
	ENTRY(glGetShaderSource)
	ENTRY(glGetShaderiv)
	ENTRY(glGetString)
	ENTRY(glGetTexParameterfv)
	ENTRY(glGetTexParameteriv)
	ENTRY(glGetUniformLocation)
	ENTRY(glGetUniformfv)
	ENTRY(glGetUniformiv)
	ENTRY(glGetVertexAttribPointerv)
	ENTRY(glGetVertexAttribfv)
	ENTRY(glGetVertexAttribiv)
	ENTRY(glHint)
	ENTRY(glIsBuffer)
	ENTRY(glIsEnabled)
	ENTRY(glIsFramebuffer)
	ENTRY(glIsProgram)
	ENTRY(glIsRenderbuffer)
	ENTRY(glIsShader)
	ENTRY(glIsTexture)
	ENTRY(glLineWidth)
	ENTRY(glLinkProgram)
	ENTRY(glPixelStorei)
	ENTRY(glPolygonOffset)
	ENTRY(glReadPixels)
	ENTRY(glReleaseShaderCompiler)
	ENTRY(glRenderbufferStorage)
	ENTRY(glSampleCoverage)
	ENTRY(glScissor)
	ENTRY(glShaderBinary)
	ENTRY(glShaderSource)
	ENTRY(glStencilFunc)
	ENTRY(glStencilFuncSeparate)
	ENTRY(glStencilMask)
	ENTRY(glStencilMaskSeparate)
	ENTRY(glStencilOp)
	ENTRY(glStencilOpSeparate)
	ENTRY(glTexImage2D)
	ENTRY(glTexParameterf)
	ENTRY(glTexParameterfv)
	ENTRY(glTexParameteri)
	ENTRY(glTexParameteriv)
	ENTRY(glTexSubImage2D)
	ENTRY(glUniform1f)
	ENTRY(glUniform1fv)
	ENTRY(glUniform1i)
	ENTRY(glUniform1iv)
	ENTRY(glUniform2f)
	ENTRY(glUniform2fv)
	ENTRY(glUniform2i)
	ENTRY(glUniform2iv)
	ENTRY(glUniform3f)
	ENTRY(glUniform3fv)
	ENTRY(glUniform3i)
	ENTRY(glUniform3iv)
	ENTRY(glUniform4f)
	ENTRY(glUniform4fv)
	ENTRY(glUniform4i)
	ENTRY(glUniform4iv)
	ENTRY(glUniformMatrix2fv)
	ENTRY(glUniformMatrix3fv)
	ENTRY(glUniformMatrix4fv)
	ENTRY(glUseProgram)
	ENTRY(glValidateProgram)
	ENTRY(glVertexAttrib1f)
	ENTRY(glVertexAttrib1fv)
	ENTRY(glVertexAttrib2f)
	ENTRY(glVertexAttrib2fv)
	ENTRY(glVertexAttrib3f)
	ENTRY(glVertexAttrib3fv)
	ENTRY(glVertexAttrib4f)
	ENTRY(glVertexAttrib4fv)
	ENTRY(glVertexAttribPointer)
	ENTRY(glViewport)
};

#undef ENTRY

void *getGLProcAddress(const char *name)
{
	for (const GLEntry &e : glEntries)
	{
		if (strcmp(e.name, name) == 0)
			return e.proc;
	}
	return nullptr;
}

void logGraphicsDiagnostics()
{
	EGLint error = eglGetError();
	EGLDisplay display = eglGetDisplay(EGL_DEFAULT_DISPLAY);
	EGLint retryError = eglGetError();
	log("EGL: last error 0x%x; eglGetDisplay retry -> %p (error 0x%x)", error, display, retryError);
	logMemory();
}

} // ps4
} // love

#endif // LOVE_PS4
