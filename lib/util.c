#include "lib/util.h"

#include <assert.h>
#include <fcntl.h>
#include <fftw3.h>
#include <math.h>
#include <stdarg.h>
#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>

void * xmalloc(size_t size)
{
    void * res = malloc(size);
    if (!res)
        err(1, "malloc");
    return res;
}

void * xrealloc(void * ptr, size_t size)
{
    void * res = realloc(ptr, size);
    if (!res)
        err(1, "realloc");
    return res;
}


void slurp_file(int file, unsigned char * * restrict buffer,
                size_t * restrict offset, size_t * restrict size)
{
    int r;
    do {
        if (*offset >= *size) {
            *size += (*size / 2 & -8192) + 8192;
            *buffer = xrealloc(*buffer, *size);
        }
        r = checkz(read(file, *buffer + *offset, *size - *offset), "read");
        *offset += r;
    }
    while (r);
}


void slurp_path(const char * path, unsigned char * * restrict buffer,
                size_t * restrict offset, size_t * restrict size)
{
    int file = checki(open(path, O_RDONLY), "open");
    slurp_file(file, buffer, offset, size);
    checki(close(file), "close");
}


void dump_file(int file, const void * data, size_t len)
{
    const unsigned char * start = data;
    const unsigned char * end = start + len;
    for (const unsigned char * p = start; p != end;)
        p += checkz(write(file, p, end - p), "writing output");
}


void dump_path(const char * path, const void * data, size_t len)
{
    if (path == NULL) {
        dump_file(1, data, len);        // Assume stdout.
        return;
    }
    int outfile = checki(open(path, O_WRONLY|O_CREAT|O_TRUNC, 0666),
                         "opening output");
    dump_file(outfile, data, len);
    checki(close(outfile), "closing output");
}


size_t best30(const unsigned char ** restrict buffer, size_t * restrict bytes)
{
    uint32_t runA = 0;
    uint32_t runB = 0;
    uint32_t runC = 0;
    uint32_t runD = 0;
    const unsigned char * badA = *buffer;
    const unsigned char * badB = *buffer;
    const unsigned char * badC = *buffer;
    const unsigned char * badD = *buffer;
    const unsigned char * best = *buffer;
    const unsigned char * end = *buffer + *bytes;
    size_t bestsize = 0;
    for (const unsigned char * p = *buffer; p != end; ++p) {
        int predicted = __builtin_parity(runD & 0x80401020);
        uint32_t runZ = runD * 2 + !!(*p & 128);
        const unsigned char * badZ = badD;
        if (runZ != runB || predicted != (runZ & 1))
            badZ = p;
        else if (p - badD >= bestsize) {
            best = badD;
            bestsize = p - badD;
        }

        badD = badA;
        badA = badB;
        badB = badC;
        badC = badZ;
        runD = runA;
        runA = runB;
        runB = runC;
        runC = runZ;
    }

    if (bestsize < 64 * 4) {
        *bytes = 0;
        return 0;
    }

    *buffer = best + 32 * 4 - 3;
    bestsize -= 63 * 4;
    *bytes = bestsize;
    return bestsize / 4;
}


size_t best22(const unsigned char ** restrict buffer, size_t * restrict bytes)
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


size_t best14(const unsigned char ** restrict buffer, size_t * restrict bytes)
{
    uint32_t runA = 0;
    uint32_t runB = 0;
    const unsigned char * badA = *buffer;
    const unsigned char * badB = *buffer;
    const unsigned char * best = *buffer;
    const unsigned char * end = *buffer + *bytes;
    size_t bestsize = 0;
    for (const unsigned char * p = *buffer; p != end; ++p) {
        int predicted = __builtin_parity(runB & 0x80401020);
        int got = !!(*p & 128);
        uint32_t runNext = runB * 2 + got;
        const unsigned char * badNext = badB;
        if (predicted != got)
            badNext = p;
        else if (p - badB >= bestsize) {
            best = badB;
            bestsize = p - badB;
        }

        badB = badA;
        badA = badNext;
        runB = runA;
        runA = runNext;
    }

    if (bestsize < 64 * 2) {
        *bytes = 0;
        return 0;
    }

    *buffer = best + 32 * 2 - 1;
    bestsize -= 63 * 2;
    *bytes = bestsize;
    return bestsize / 2;
}


size_t best36(const unsigned char ** restrict buffer, size_t * restrict bytes)
{
    const unsigned char * best = NULL;
    size_t best_bytes = 0;
    const unsigned char * starts[5] = { NULL, NULL, NULL, NULL, NULL };
    int i = 0;
    const unsigned char * end = *buffer + *bytes;
    for (const unsigned char * p = *buffer + 4; p < end; ++p) {
        if (*p >= 16)
            starts[i] = NULL;
        else if (starts[i] == NULL)
            starts[i] = p;
        else if (p - starts[i] > best_bytes) {
            best = starts[i];
            best_bytes = p - starts[i];
        }

        if (i < 4)
            ++i;
        else
            i = 0;
    }

    if (best_bytes > 0) {
        best_bytes += 5;
        best -= 4;
    }
    assert (best_bytes % 5 == 0);
    *buffer = best;
    *bytes = best_bytes;
    return best_bytes / 5;
}


float * spectrum(const double * samples, size_t length)
{
    double * fft = fftw_malloc(length * sizeof * fft);

    // Apply a window.
    for (size_t i = 0; i != length; ++i)
        fft[i] = samples[i] * (1 - cos(2 * M_PI * i / length));

    fftw_plan_with_nthreads(4);
    fftw_plan plan = fftw_plan_r2r_1d(
        length, fft, fft, FFTW_R2HC, FFTW_ESTIMATE);
    fftw_execute(plan);
    fftw_destroy_plan(plan);

    float * output = xmalloc(length / 2 * sizeof(float));
    output[0] = 0;                      // Not interesting.
    for (size_t i = 1; i * 2 < length; ++i)
        output[i] = fft[i] * fft[i] + fft[length - i] * fft[length - i];
    if (length % 2 == 0)
        output[length / 2] = fft[length / 2] * fft[length / 2];

    fftw_free(fft);
    return output;
}


float * spectrumf(const float * samples, size_t length)
{
    float * fft = fftwf_malloc(length * sizeof * fft);

    // Apply a window.
    for (size_t i = 0; i != length; ++i)
        fft[i] = samples[i] * (1 - cos(2 * M_PI * i / length));

    fftwf_plan_with_nthreads(4);
    fftwf_plan plan = fftwf_plan_r2r_1d(
        length, fft, fft, FFTW_R2HC, FFTW_ESTIMATE);
    fftwf_execute(plan);
    fftwf_destroy_plan(plan);

    float * output = xmalloc(length / 2 * sizeof(float));
    output[0] = 0;                      // Not interesting.
    for (size_t i = 1; i * 2 < length; ++i)
        output[i] = fft[i] * fft[i] + fft[length - i] * fft[length - i];
    if (length % 2 == 0)
        output[length / 2] = fft[length / 2] * fft[length / 2];

    fftwf_free(fft);
    return output;
}
