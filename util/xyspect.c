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

#define LENGTH (1<<22)
#define FULL_LENGTH (LENGTH + 65536)
#define BUFFER_SIZE (FULL_LENGTH * 4)


static void load_samples(const unsigned char * buffer, complex float * samples)
{
    size_t bytes = BUFFER_SIZE;
    size_t len = best30(&buffer, &bytes);

    if (len < LENGTH)
        errx(1, "Only got %zd wanted %d.\n", len, LENGTH);

    double xx_sum = 0;
    double xx_sum_sq = 0;
    double yy_sum = 0;
    double yy_sum_sq = 0;
#pragma omp parallel for reduction(+:xx_sum, yy_sum, xx_sum_sq, yy_sum_sq)
    for (int i = 0; i < LENGTH; ++i) {
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
            xx_sum / LENGTH + 0.5, yy_sum / LENGTH + 0.5,
            sqrt(LENGTH * xx_sum_sq - xx_sum * xx_sum) / LENGTH,
            sqrt(LENGTH * yy_sum_sq - yy_sum * yy_sum) / LENGTH);
}


int main (int argc, const char ** argv)
{
    if (argc != 3)
        errx(1, "Usage: <freq> <filename>.");

    /* char * dag; */
    /* unsigned freq = strtoul(argv[1], &dag, 0); */
    /* if (*dag) */
    /*     errx(1, "Usage: <freq> <filename>."); */

    // Slurp a truckload of data.
    unsigned char * buffer = usb_slurp_channel(
        BUFFER_SIZE, XMIT_TURBO|XMIT_XY|2, -1, -1);
    usb_close();

    complex float * samples = malloc(LENGTH * sizeof * samples);
    load_samples(buffer, samples);
    free(buffer);

    // Apply a raised cosine transform.
#pragma omp parallel for
    for (int i = 0; i < LENGTH; ++i)
        samples[i] *= 1 - cos(2 * M_PI * i / LENGTH);

    // Take the transform.
    fftwf_init_threads();
    fftwf_plan_with_nthreads(4);

    fftwf_plan plan = fftwf_plan_dft_1d(LENGTH, samples, samples,
                                        FFTW_FORWARD, FFTW_ESTIMATE);
    fftwf_execute(plan);

    // Calculate spectrum.
    float * spectrum = malloc(LENGTH * sizeof * spectrum);
#pragma omp parallel for
    for (int i = 0; i < LENGTH; ++i)
        spectrum[i] = creal(samples[i]) * creal(samples[i])
            +         cimag(samples[i]) * cimag(samples[i]);

    dump_path(argv[2], spectrum, LENGTH * sizeof * spectrum);

    free(samples);
    free(spectrum);

    return 0;
}
