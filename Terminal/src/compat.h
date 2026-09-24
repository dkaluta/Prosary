#ifndef PROSARY_COMPAT_H
#define PROSARY_COMPAT_H

/* TinyCC 0.9.28rc (including Alpine 3.23's 20250619 snapshot) declares
 * __WCHAR_TYPE__ as signed int on AArch64 Linux. That contradicts the
 * platform ABI and musl's unsigned wchar_t, so its stddef.h conflicts with
 * wchar.h. Match the ABI before any system header is included. This does
 * not change character width or affect other compilers/architectures. */
#if defined(__TINYC__) && defined(__aarch64__) && defined(__linux__)
#undef __WCHAR_TYPE__
#define __WCHAR_TYPE__ unsigned int
#endif

#endif
