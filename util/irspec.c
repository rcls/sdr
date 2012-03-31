// Analyse a (250MHz / 80 / 12) dump of the IR filter output.

#include <assert.h>
#include <fftw3.h>
#include <math.h>
#include <stdint.h>
#include <stdlib.h>
//#include <unistd.h>
#include <fcntl.h>

#include "lib/util.h"

#define LENGTH (1<<22)

static inline int64_t get36(const unsigned char * p)
{
    uint32_t low = p[0] + p[1] * 256 + p[2] * 65536 + p[3] * 16777216;
    int32_t high = p[4];
    if (high >= 8)
        high -= 16;
    return (((int64_t) high) << 32) + low;
}

static void load_samples(double * samples)
{
    unsigned char * buffer = NULL;
    size_t length = 0;
    size_t max_size = 0;
    slurp_file (0, &buffer, &length, &max_size);

    const unsigned char * p = buffer;
    size_t l = best36 (&p, &length);
    assert (l >= LENGTH);

    p += length - 5 * LENGTH;

    for (int i = 0; i < LENGTH; ++i) {
        samples[i] = get36(p + i * 5);
        assert(p[i*5+4] <= 15);
    }

    free (buffer);
}


int main (int argc, const char ** argv)
{
    static double samples[LENGTH];

    load_samples (samples);

    fftw_plan plan = fftw_plan_r2r_1d(
        LENGTH, samples, samples, FFTW_R2HC, FFTW_ESTIMATE);
    fftw_execute(plan);
    fftw_destroy_plan(plan);

    samples[0] = 0;                     // Not interesting.

    for (size_t i = 1; i < LENGTH/2; ++i)
        samples[i] = samples[i] * samples[i]
            + samples[LENGTH - i] * samples[LENGTH - i];

    static float output[LENGTH/2];

    int shift = 0;
    for (size_t len = LENGTH/2; len >= 2048; len /= 2) {
        for (size_t i = 0; i < len; ++i)
            output[i] = samples[i];

        char outpath[20];
        if (shift == 0)
            snprintf(outpath, sizeof(outpath), "util/sir.dat");
        else
            snprintf(outpath, sizeof(outpath), "util/sir.dat.%i", shift);

        int outfile = checki(open(outpath, O_WRONLY|O_CREAT|O_TRUNC, 0666),
                             "opening output");
        dump_file(outfile, output, len * sizeof(float));
        checki(close(outfile), "closing output");

        assert ((len & 1) == 0);
        size_t div = len / 2;
        for (size_t i = 0; i != div; ++i)
            samples[i] = 0.5 * (samples[2*i] + samples[2*i + 1]);
        ++shift;
      }

    return 0;
}