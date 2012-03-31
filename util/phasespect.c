// Analyse a (250MHz / 240) dump of the phase detector output.

#include <assert.h>
#include <fftw3.h>
#include <math.h>
#include <stdlib.h>
//#include <unistd.h>
#include <fcntl.h>

#include "lib/util.h"

#define LENGTH (1<<22)

static inline unsigned get24(const unsigned char * p)
{
    return p[0] + p[1] * 256 + p[2] * 65536;
}

static void load_samples(double * samples)
{
    unsigned char * buffer = NULL;
    size_t length = 0;
    size_t max_size = 0;
    slurp_file (0, &buffer, &length, &max_size);

    size_t best_l = 0;
    size_t best_o = 0;
    for (size_t i = 0; i != 3; ++i) {
        ssize_t good = -1;
        for (size_t j = i; j + 3 <= length; j += 3) {
            if (buffer[j + 2] >= 4) {
                good = -1;
                continue;
            }
            if (good < 0)
                good = j;
            size_t l = j - good + 3;
            if (l > best_l) {
                best_o = good;
                best_l = l;
            }
        }
    }

    assert (best_l % 3 == 0);
    const unsigned char * array = buffer + best_o;
    length = best_l / 3;

    fprintf (stderr, "Best block is length %zu (%zu bytes) at offset %zu\n",
             length, best_l, best_o);
    assert (best_l >= 3 * LENGTH + 3);

    for (unsigned i = 0; i < LENGTH; ++i) {
        int diff = get24(array + i*3 + 3) - get24(array + i*3);
        diff &= 0x3ffff;
        if (diff > 0x20000)
            diff -= 0x40000;
        samples[i] = diff;
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
            snprintf(outpath, sizeof(outpath), "util/sfm.dat");
        else
            snprintf(outpath, sizeof(outpath), "util/sfm.dat.%i", shift);

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