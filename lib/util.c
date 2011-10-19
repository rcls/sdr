#include "lib/util.h"

#include <stdarg.h>
#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>

void exprintf(const char * f, ...)
{
    va_list args;
    va_start(args, f);
    vfprintf(stderr, f, args);
    va_end(args);
    exit(EXIT_FAILURE);
}

void experror(const char * m)
{
    perror(m);
    exit(EXIT_FAILURE);
}

void * xmalloc(size_t size)
{
    void * res = malloc(size);
    if (!res)
        experror("malloc");
    return res;
}

void * xrealloc(void * ptr, size_t size)
{
    void * res = realloc(ptr, size);
    if (!res)
        experror("realloc");
    return res;
}


void slurp_file(int file, unsigned char * * restrict buffer,
                size_t * restrict offset, size_t * restrict size)
{
    int r;
    do {
        if (*offset == *size) {
            *size += (*size / 2 & -8192) + 8192;
            *buffer = xrealloc(*buffer, *size);
        }
        r = checkz(read(file, *buffer + *offset, *size - *offset), "read");
        *offset += r;
    }
    while (r);
}


size_t best22(const unsigned char ** restrict buffer,
              size_t * restrict bytes)
{
    uint32_t runA = 0;
    uint32_t runB = 0;
    uint32_t runC = 0;
    const unsigned char * badA = *buffer;
    const unsigned char * badB = *buffer;
    const unsigned char * badC = *buffer;
    const unsigned char * best = *buffer;
    const unsigned char * end = *buffer + *bytes;
    size_t bestsize = 0;
    for (const unsigned char * p = *buffer; p != end; ++p) {
        int predicted = __builtin_parity(runC & 0x80401020);
        uint32_t nextC = runC * 2 + (*p & 1);
        const unsigned char * nbC = badC;
        if ((nextC & ~runB) || (runA & ~nextC) || predicted != (nextC & 1))
            nbC = p;
        else if (p - badC >= bestsize) {
            best = badC;
            bestsize = p - badC;
        }

        badC = badA;
        badA = badB;
        badB = nbC;
        runC = runA;
        runA = runB;
        runB = nextC;
    }

    if (bestsize < 64 * 3) {
        *bytes = 0;
        return 0;
    }

    *buffer = best + 32 * 3 - 2;
    bestsize -= 63 * 3;
    *bytes = bestsize;
    return bestsize / 3;
}
