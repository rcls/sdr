#include <assert.h>
#include <complex.h>
#include <fftw3.h>
#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "lib/legendre.h"

#define FREQ (1e8 / 16.0)

#define SIZE (1<<23)
#define HALF (SIZE/2)
#define HALFp1 (HALF + 1)

// Time domain length of filter.
#define FILTER_WIDTH 16384

// Width of image (image is doubled & is actually twice this).
#define I_WIDTH 350
// Height of image
#define I_HEIGHT 500

//#define ROWS 4096
#define ROWS HALF

static int in[SIZE];
static double out[SIZE + 1];

static double mapped[SIZE];


static void run_regression(void)
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
            max_index, max_index * (FREQ / SIZE));
    if (max_index <= SIZE / FILTER_WIDTH
        || max_index >= HALF - SIZE / FILTER_WIDTH) {
        fprintf(stderr, "Too close to end.\n");
        exit(EXIT_FAILURE);
    }

    // Doing a full size fft & then the regression on full time resolution is
    // a bit silly...  CPU cycles are cheap.
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

    const int START = FILTER_WIDTH;
    const int END = SIZE - FILTER_WIDTH;
    const int LEN = END - START;

    static double phase[SIZE];
    int last_phase_loops = 0;
    double last_phase = 0;
    double max_jump = 0;
    // Run phase detection...
    for (int i = START; i != END; ++i) {
        double this_phase = carg(filtered[i]);
        double jump = this_phase - last_phase;
        if (this_phase > last_phase + M_PI) {
            --last_phase_loops;
            jump -= 2 * M_PI;
        }
        else if (this_phase < last_phase - M_PI) {
            ++last_phase_loops;
            jump += 2 * M_PI;
        }
        last_phase = this_phase;
        phase[i] = this_phase + 2 * M_PI * last_phase_loops;
        if (i && fabs(jump) > max_jump)
            max_jump = fabs(jump);
    }

    fprintf(stderr, "Max jump = %g\n", max_jump);

    // Polynomial fit.
    const int order = 5;
    double coeffs[order + 1];
    l_fit(coeffs, phase + START, LEN, order);

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
    for (int i = 0; i <= order; ++i)
        fprintf(stderr, " %g", coeffs[i]);
    fprintf(stderr, "\n");
    fprintf(stderr, "Mean frequency offset: %g Hz\n",
            coeffs[1] * (FREQ / LEN / M_PI));
    if (order > 1)
        fprintf(stderr, "End-end frequency drift: %g Hz\n",
                6 * coeffs[2] * (FREQ / LEN / M_PI));

    unsigned int counts[I_HEIGHT][I_WIDTH];
    memset(counts, 0, sizeof(counts));
    for (int i = START; i < END; ++i) {
        int position
            = (i * (unsigned long long) max_index) % SIZE; // (mod size).
        double angle = l_eval(l_x(i, LEN), coeffs, order); // mod 2pi
        double coord = position * (I_WIDTH / (double) SIZE)
            + angle * (I_WIDTH / 2 / M_PI);
        coord = fmod(coord, I_WIDTH);
        if (coord < 0)
            coord += I_WIDTH;
        ++counts[in[i] * I_HEIGHT / 13000][(int) coord];
    }
    printf("unset xtics\n");
    printf("unset ytics\n");
    printf("unset cbtics\n");
    printf("unset colorbox\n");
    printf("unset border\n");
    printf("set palette rgbformulae 22,21,23\n");
    printf("set terminal wxt size %i, %i\n",
           I_WIDTH * 2, 825 * I_HEIGHT / 1000);
    printf("set lmargin 0\n");
    printf("set rmargin 0\n");
    printf("set tmargin 0\n");
    printf("set bmargin 0\n");
    printf("set xrange [0:%i]\n", 2 * I_WIDTH);
    printf("set yrange [%i:%i]\n", 50 * I_HEIGHT / 1000, 875 * I_HEIGHT / 1000);
    printf("set cbrange [0:%i]\n", 140000000 / I_WIDTH / I_HEIGHT);
    printf("plot '-' matrix with image");
    for (int i = 0; i < I_HEIGHT; ++i) {
        printf("\n%i", counts[i][0]);
        for (int j = 1; j < I_WIDTH; ++j)
            printf(" %i", counts[i][j]);
        for (int j = 0; j < I_WIDTH; ++j)
            printf(" %i", counts[i][j]);
    }
    printf("\ne\ne\n");
}


static void print_table(void)
{
    for (int i = 0; i != ROWS; ++i) {
        const char * sep = "";
        for (int mult = 1; mult * ROWS <= HALF; mult *= 2) {
            int low = i * mult;
            int high = (i + 1) * mult;
            double power = 0;
            double re = 0;
            double im = 0;
            for (int k = low; k != high; ++k) {
                power += out[k] * out[k] + out[SIZE - k] * out[SIZE - k];
                re += out[k];
                im += out[SIZE - k];
            }
            double freq = (low + high - 1) * (0.5 * FREQ / SIZE);
            printf("%s%f\t%g", sep, freq, power);
            printf("\t%f", atan2(im, re));
            sep = "\t";
        }
        printf("\n");
    }
}


int main()
{
    FILE * used = fopen("used-codes.txt", "r");
    if (!used)
        perror("open used-codes.txt"), exit(1);

    int reindex_limit = 0;
    int x;
    int reindex[16384];
    memset(reindex, 0, sizeof(reindex));
    while (fscanf(used, "%x", &x) > 0) {
        assert(x >= 0 && x < 16384);
        reindex[x] = ++reindex_limit;
    }
    assert(reindex_limit < 16384);
    fclose(used);

    for (int i = 0; i != SIZE; ++i) {
        if (scanf("%x", &x) < 1)
            fprintf(stderr, "Short read...\n"), exit(1);
        assert(x >= 0 && x < 16384);
        assert(reindex[x] != 0);
        in[i] = reindex[x];
    }

    int counts[16384];
    memset(counts, 0, sizeof(counts));
    for (int i = 0; i != SIZE; ++i)
        counts[in[i]]++;

    x = 0;
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

    if (1)
        run_regression();

    if (0)
        print_table();

    exit(EXIT_SUCCESS);
}
