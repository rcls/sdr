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

#define FREQ (1e9 / period)

#define SIZE (1<<23)
#define HALF (SIZE/2)
#define HALFp1 (HALF + 1)

// Time domain length of filter.
#define FILTER_WIDTH 16384
//#define FILTER_WIDTH 128

// Width of image (image is doubled & is actually twice this).
#define I_WIDTH 600
// Height of image
#define I_HEIGHT 1000

//#define ROWS 4096
#define ROWS HALF

static const char * inpath;
static const char * dumppath;
static const char * outpath;
static const char * jitterpath;
static int poly_order = 10;
static int period = 205;

static int in[SIZE];
static double out[SIZE + 1];

static double mapped[SIZE];

static int sample_limit;

static void run_regression(FILE * outfile)
{
    double max_power = 0;
    int max_index = 0;
    for (int i = 1; i < HALF; ++i) {
        double power = out[i] * out[i] + out[SIZE-i] * out[SIZE-i];
        if (power > max_power) {
            max_power = power;
            max_index = i;
        }
    }

    fprintf(stderr, "Peak at %i, %f Hz\n",
            max_index, max_index * 1e9 / period / SIZE);
    if (max_index <= SIZE / FILTER_WIDTH
        || max_index >= HALF - SIZE / FILTER_WIDTH) {
        fprintf(stderr, "Too close to end.\n");
        exit(EXIT_FAILURE);
    }

    // Doing a full size fft & then the regression on full time resolution is
    // a bit silly...  But CPU cycles are cheap.
    fprintf(stderr, "Construct filter...\n");
    static fftw_plan plan;
    static complex filtered[SIZE];
    if (!plan)
        plan = fftw_plan_dft_1d(SIZE, filtered, filtered,
                                FFTW_BACKWARD, FFTW_ESTIMATE);
    // First generate the filter spectrum.  Full complex instead of real
    // symmetric FFT.  Again, waste waste waste.
    for (unsigned int i = 0; i < SIZE; ++i)
        filtered[i] = 0;
    filtered[0] = M_PI / FILTER_WIDTH;
    for (unsigned int i = 1; i < FILTER_WIDTH; ++i)
        filtered[i] = filtered[SIZE - i] = sin(i * (M_PI / FILTER_WIDTH)) / i;
    for (unsigned int i = FILTER_WIDTH; i < SIZE - FILTER_WIDTH; ++i)
        filtered[i] = 0;
    fftw_execute(plan);

    // Do the filtering in frequency domain.
    for (int i = 1; i < max_index; ++i)
        filtered[SIZE - max_index + i] *= out[i] + I * out[SIZE - i];
    for (int i = max_index; i < HALF; ++i)
        filtered[i - max_index] *= out[i] + I * out[SIZE - i];
    for (int i = HALF - max_index; i <= SIZE - max_index; ++i)
        filtered[i] = 0;

    fftw_execute(plan);

    fprintf(stderr, "Filtering...\n");
    const int START = FILTER_WIDTH;
    const int END = SIZE - FILTER_WIDTH;
    const int LEN = END - START;

    static double phase[SIZE];
    int last_phase_loops = 0;
    int max_loops = 0;
    int min_loops = 0;
    double max_jump = 0;
    double last_phase = carg(filtered[START]);
    phase[START] = last_phase;

    // Run phase detection...
    for (int i = START + 1; i != END; ++i) {
        double this_phase = carg(filtered[i]);
        double jump = this_phase - last_phase;
        if (this_phase > last_phase + M_PI) {
            --last_phase_loops;
            if (last_phase_loops < min_loops)
                min_loops = last_phase_loops;
            jump -= 2 * M_PI;
        }
        else if (this_phase < last_phase - M_PI) {
            ++last_phase_loops;
            if (last_phase_loops > max_loops)
                max_loops = last_phase_loops;
            jump += 2 * M_PI;
        }
        last_phase = this_phase;
        phase[i] = this_phase + 2 * M_PI * last_phase_loops;
        if (fabs(jump) > max_jump)
            max_jump = fabs(jump);
    }

    fprintf(stderr, "Max jump = %g, loop range %i..%i, finish %i\n",
            max_jump, min_loops, max_loops, last_phase_loops);

    if (jitterpath != NULL) {
        int len = END - START;
        float * js = spectrum(phase + START, len);
        dump_path(jitterpath, js, len / 2 * sizeof(float));
        free(js);
    }

    // Polynomial fit.
    double coeffs[poly_order + 1];
    l_fit(coeffs, phase + START, LEN, poly_order);

    // Find the RMS residual.
    double sum = 0;
    double mres = 0;
    for (int i = START; i != END; ++i) {
        sum += phase[i] * phase[i];
        if (fabs(phase[i]) > mres)
            mres = fabs(phase[i]);
    }

    fprintf(stderr, "RMS & max phase residual: %g & %g radians.\n",
            sqrt(sum / LEN), mres);
    fprintf(stderr, "Normalised coeffs:");
    for (int i = 0; i <= poly_order; ++i)
        fprintf(stderr, " %g", coeffs[i]);
    fprintf(stderr, "\n");
    fprintf(stderr, "Mean frequency offset: %g Hz\n",
            coeffs[1] * (1e9 / period / LEN / M_PI));
    if (poly_order > 1)
        fprintf(stderr, "End-end frequency drift: %g Hz\n",
                6 * coeffs[2] * (1e9 / period / LEN / M_PI));

    static unsigned int counts[I_HEIGHT][I_WIDTH];
    memset(counts, 0, sizeof(counts));
    for (int i = START; i < END; ++i) {
        int position
            = (i * (unsigned long long) max_index) % SIZE; // (mod size).
        double angle = l_eval(l_x(i, LEN), coeffs, poly_order); // mod 2pi
        double coord = position * (I_WIDTH / (double) SIZE)
            + angle * (I_WIDTH / 2 / M_PI);
        coord = fmod(-coord, I_WIDTH);
        if (coord < 0)
            coord += I_WIDTH;
        ++counts[in[i] * I_HEIGHT / sample_limit][(int) coord];
    }
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
    fprintf(outfile, "set cbrange [0:%li]\n", 16ul * SIZE / I_WIDTH / I_HEIGHT);
    fprintf(outfile, "plot '-' matrix with image");
    for (int i = 0; i < I_HEIGHT; ++i) {
        fprintf(outfile, "\n%i", counts[i][0]);
        for (int j = 1; j < I_WIDTH; ++j)
            fprintf(outfile, " %i", counts[i][j]);
        for (int j = 0; j < I_WIDTH; ++j)
            fprintf(outfile, " %i", counts[i][j]);
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
    adc_config(dev, 0x2510, 0x0303, 0x4a01, -1);

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
        switch (getopt(argc, argv, "i:j:o:d:p:O:")) {
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
    bool used[16384];
    memset(used, 0, sizeof used);
    for (int i = 0; i != SIZE; ++i) {
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

    for (int i = 0; i != SIZE; ++i) {
        int d = in[i];
        if (d < middle)
            mapped[i] = fabs(quart1 - d);
        else
            mapped[i] = fabs(d - quart3);
    }

    fprintf(stderr, "Got data...\n");

    fftw_init_threads();
    fftw_plan_with_nthreads(4);

    fftw_plan plan = fftw_plan_r2r_1d(
        SIZE, mapped, out, FFTW_R2HC, FFTW_ESTIMATE);
    fftw_execute(plan);
    out[0] = 0;                         // Not interesting...
    out[SIZE] = 0;

    FILE * outfile = stdout;
    if (outpath != NULL) {
        outfile = fopen(outpath, "w");
        if (outfile == NULL)
            err(1, "Cannot open output %s", outpath);
    }

    run_regression(outfile);

    fflush(outfile);
    if (ferror(outfile))
        errx(1, "Error writing output");

    if (outpath != NULL)
        fclose(outfile);

    return EXIT_SUCCESS;
}
