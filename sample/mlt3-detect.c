#include <assert.h>
#include <complex.h>
#include <err.h>
#include <fftw3.h>
#include <math.h>
#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#include "lib/legendre.h"
#include "lib/usb.h"
#include "lib/util.h"
#include "lib/registers.h"

static size_t SIZE = 1<<23;

// Time domain length of filter.
#define FILTER_WIDTH 16384
//#define FILTER_WIDTH 128

// Width of image (image is doubled & is actually twice this).
#define I_WIDTH 600
// Height of image
#define I_HEIGHT 1000

#define SAMPLE_BITS 15
#define SAMPLE_RANGE (1 << SAMPLE_BITS)

#define UNLIKELY(b) __builtin_expect(b, 0)

static const char * inpath;
static const char * dumppath;
static const char * outpath;
static const char * jitterpath;
static int period = 205;
static int wander_decay = -1;

static void fftf_once(fftwf_plan plan)
{
    fftwf_execute(plan);
    fftwf_destroy_plan(plan);
}


static inline double square(double x)
{
    return x * x;
}


// Produce a non-linear transformation for clock recovery.  We use a W shaped
// function based on the quartiles.
static float * rectify(const unsigned short * restrict in, size_t size)
{
    int counts[SAMPLE_RANGE];
    memset(counts, 0, sizeof(counts));
#pragma omp parallel for
    for (int i = 0; i < size; ++i)
#pragma omp atomic
        counts[in[i]]++;

    int x = 0;
    double quart1 = 0;
    double middle = 0;
    double quart3 = 0;
    for (int i = 0; i != SAMPLE_RANGE; ++i) {
        int xx = x + counts[i];
        if (x < size / 4 && xx >= size / 4)
            quart1 = i - (xx - size * 0.25) / (xx - x);
        if (x < size / 2 && xx >= size / 2)
            middle = i - (xx - size * 0.5) / (xx - x);
        if (x < 3 * size / 4 && xx >= 3 * size / 4)
            quart3 = i - (xx - size * 0.75) / (xx - x);
        x = xx;
    }

    fprintf(stderr, "Quartiles : %f %f %f\n", quart1, middle, quart3);

    float * out = fftwf_malloc(size * sizeof * out);
#pragma omp parallel for
    for (int i = 0; i < size; ++i) {
        int d = in[i];
        if (d < middle)
            out[i] = fabs(quart1 - d);
        else
            out[i] = fabs(d - quart3);
    }

    return out;
}


// Given the rectified data, find the peak power.  Transforms out.
static size_t peak_power(float * restrict out, size_t size)
{
    fprintf(stderr, "Running phase detect fft...");

    fftf_once(fftwf_plan_r2r_1d(size, out, out, FFTW_R2HC, FFTW_ESTIMATE));
    fprintf(stderr, "\n");

    double max_power = 0;
    size_t peak_index = 0;
    const size_t HALF = size / 2;
#pragma omp parallel for
    for (size_t i = 2; i < HALF - 2; ++i) {
        double power = square(out[i] - 0.5 * (out[i-1] + out[i+1]))
            + square(out[size-i] - 0.5 * (out[size-i-1] + out[size-i+1]));
        if (UNLIKELY(power > max_power))
#pragma omp critical(max_power)
            if (power > max_power) {
                max_power = power;
                peak_index = i;
            }
    }

    fprintf(stderr, "Peak at %zi, %f Hz\n",
            peak_index, peak_index * 1e9 / period / size);

    return peak_index;
}


// data should be the frequency domain data.  We apply a filter and map to
// phases.
static void phase_recover(float * restrict data, size_t size, size_t peak_index)
{
    const size_t HALF = size / 2;
    const size_t START = FILTER_WIDTH;
    const size_t END = size - FILTER_WIDTH;

    if (peak_index <= size / FILTER_WIDTH
        || peak_index >= HALF - size / FILTER_WIDTH) {
        fprintf(stderr, "Too close to end.\n");
        exit(EXIT_FAILURE);
    }

    // Doing a full size fft & then the regression on full time resolution is
    // a bit silly...  But CPU cycles are cheap.
    fprintf(stderr, "Construct filter...\n");
    complex float * filtered = fftwf_malloc (size * sizeof * filtered);
    fftwf_plan plan = fftwf_plan_dft_1d(size, filtered, filtered,
                                        FFTW_BACKWARD, FFTW_ESTIMATE);
    // First generate the filter spectrum.  Full complex instead of real
    // symmetric FFT.  Again, waste waste waste.
    filtered[0] = M_PI / FILTER_WIDTH;
    for (size_t i = 1; i < FILTER_WIDTH; ++i)
        filtered[i] = filtered[size - i] = sin(i * (M_PI / FILTER_WIDTH)) / i;
    for (size_t i = FILTER_WIDTH; i < size - FILTER_WIDTH; ++i)
        filtered[i] = 0;
    fprintf(stderr, "Filter gen...");
    fftwf_execute(plan);

    // Do the filtering in frequency domain.
    fprintf(stderr, "\nFiltering...");
#pragma omp parallel for
    for (size_t i = 1; i < peak_index; ++i)
        filtered[size - peak_index + i] *= data[i] + I * data[size - i];
#pragma omp parallel for
    for (size_t i = peak_index; i < HALF; ++i)
        filtered[i - peak_index] *= data[i] + I * data[size - i];
#pragma omp parallel for
    for (size_t i = HALF - peak_index; i <= size - peak_index; ++i)
        filtered[i] = 0;

    // Back to time domain.
    fprintf(stderr, "\nBack to time...");
    fftwf_execute(plan);
    fftwf_destroy_plan(plan);
    fprintf(stderr, "\n");

    // Transform to phases...
#pragma omp parallel for
    for (size_t i = START; i < END; ++i)
        data[i] = carg(filtered[i]);

    fftwf_free(filtered);
}


// Map [0..1] to [0..1] but with smooth ends.
static double coramp(double x)
{
    return 0.5 - 0.5 * cos(M_PI * x);
}


static void create_image(FILE * outfile,
                         const unsigned short * restrict in,
                         const float * restrict phase,
                         size_t size, size_t peak_index, int sample_limit)
{
    //const size_t HALF = size / 2;
    const size_t START = FILTER_WIDTH;
    const size_t END = size - FILTER_WIDTH;

    fprintf(stderr, "Phase detection done, create image.\n");

    float (*counts)[I_WIDTH] = fftwf_malloc(
        sizeof(float) * sample_limit * I_WIDTH);
    memset(counts, 0, sizeof(float) * sample_limit * I_WIDTH);
#pragma omp parallel for
    for (size_t i = START; i < END; ++i) {
        int position = (i * (unsigned long long) peak_index) % size;
        double angle = phase[i];
        double coord = position * (I_WIDTH / (double) size)
            + angle * (I_WIDTH / 2 / M_PI);
        coord = fmod(coord, I_WIDTH);
        if (coord < 0)
            coord += I_WIDTH;
#pragma omp atomic
        ++counts[in[i]][(int) coord];
    }

    // Now transform for filtering...
    complex float (*freqc)[I_WIDTH / 2 + 1] = fftwf_malloc(
        sizeof(complex float) * sample_limit * (I_WIDTH / 2 + 1));
    fftf_once(fftwf_plan_dft_r2c_2d(sample_limit, I_WIDTH,
                                    *counts, *freqc, FFTW_ESTIMATE));

    // Kill vertical high frequency noise.
    for (int i = I_HEIGHT / 2 + 1; i < sample_limit - I_HEIGHT / 2 - 1; ++i)
        for (size_t j = 0; j != I_WIDTH / 2 + 1; ++j)
            freqc[i][j] = 0;
    if (I_HEIGHT < sample_limit / 4)
        for (int i = (I_HEIGHT + 3) / 4; i != I_HEIGHT / 2; ++i) {
            double factor = coramp(2 - i * 4.0 / I_HEIGHT);
            for (size_t j = 0; j != I_WIDTH / 2 + 1; ++j) {
                freqc[i][j] *= factor;
                freqc[sample_limit - i][j] *= factor;
            }
        }
    for (int i = 0; i != sample_limit; ++i) {
        int ii = i;
        if (i > sample_limit / 2)
            ii = sample_limit - i;
        for (int j = 0; j != I_WIDTH / 2 + 1; ++j) {
            double s = sqrt(square(j / (double) I_WIDTH)
                            + square(ii / (double) I_HEIGHT));
            // Between 1/4 and 1/8 we ramp up to 2.
            // Between 1/8 and 1/32 we maintain as 2.
            // Between 1/32 and 1/64 we ramp down to 2.
            if (s <= 1.0/4 && s >= 1.0/8)
                freqc[i][j] *= 1 + coramp(2 - (s * 8));
            else if (s <= 1.0/8 && s >= 1.0/32)
                freqc[i][j] *= 2;
            else if (s <= 1.0/32 && s >= 1.0/64)
                freqc[i][j] *= 1 + coramp(s * 64 - 1);
        }
    }

    fftf_once(fftwf_plan_dft_c2r_2d(sample_limit, I_WIDTH,
                                    *freqc, *counts, FFTW_ESTIMATE));
    fftwf_free(freqc);

    fprintf(outfile, "unset xtics\n");
    fprintf(outfile, "unset ytics\n");
    fprintf(outfile, "unset cbtics\n");
    fprintf(outfile, "unset colorbox\n");
    fprintf(outfile, "unset border\n");
    fprintf(outfile, "set palette rgbformulae 22,21,23\n");
    fprintf(outfile, "set terminal wxt size %i, %i\n", I_WIDTH * 2, I_HEIGHT);
    fprintf(outfile, "set lmargin 0\n");
    fprintf(outfile, "set rmargin 0\n");
    fprintf(outfile, "set tmargin 0\n");
    fprintf(outfile, "set bmargin 0\n");
    fprintf(outfile, "set xrange [0:%i]\n", 2 * I_WIDTH);
    fprintf(outfile, "set yrange [%i:%i]\n", 0, I_HEIGHT);
    fprintf(outfile, "set cbrange [0:%li]\n", 12 * size);
    fprintf(outfile, "plot '-' matrix with image");
    for (int ii = 0; ii < I_HEIGHT; ++ii) {
        int i = ii * sample_limit / I_HEIGHT;
        fprintf(outfile, "\n%g", counts[i][0]);
        for (int j = 1; j < I_WIDTH; ++j)
            fprintf(outfile, " %g", counts[i][j]);
        for (int j = 0; j < I_WIDTH; ++j)
            fprintf(outfile, " %g", counts[i][j]);
    }
    fprintf(outfile, "\ne\ne\n");
    fftwf_free(counts);
}


static unsigned char * capture(size_t len)
{
    int clock;
    int count;
    if (period % 4 == 0) {
        clock = 0;
        count = period / 4 - 1;
    }
    else if (period % 5 == 0) {
        clock = ADC_CLOCK_SELECT;
        count = period / 5 - 1;
    }
    else
        errx(1, "Period must be a multiple of 4 or 5 (nanoseconds)\n");

    if (count < 39 || count > 255)
        errx(1, "Gives count = %i outside of 39...255", count);

    fprintf(stderr, "Capturing @ %ins, %iMHz / %i\n",
            period, clock ? 200 : 250, count + 1);

    libusb_device_handle * dev = usb_open();

    // Reset the ADC and clock if necessary.  Set up the sample counter.
    unsigned char reset[] = {
        REG_ADDRESS, REG_MAGIC, MAGIC_MAGIC, REG_ADC, clock|ADC_RESET };
    usb_send_bytes(dev, reset, sizeof reset);
    usleep(100000);

    // Now set up ADC:  Low gain, hi perf modes.
    adc_config(dev, clock,
               0x2510,                  // Low gain.
               0x0303, 0x4a01,          // High perf
               0xcf00, // Offset params
               0x3de0, // Format / enable offset
               -1);

    // Slurp the sampler in turbo mode.
    unsigned char * result = usb_slurp_channel(
        dev, len, XMIT_TURBO|XMIT_SAMPLE, count, wander_decay);

    // Back to normal parameters, in case we down clocked.
    reset[sizeof reset - 1] = ADC_SEN;
    usb_send_bytes(dev, reset, sizeof reset);

    usb_close(dev);
    return result;
}


static void parse_opts(int argc, char ** argv)
{
    while (1)
        switch (getopt(argc, argv, "i:j:o:d:p:n:w:")) {
        case 'i':
            inpath = optarg;
            break;
        case 'o':
            outpath = optarg;
            break;
        case 'n':
            SIZE = strtoul(optarg, NULL, 0);
            if (SIZE < 1048576 || (SIZE * 32) / 32 != SIZE || (SIZE & 1))
                errx(1, "Number of samples invalid");
            break;
        case 'j':
            jitterpath = optarg;
            break;
        case 'd':
            dumppath = optarg;
            break;
        case 'p':
            period = strtoul(optarg, NULL, 0);
            break;
        case 'w':
            wander_decay = strtol(optarg, NULL, 0);
            break;
        case -1:
            return;
        default:
            errx(1, "Bad option.\n");
        }
}


int main(int argc, char ** argv)
{
    parse_opts(argc, argv);

    fftwf_init_threads();
    fftwf_plan_with_nthreads(4);

    /* freq_domain_filter_width =  */

    const unsigned char * buffer = NULL;
    size_t bufsize = 0;
    if (inpath != NULL) {
        size_t sz = 0;
        unsigned char * b = NULL;
        slurp_path(inpath, &b, &bufsize, &sz);
        buffer = b;
    }
    else {
        bufsize = SIZE * 2 + USB_SLOP;
        buffer = capture(bufsize);
    }

    if (dumppath != NULL) {
        dump_path(dumppath, buffer, bufsize);
        if (outpath == NULL)
            return EXIT_SUCCESS;
    }

    const unsigned char * good = buffer;
    if (best14 (&good, &bufsize) < SIZE)
        errx(1, "Did not get sufficient contiguous data.");

    // Read in the data and find the used codes.
    unsigned short * in = xmalloc(SIZE * sizeof * in);
    bool used[SAMPLE_RANGE];
    memset(used, 0, sizeof used);
#pragma omp parallel for
    for (int i = 0; i < SIZE; ++i) {
        int x = good[i * 2] + good[i * 2 + 1] * 256;
        x &= SAMPLE_RANGE - 1;
        x ^= 1 << (SAMPLE_BITS - 1);
        assert(x >= 0 && x < SAMPLE_RANGE);
        in[i] = x;
#pragma omp atomic write
        used[x] = true;
    }
    free((void*)buffer);

    // Map the used codes to a gapless sequence.
    int reindex_limit = 0;
    int reindex[SAMPLE_RANGE];
    int low = -1;
    int top = -1;
    for (int i = 0; i != SAMPLE_RANGE; ++i)
        if (used[i]) {
            reindex[i] = reindex_limit++;
            if (low < 0)
                low = i;
            top = i;
        }

    fprintf(stderr, "Low %i high %i used %i missing %i\n",
            low, top, reindex_limit, top - low + 1 - reindex_limit);

    // Map the data to the gapless sequence.
#pragma omp parallel for
    for (int i = 0; i < SIZE; ++i)
        in[i] = reindex[in[i]];

    float * data = rectify(in, SIZE);
    size_t peak_index = peak_power(data, SIZE);
    phase_recover(data, SIZE, peak_index);

    FILE * outfile = stdout;
    if (outpath != NULL) {
        outfile = fopen(outpath, "w");
        if (outfile == NULL)
            err(1, "Cannot open output %s", outpath);
    }

    create_image(outfile, in, data, SIZE, peak_index, reindex_limit);
    free(in);
    fftwf_free(data);

    fflush(outfile);
    if (ferror(outfile))
        errx(1, "Error writing output");

    if (outpath != NULL)
        fclose(outfile);

    return EXIT_SUCCESS;
}
