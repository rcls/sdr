#include "lib/util.h"

#include <assert.h>
#include <fcntl.h>
#include <fftw3.h>
#include <math.h>
#include <omp.h>
#include <stdarg.h>
#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>

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
    if (strcmp(path, "-") == 0) {
        slurp_file(0, buffer, offset, size);
        return;
    }
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


size_t best_lfsr(const unsigned char * restrict * restrict buffer,
                 size_t num_samples, size_t bytes, int sample_size)
{
    uint32_t run[sample_size];
    const unsigned char * bad[sample_size];
    assert(sample_size <= bytes);
    for (int i = 0; i < sample_size; ++i)
        bad[i] = *buffer + i;

    const unsigned char * best = NULL;
    size_t bestsize = 0;
    int index = 0;
    const unsigned char * end = *buffer + bytes;
    for (const unsigned char * p = *buffer; p != end; ++p) {
        int predicted = __builtin_parity(run[index] & 0x80401020);
        run[index] = run[index] * 2 + !!(*p & 128);
        if (predicted != (run[index] & 1) || run[index] == 0)
            bad[index] = p;
        else if (p - bad[index] >= bestsize) {
            best = bad[index];
            bestsize = p - best;
        }

        if (++index == sample_size)
            index = 0;
    }

    if (bestsize < 64 * sample_size) {
        bytes = 0;
        return 0;
    }

    assert(bestsize % sample_size == 0);

    *buffer = best + 31 * sample_size + 1;
    bestsize -= 63 * sample_size;
    bestsize /= sample_size;
    if (bestsize < num_samples)
        errx(1, "Only got %zi out of required %zi samples.",
             bestsize, num_samples);
    return bestsize;
}


size_t best_flag(const unsigned char * restrict * restrict buffer,
                 size_t num_samples, size_t bytes, int sample_size)
{
    assert(sample_size <= bytes);
    size_t last_bad = sample_size - 1;
    size_t best = last_bad;
    size_t bestsize = 0;
    const unsigned char * p = *buffer;
    for (size_t i = sample_size - 1; i < bytes; i += sample_size)
        if (p[i] & 128)
            last_bad = i;
        else if (i - last_bad > bestsize) {
            best = last_bad;
            bestsize = i - last_bad;
        }

    assert(bestsize % sample_size == 0);
    bestsize = bestsize / sample_size + 1;
    *buffer += best + 1 - sample_size;
    if (bestsize < num_samples)
        errx(1, "Only got %zi out of required %zi samples.",
             bestsize, num_samples);
    return bestsize;
}


// A high pass filter x(t) - 0.5*(x(t-1)+x(t+1) that in the frequency domain
// corresponds to a raised cosine window in the time domain.
// before replaces data[start-1], after replaces data[end].
static void hp_range(float * data, size_t startG, size_t endG,
                     float beforeG, float afterG)
{
#pragma omp parallel
    {
        size_t num = omp_get_thread_num();
        size_t threads = omp_get_num_threads();
        size_t start = startG + (endG - startG) * num / threads;
        size_t end = startG + (endG - startG) * (num + 1) / threads;
        float before = start == startG ? beforeG : data[start - 1];
        float after = end == endG ? afterG : data[end];
#pragma omp barrier
        if (start < end) {
            end -= 1;
            float prev = before;
            for (size_t i = start; i < end; ++i) {
                double this = data[i];
                data[i] = this - 0.5 * (prev + data[i+1]);
                prev = this;
            }
            data[end] = data[end] - 0.5 * (prev + after);
        }
    }
}


void spectrum(const char * path, float * samples, size_t length, bool preserve)
{
    float * data = samples;
    if (preserve)
        data = fftwf_malloc(length * sizeof * data);

    fftwf_plan_with_nthreads(4);
    fftwf_plan plan = fftwf_plan_r2r_1d(
        length, samples, data, FFTW_R2HC, FFTW_ESTIMATE);
    fftwf_execute(plan);
    fftwf_destroy_plan(plan);

    data[0] = 0;                        // Not interesting.

    size_t half = length / 2;
    if (length % 2 == 0) {
        // Leave the constant and last cosine items as is.
        // There are implicitly zeros before and after the sine ranges.
        hp_range(data, 1, half, 0, data[half]);
        hp_range(data, half + 1, length, 0, 0);
    }
    else {
        // The end of the cosine range and the start of the sine range
        // implicitly wrap.
        hp_range(data, 1, half, 0, data[half - 1]);
        hp_range(data, half + 1, length, -data[half + 1], 0);
    }
#pragma omp parallel for
    for (size_t i = 1; i < half; ++i)
        data[i] = data[i] * data[i] + data[length - i] * data[length - i];
    if (length % 2 == 0)
        data[half] = data[half] * data[half];

    dump_path(path, data, half * sizeof (float));

    if (preserve)
        fftwf_free(data);
}
