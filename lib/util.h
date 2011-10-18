#ifndef FM_UTIL_H_
#define FM_UTIL_H_

void exprintf(const char * f, ...) __attribute__(
    (__noreturn__, __format__(__printf__, 1, 2)));

void experror(const char * m) __attribute__((__noreturn__));

void * xmalloc(size_t size) __attribute__((__malloc__, __warn_unused_result__));

void * xrealloc(void * ptr, size_t size)
    __attribute__((__realloc__, __warn_unused_result__));

#endif
