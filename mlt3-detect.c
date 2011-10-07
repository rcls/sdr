#include <assert.h>
#include <complex.h>
#include <fftw3.h>
#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define FREQ (1e8 / 16.0)

#define SIZE (1<<23)
#define HALF (SIZE/2)
#define HALFp1 (HALF + 1)

#define WIDTH 32

//#define ROWS 4096
#define ROWS HALF

static int in[SIZE];
static double mapped[SIZE];
static complex chirped[SIZE];

static double cmod_sq(complex z)
{
    double re = creal(z);
    double im = cimag(z);
    return re * re + im * im;
}


static void chirped_fft(double chirp)
{
    static fftw_plan plan;
    printf("Chirp = %g\n", chirp);

    if (!plan)
        plan = fftw_plan_dft_1d(
            SIZE, chirped, chirped, FFTW_FORWARD, FFTW_ESTIMATE);

    for (int i = 0; i < SIZE; ++i) {
        double ii = (i - HALF) * (1.0 / SIZE);
        double phase = chirp * (ii * ii - 0.5);
        chirped[i] = mapped[i] * (cos(phase) + I * sin(phase));
    }

    fftw_execute(plan);
}


// Find fit in form Y = 1/(slope*(X-offset)).  This turns out to not be a good
// fit :-( .  The problem is that the peak is not at 90% phase to the tails...
// The problem seems to be chirping... so we'll correct the chirp...
static double regression(int CENTER,
                         complex * __restrict__ slope,
                         complex * __restrict__ offset)
{
    const int N = WIDTH * 2 + 1;
    int X[N];
    complex Y[N];
    double weight[N];
    double mean_X = 0;
    double mean_Y = 0;
    double weight_sum = 0;
    for (int i = 0; i < N; ++i) {
        int ii = i + CENTER - WIDTH;
        X[i] = i - WIDTH;
        complex d = chirped[ii];
        Y[i] = 1 / d;
        if (*slope == 0 && *offset == 0)
            weight[i] = cmod_sq(d);
        else
            weight[i] = cabs(d / (*slope * (X[i] - *offset)));

        mean_X += X[i] * weight[i];
        mean_Y += Y[i] * weight[i];
        weight_sum += weight[i];
    }
    mean_X /= weight_sum;
    mean_Y /= weight_sum;

    complex covariance = 0;
    double x_variance = 0;
    double y_variance = 0;

    for (int i = 0; i < N; ++i) {
        double w = weight[i] * weight[i];
        complex xd = X[i] - mean_X;
        complex yd = Y[i] - mean_Y;
        covariance += w * conj(xd) * yd;
        x_variance += w * cmod_sq(xd);
        y_variance += w * cmod_sq(yd);
    }
    *slope = covariance / x_variance;
    *offset = mean_X - mean_Y / *slope;
    double cq = cabs(covariance) / sqrt(x_variance * y_variance);
    printf("Slope = %.5g%+.5gi, offset = %.5g%+.5gi, fit = %f\n",
           creal(*slope), cimag(*slope), creal(*offset), cimag(*offset), cq);
    // for (int i = 0; i != N; ++i) {
    //     complex eY = 1 / (*slope * (X[i] - *offset));
    //     printf ("Actual % 11.05g%+11.05gi, est % 11.05g%+11.05gi\n",
    //             creal(Y[i]), cimag(Y[i]), creal(eY), cimag(eY));
    // }
    return cq;
}


static double run_regression(int iterations)
{
    double max_power = 0;
    int max_index = 0;
    for (int i = 100; i < HALF - 100; ++i) {
        double power = cmod_sq(chirped[i]);
        if (power > max_power) {
            max_power = power;
            max_index = i;
        }
    }

    fprintf(stderr, "Peak at %i, %f Hz\n",
             max_index, max_index * (FREQ / SIZE));
    if (max_index <= WIDTH || max_index >= HALF - WIDTH) {
        fprintf(stderr, "Too close to end.\n");
        exit(EXIT_FAILURE);
    }

    complex slope = 0;
    complex offset = 0;
    double fit = 0;
    for (int i = 0; i < iterations; ++i)
        fit = regression(max_index, &slope, &offset);
    return fit;
}


static double run_chirped(double chirp)
{
    chirped_fft(chirp);
    return run_regression(5);
}


static void chirp_test(void)
{
    double hi = -11;
    double md = -10;
    double lo = -9;
    double fit_hi = run_chirped(hi);
    double fit_md = run_chirped(md);
    double fit_lo = run_chirped(lo);

    while (fit_md > fit_lo && fit_md > fit_hi) {
        double hh = (hi + md) * 0.5;
        double ll = (lo + md) * 0.5;
        double fit_hh = run_chirped(hh);
        double fit_ll = run_chirped(ll);
        if (fit_md >= fit_hh && fit_md >= fit_ll) {
            hi = hh;
            lo = lo;
            fit_hi = fit_hh;
            fit_lo = fit_ll;
        }
        else if (fit_hh > fit_ll) {
            lo = md;
            md = hh;
            fit_lo = fit_md;
            fit_md = fit_hh;
        }
        else {
            hi = md;
            md = ll;
            fit_hi = fit_md;
            fit_md = fit_ll;
        }
    }
}


static void print_table(void)
{
    static double out[SIZE + 1];

    fftw_plan plan = fftw_plan_r2r_1d(
        SIZE, mapped, out, FFTW_R2HC, FFTW_ESTIMATE);

    fprintf(stderr, "Executing...\n");

    fftw_execute(plan);
    out[0] = 0;                         // Not interesting...
    out[SIZE] = 0;

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

    if (1)
        chirp_test();
    if (0) {
        chirped_fft(0);
        run_regression(1);
    }
    if (0)
        print_table();

    exit(EXIT_SUCCESS);
}
