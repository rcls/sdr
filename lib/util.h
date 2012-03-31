#ifndef FM_UTIL_H_
#define FM_UTIL_H_

#include <unistd.h>

void exprintf(const char * f, ...) __attribute__(
    (__noreturn__, __format__(__printf__, 1, 2)));

void experror(const char * m) __attribute__((__noreturn__));

void * xmalloc(size_t size) __attribute__((__malloc__, __warn_unused_result__));

void * xrealloc(void * ptr, size_t size)
    __attribute__((__warn_unused_result__));

inline int checki(int r, const char * w)
{
    if (r < 0)
        experror(w);
    return r;
}

inline ssize_t checkz(ssize_t r, const char * w)
{
    if (r < 0)
        experror(w);
    return r;
}

void slurp_file(int file, unsigned char * * restrict b,
                size_t * restrict offset, size_t * restrict size);

void dump_file(int file, const void * data, size_t len);

// Returns number of samples, update pointer and size.
size_t best30(const unsigned char ** restrict buffer,
              size_t * restrict bytes);
size_t best22(const unsigned char ** restrict buffer,
              size_t * restrict bytes);
size_t best14(const unsigned char ** restrict buffer,
              size_t * restrict bytes);
size_t best36(const unsigned char ** restrict buffer,
              size_t * restrict bytes);

#endif
