// Analyse a (250MHz / 80) dump of the multifilter output.

#include <assert.h>
#include <complex.h>
#include <fftw3.h>
#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>

#include "lib/usb.h"
#include "lib/util.h"
#include "lib/registers.h"

static void load_samples(const unsigned char * buffer, complex float * samples,
                         size_t num_samples, size_t bytes)
{
    best_lfsr(&buffer, num_samples, bytes, 4);

    double xx_sum = 0;
    double xx_sum_sq = 0;
    double yy_sum = 0;
    double yy_sum_sq = 0;
#pragma omp parallel for reduction(+:xx_sum, yy_sum, xx_sum_sq, yy_sum_sq)
    for (size_t i = 0; i < num_samples; ++i) {
        const unsigned char * p = buffer + i * 4;
        int xx = p[0] + p[1] * 256;
        int yy = p[2] + p[3] * 256;
        //fprintf(stderr,"%04x %04x\n", xx, yy);
        assert(!(xx & 0x8000));
        xx = (xx & 0x3fff) - (xx & 0x4000);
        yy = (yy & 0x3fff) - (yy & 0x4000);
        samples[i] = xx + 0.5 + (yy + 0.5) * I;
        xx_sum += xx;
        xx_sum_sq += xx * xx;
        yy_sum += yy;
        yy_sum_sq += yy * yy;
    }
    fprintf(stderr, "Mean %f,%f, sd %f,%f\n",
            xx_sum / num_samples + 0.5, yy_sum / num_samples + 0.5,
            sqrt(num_samples * xx_sum_sq - xx_sum * xx_sum) / num_samples,
            sqrt(num_samples * yy_sum_sq - yy_sum * yy_sum) / num_samples);
}


static void load_samples1(const unsigned char * buffer, float * samples,
                          size_t num_samples, size_t bytes)
{
    best_lfsr(&buffer, num_samples, bytes, 4);
    double sum = 0;
    double sum_sq = 0;
#pragma omp parallel for reduction(+:sum, sum_sq)
    for (size_t i = 0; i < num_samples; ++i) {
        const unsigned char * p = buffer + 4 * i;
        int32_t v = p[0] + p[1] * 256 + p[2] * 65536 + (p[3] & 127) * 16777216;
        if (v & 0x40000000)
            v -= 0x80000000;
        samples[i] = v + 0.5;
        sum += v;
        sum_sq += v * (double) v;
    }
    fprintf(stderr, "Mean %f, sd %f\n", sum / num_samples + 0.5,
            sqrt(num_samples * sum_sq - sum * sum) / num_samples);
}


static bool sample_x, sample_y;


static int option(int c)
{
    switch (c) {
    case 'x':
        sample_x = true;
        break;
    case 'y':
        sample_y = true;
        break;
    case 0:
        usb_write_mask(REG_PLL_DECAY,
                       sample_x != sample_y
                       ? sample_x ? REG_XY_SEL_X : REG_XY_SEL_Y
                       : REG_XY_SEL_XY,
                       REG_XY_SEL_MASK);
    default:
        return c;
    }
    return 0;
}


int main (int argc, char * const argv[])
{
    // Slurp a truckload of data.
    size_t num_samples = 22;
    size_t bytes;
    unsigned char * buffer = slurp_getopt(
        argc, argv, SLURP_OPTS "xy", option,
        XMIT_TURBO|XMIT_XY|2, &num_samples, &bytes);
    usb_close();

    if (sample_x != sample_y) {
        float * samples = xmalloc(num_samples * sizeof * samples);
        load_samples1(buffer, samples, num_samples, bytes);
        spectrum (optind < argc ? argv[optind] : NULL,
                  samples, num_samples, false);
        return 0;
    }

    complex float * samples = xmalloc(num_samples * sizeof * samples);

    load_samples(buffer, samples, num_samples, bytes);
    free(buffer);

    // Apply a raised cosine transform.
#pragma omp parallel for
    for (int i = 0; i < num_samples; ++i)
        samples[i] *= 1 - cos(2 * M_PI * i / num_samples);

    // Take the transform.
    fftwf_init_threads();
    fftwf_plan_with_nthreads(4);

    fftwf_plan plan = fftwf_plan_dft_1d(num_samples, samples, samples,
                                        FFTW_FORWARD, FFTW_ESTIMATE);
    fftwf_execute(plan);

    // Calculate spectrum.
    float * spectrum = malloc(num_samples * sizeof * spectrum);
#pragma omp parallel for
    for (int i = 0; i < num_samples; ++i)
        spectrum[i] = creal(samples[i]) * creal(samples[i])
            +         cimag(samples[i]) * cimag(samples[i]);
    free(samples);

    dump_path(optind < argc ? argv[optind] : NULL,
              spectrum, num_samples * sizeof * spectrum);

    free(spectrum);

    return 0;
}
