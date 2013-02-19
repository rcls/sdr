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

#define UNLIKELY(b) __builtin_expect(b, 0)

static const char * inpath;
static const char * dumppath;
static const char * outpath;
static const char * jitterpath;
static int poly_order = 10;
static int period = 205;

static unsigned short * in;
static float * out;

static int sample_limit;

static void fft_once(fftw_plan plan)
{
    fftw_execute(plan);
    fftw_destroy_plan(plan);
}


static void run_regression(FILE * outfile)
{
    double max_power = 0;
    int peak_index = 0;
    const long HALF = SIZE / 2;
#pragma omp parallel for
    for (int i = 1; i < HALF; ++i) {
        double power = out[i] * out[i] + out[SIZE-i] * out[SIZE-i];
        if (power > max_power)
#pragma omp critical(max_power)
            if (power > max_power) {
                max_power = power;
                peak_index = i;
            }
    }

    fprintf(stderr, "Peak at %i, %f Hz\n",
            peak_index, peak_index * 1e9 / period / SIZE);
    if (peak_index <= SIZE / FILTER_WIDTH
        || peak_index >= HALF - SIZE / FILTER_WIDTH) {
        fprintf(stderr, "Too close to end.\n");
        exit(EXIT_FAILURE);
    }

    // Do a power weighted mean around peak_index and decide on a new peak
    // index.
    double weights = 0;
    double wsum = 0;
    int flen = SIZE / FILTER_WIDTH;
    for (int i = - flen + 1; i < flen; ++i) {
        long j = i + peak_index;
        double w = sqrt(out[j] * out[j] + out[SIZE-j] * out[SIZE-j]);
        weights += w;
        wsum += w * i;
    }

    peak_index += (long) (wsum / weights);
    fprintf(stderr, "Adjusted to %i, %f Hz (%g %g)\n",
            peak_index, peak_index * 1e9 / period / SIZE, wsum, weights);

    // Doing a full size fft & then the regression on full time resolution is
    // a bit silly...  But CPU cycles are cheap.
    fprintf(stderr, "Construct filter...\n");
    complex float * filtered = fftw_malloc (SIZE * sizeof * filtered);
    fftwf_plan plan = fftwf_plan_dft_1d(SIZE, filtered, filtered,
                                        FFTW_BACKWARD, FFTW_ESTIMATE);
    // First generate the filter spectrum.  Full complex instead of real
    // symmetric FFT.  Again, waste waste waste.
    filtered[0] = M_PI / FILTER_WIDTH;
    for (long i = 1; i < FILTER_WIDTH; ++i)
        filtered[i] = filtered[SIZE - i] = sin(i * (M_PI / FILTER_WIDTH)) / i;
    for (long i = FILTER_WIDTH; i < SIZE - FILTER_WIDTH; ++i)
        filtered[i] = 0;
    fprintf(stderr, "Filter gen...");
    fftwf_execute(plan);

    // Do the filtering in frequency domain.
    fprintf(stderr, "\nFiltering...");
#pragma omp parallel for
    for (long i = 1; i < peak_index; ++i)
        filtered[SIZE - peak_index + i] *= out[i] + I * out[SIZE - i];
#pragma omp parallel for
    for (long i = peak_index; i < HALF; ++i)
        filtered[i - peak_index] *= out[i] + I * out[SIZE - i];
#pragma omp parallel for
    for (long i = HALF - peak_index; i <= SIZE - peak_index; ++i)
        filtered[i] = 0;

    // Back to time domain.
    fprintf(stderr, "\nBack to time...");
    fftwf_execute(plan);
    fftwf_destroy_plan(plan);
    fprintf(stderr, "\n");

    const long START = FILTER_WIDTH;
    const long END = SIZE - FILTER_WIDTH;
    const long LEN = END - START;

    float * phase = xmalloc(SIZE * sizeof * phase);

    // Run phase detection...
#pragma omp parallel for
    for (long i = START; i < END; ++i)
        phase[i] = carg(filtered[i]) * (0.5 / M_PI);

    fftw_free(filtered);

    // See how big the steps in phase are.  This determines the stride for
    // doing coarse grained loop detection.
    double max_jump = 0;
#pragma omp parallel for reduction(max:max_jump)
    for (long i = START + 1; i < END; ++i) {
        double jump = fabs(phase[i] - phase[i-1]);
        if (UNLIKELY(jump > max_jump)) {
            if (jump > 0.5)
                jump = 1 - jump;
            if (jump > max_jump)
                max_jump = jump;
        }
    }

    // Work out the block size for doing coarse grained loop detection.
    long blocks;
    if (max_jump < 4.0 / LEN)
        blocks = 8;                     // Split up for parallelism.
    else if (max_jump > 1.0 / 2048)
        blocks = 1;                     // Yurrgghhh... do it all as one block.
    else
        blocks = 1 + (long) (LEN * max_jump * 2);

    fprintf(stderr, "Max jump = %g, blocks = %zi\n", max_jump, blocks);

    int loops[blocks + 1];
    double start[blocks];
//#pragma omp parallel for
    for (long i = 0; i < blocks; ++i) {
        long bstart = (LEN - 1) * i / blocks + START + 1;
        long bend = (LEN - 1) * (i + 1) / blocks + START + 1;
        start[i] = phase[bstart - 1];
        int l = 0;
        for (long j = bstart; j != bend; ++j)
            if (UNLIKELY(phase[j] > phase[j-1] + 0.5))
                --l;
            else if (UNLIKELY(phase[j] < phase[j-1] - 0.5))
                ++l;
        loops[i] = l;
    }
    int running = 0;
    double slope = 0;
    double weight = 0;
    double mean = 0;
    for (long i = 0; i < blocks; ++i) {
        int next_running = running + loops[i];
        double ii = i - blocks * 0.5;
        loops[i] = running;
        slope += ii * running;
        weight += ii * ii;
        mean += running;
        running = next_running;
    }
    loops[blocks] = running;

    slope += 0.5 * blocks * running;
    weight += blocks * blocks * 0.25;
    mean += running;

    slope = slope * blocks / (weight * LEN);
    mean /= blocks + 1;
    fprintf(stderr, "Slope = %g, mean = %g\n", slope, mean);

    fprintf(stderr, "Coarse loops done, now final adjust.\n");

    // Now the final phase adjustment.
#pragma omp parallel for
    for (long i = 0; i < blocks; ++i) {
        long bstart = (LEN - 1) * i / blocks + START + 1;
        long bend = (LEN - 1) * (i + 1) / blocks + START + 1;
        int l = loops[i];
        double last_phase = start[i];
        for (long j = bstart; j < bend; ++j) {
            if (UNLIKELY(phase[j] > last_phase + 0.5))
                --l;
            else if (UNLIKELY(phase[j] < last_phase - 0.5))
                ++l;
            last_phase = phase[j];
            phase[j] += l - mean - slope * (j - HALF);
        }
        assert(l == loops[i + 1]);
    }
    phase[START] -= mean + slope * (START - HALF);

    if (jitterpath != NULL) {
        fprintf(stderr, "Jitter spectrum.\n");
        float * js = spectrumf(phase + START, LEN);
        dump_path(jitterpath, js, LEN / 2 * sizeof(float));
        free(js);
    }

    double (*counts)[I_WIDTH] = fftw_malloc(
        sizeof(double) * sample_limit * I_WIDTH);
    memset(counts, 0, sizeof(double) * sample_limit * I_WIDTH);
#pragma omp parallel for
    for (long i = START; i < END; ++i) {
        int position = (i * (unsigned long long) peak_index) % SIZE;
        double angle = phase[i] + mean + slope * (i - HALF);
        double coord = position * (I_WIDTH / (double) SIZE)
            + angle * I_WIDTH;
        coord = fmod(-coord, I_WIDTH);
        if (coord < 0)
            coord += I_WIDTH;
#pragma omp atomic
        ++counts[in[i]][(int) coord];
    }

    // Now transform for filtering...
    complex (*freqc)[I_WIDTH / 2 + 1] = fftw_malloc(
        sizeof(complex) * sample_limit * (I_WIDTH / 2 + 1));
    fft_once(fftw_plan_dft_r2c_2d(sample_limit, I_WIDTH,
                                  *counts, *freqc, FFTW_ESTIMATE));

    // Kill vertical high frequency noise.
    for (int i = I_HEIGHT / 4 + 1; i != sample_limit - I_HEIGHT / 4 - 1; ++i)
        for (long j = 0; j != I_WIDTH / 2 + 1; ++j)
            freqc[i][j] = 0;
    for (int i = (I_HEIGHT + 7) / 8; i != I_HEIGHT / 4; ++i) {
        double factor = (i - I_HEIGHT / 8) / (I_HEIGHT / 8);
        for (long j = 0; j != I_WIDTH / 2 + 1; ++j) {
            freqc[i][j] *= factor;
            freqc[sample_limit - i][j] *= factor;
        }
    }

    fft_once(fftw_plan_dft_c2r_2d(sample_limit, I_WIDTH,
                                  *freqc, *counts, FFTW_ESTIMATE));

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
    fprintf(outfile, "set cbrange [0:%li]\n", 16ul * SIZE);
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
    adc_config(dev, clock, 0x2510, 0x0303, 0x4a01, -1);

    // Slurp the sampler in turbo mode.
    unsigned char * result = usb_slurp_channel(
        dev, len, XMIT_TURBO|XMIT_ADC_SAMPLE, count, 0);

    // Back to normal parameters, in case we down clocked.
    reset[sizeof reset - 1] = ADC_SEN;
    usb_send_bytes(dev, reset, sizeof reset);

    usb_close(dev);
    return result;
}


static void parse_opts(int argc, char ** argv)
{
    while (1)
        switch (getopt(argc, argv, "i:j:o:d:p:O:n:")) {
        case 'i':
            inpath = optarg;
            break;
        /* case 'b': */
        /*     bandwidth = strtod(optarg, NULL); */
        /*     break; */
        case 'o':
            outpath = optarg;
            break;
        case 'O':
            poly_order = strtoul(optarg, NULL, 0);
            if (poly_order < 1 || poly_order > 1000)
                errx(1, "Polynomial order must be between 1 and 1000.");
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
        case -1:
            return;
        default:
            errx(1, "Bad option.\n");
        }
}


int main(int argc, char ** argv)
{
    parse_opts(argc, argv);

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

    if (best14 (&buffer, &bufsize) < SIZE)
        errx(1, "Did not get sufficient contiguous data.");

    // Read in the data and find the used codes.
    in = xmalloc(SIZE * sizeof * in);
    bool used[16384];
    memset(used, 0, sizeof used);
#pragma omp parallel for
    for (int i = 0; i < SIZE; ++i) {
        int x = buffer[i * 2] + 256 * (buffer[i * 2 + 1] & 0x3f);
        x ^= 1 << 13;
        assert(x >= 0 && x < 16384);
        in[i] = x;
        used[x] = true;
    }

    // Map the used codes to a gapless sequence.
    int reindex_limit = 0;
    int reindex[16384];
    int low = -1;
    int top = -1;
    for (int i = 0; i != 16384; ++i)
        if (used[i]) {
            reindex[i] = reindex_limit++;
            if (low < 0)
                low = i;
            top = i;
        }

    fprintf(stderr, "Low %i high %i used %i missing %i\n",
            low, top, reindex_limit, top - low + 1 - reindex_limit);
    sample_limit = reindex_limit;

    // Map the data to the gapless sequence.
    for (int i = 0; i != SIZE; ++i)
        in[i] = reindex[in[i]];

    // Do a nonlinear transformation for clock recovery.  We use a W shaped
    // function based on the quartiles.
    int counts[16384];
    memset(counts, 0, sizeof(counts));
    for (int i = 0; i != SIZE; ++i)
        counts[in[i]]++;

    int x = 0;
    double quart1 = 0;
    double middle = 0;
    double quart3 = 0;
    for (int i = 0; i != 16384; ++i) {
        int xx = x + counts[i];
        if (x < SIZE / 4 && xx >= SIZE / 4)
            quart1 = i - (xx - SIZE * 0.25) / (xx - x);
        if (x < SIZE / 2 && xx >= SIZE / 2)
            middle = i - (xx - SIZE * 0.5) / (xx - x);
        if (x < 3 * SIZE / 4 && xx >= 3 * SIZE / 4)
            quart3 = i - (xx - SIZE * 0.75) / (xx - x);
        x = xx;
    }

    fprintf(stderr, "Quartiles : %f %f %f\n", quart1, middle, quart3);

    out = fftw_malloc(SIZE * sizeof * out);
#pragma omp parallel for
    for (int i = 0; i < SIZE; ++i) {
        int d = in[i];
        if (d < middle)
            out[i] = fabs(quart1 - d);
        else
            out[i] = fabs(d - quart3);
    }

    fprintf(stderr, "Running phase detect fft...");

    fftwf_init_threads();
    fftwf_plan_with_nthreads(4);

    fftwf_plan plan = fftwf_plan_r2r_1d(SIZE, out, out,
                                        FFTW_R2HC, FFTW_ESTIMATE);
    fftwf_execute(plan);
    fftwf_destroy_plan(plan);
    fprintf(stderr, "\n");
    out[0] = 0;                         // Not interesting...

    FILE * outfile = stdout;
    if (outpath != NULL) {
        outfile = fopen(outpath, "w");
        if (outfile == NULL)
            err(1, "Cannot open output %s", outpath);
    }

    run_regression(outfile);
    fftw_free(out);

    fflush(outfile);
    if (ferror(outfile))
        errx(1, "Error writing output");

    if (outpath != NULL)
        fclose(outfile);

    return EXIT_SUCCESS;
}
