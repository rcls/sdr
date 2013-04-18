#ifndef FM_UTIL_H_
#define FM_UTIL_H_

#include <err.h>
#include <stdbool.h>
#include <unistd.h>


void * xmalloc(size_t size) __attribute__((__malloc__, __warn_unused_result__));

void * xrealloc(void * ptr, size_t size)
    __attribute__((__warn_unused_result__));

inline int checki(int r, const char * w)
{
    if (r < 0)
        err(1, "%s", w);
    return r;
}

inline ssize_t checkz(ssize_t r, const char * w)
{
    if (r < 0)
        err(1, "%s", w);
    return r;
}

void slurp_path(const char * path, unsigned char * * restrict b,
                size_t * restrict offset, size_t * restrict size);
void slurp_file(int file, unsigned char * * restrict b,
                size_t * restrict offset, size_t * restrict size);

void dump_file(int file, const void * data, size_t len);
void dump_path(const char * path, const void * data, size_t len);

// Returns number of samples, update pointer and size.
size_t best_lfsr(const unsigned char * restrict * restrict buffer,
                 size_t bytes, int sample_size);
size_t best_flag(const unsigned char * restrict * restrict buffer,
                 size_t bytes, int sample_size);

void spectrum(const char * path, float * samples, size_t length, bool preserve);

#endif
