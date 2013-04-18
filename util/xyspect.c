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
    size_t len = best_lfsr(&buffer, bytes, 4);

    if (len < num_samples)
        errx(1, "Only got %zd wanted %zd.\n", len, num_samples);

    double xx_sum = 0;
    double xx_sum_sq = 0;
    double yy_sum = 0;
    double yy_sum_sq = 0;
#pragma omp parallel for reduction(+:xx_sum, yy_sum, xx_sum_sq, yy_sum_sq)
    for (int i = 0; i < num_samples; ++i) {
        const unsigned char * p = buffer + i * 4;
        int xx = p[0] + p[1] * 256;
        int yy = p[2] + p[3] * 256;
        //fprintf(stderr,"%04x %04x\n", xx, yy);
        assert(!(xx & 0x8000));
        xx = (xx & 0x3fff) - (xx & 0x4000);
        yy = (yy & 0x3fff) - (yy & 0x4000);
        samples[i] = yy + 0.5;
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


int main (int argc, char * const argv[])
{
    // Slurp a truckload of data.
    size_t num_samples = 22;
    size_t bytes;
    unsigned char * buffer = slurp_getopt(
        argc, argv, SLURP_OPTS, NULL,
        XMIT_TURBO|XMIT_XY|2, &num_samples, &bytes);
    usb_close();

    complex float * samples = malloc(num_samples * sizeof * samples);
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

    dump_path(optind < argc ? argv[optind] : NULL,
              spectrum, num_samples * sizeof * spectrum);

    free(samples);
    free(spectrum);

    return 0;
}
