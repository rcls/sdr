// Simulation of the phasedetect algorithm, for validating the accuracy etc.
#include <assert.h>
#include <complex.h>
#include <fftw3.h>
#include <math.h>
#include <pthread.h>
#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define IN_BITS 36
#define OUT_BITS 18
#define ITERATIONS 16
#define ROUNDOFF_BIT -1
#define TRUNCATE_BIT 0

#define ANGLE_BITS (OUT_BITS - 2)

#define MASK(n) ((1l << (n)) - 1)
#define BIT(v, i) (!!((v) & (1l << (i))))

#define CMASK(v) ((v) & MASK(IN_BITS))
#define IMASK(v) ((v) & MASK(IN_BITS + 1))
#define AMASK(v) ((v) & MASK(OUT_BITS))

#define CTOP(v) BIT((v), IN_BITS - 1)
#define ITOP(v) BIT((v), IN_BITS)

typedef unsigned long word_t;
static const int offset[ITERATIONS] = { -1 };


static word_t phasedetect(word_t qq, word_t ii, const int * angle_updates)
{
    bool positive = !CTOP(qq) ^ CTOP(ii);

    word_t angle = (CTOP(ii) << (OUT_BITS - 1)) + 1;
    if (CTOP(qq ^ ii))
        angle += MASK(OUT_BITS - 1) - 1;

    if (CTOP(qq))
        qq = CMASK(~qq);
    if (CTOP(ii))
        ii = CMASK(~ii);

    for (int i = 0; i < ITERATIONS; ++i) {
        word_t ii_shift = ii >> (i * 2);
        word_t qq_trial = CMASK(qq + ii_shift);
        word_t ii_trial = IMASK(ii - qq);

        ii = IMASK(ii << 1);

        if (!BIT(ii_trial, IN_BITS)) {
            if (positive)
                angle = AMASK(angle + angle_updates[i]);
            else
                angle = AMASK(angle - angle_updates[i]);

            if (i != 0) {
                qq = qq_trial;
                ii = IMASK(ii_trial << 1);
            }
            else {
                word_t qq3 = qq;
                qq = CMASK(ii >> 1);
                ii = qq3 << 1;
                positive = !positive;
            }
        }
    }

    if (ROUNDOFF_BIT >= 0) {
        if (BIT(angle, ROUNDOFF_BIT & 31))
            angle += 1 << (ROUNDOFF_BIT & 31);
        angle &= ~MASK(ROUNDOFF_BIT & 31);
    }
    angle &= ~MASK(TRUNCATE_BIT);

    return angle;
}


static double error(word_t qq, word_t ii,
                    const int * angle_updates, double expect)
{
    unsigned got = phasedetect(qq, ii, angle_updates);
    double err = got - expect;
    if (err < -(1 << (OUT_BITS - 1)))
        err += 1 << OUT_BITS;
    else if (err > (1 << (OUT_BITS - 1)))
        err -= 1 << OUT_BITS;
    return err;
}


static double expect(double qq, double ii)
{
    return atan2(ii + 0.5, qq + 0.5) * ((2 << ANGLE_BITS) / M_PI);
}


static double terror(word_t qq, word_t ii, const int * angle_updates)
{
#define SSHIFT (sizeof(long) * 8 - IN_BITS)
    long sqq = ((long) qq << SSHIFT) >> SSHIFT;
    long sii = ((long) ii << SSHIFT) >> SSHIFT;
    assert(CMASK(sqq) == qq);
    assert(CMASK(sii) == ii);
    assert((sqq < 0) == CTOP(qq));
    assert((sii < 0) == CTOP(ii));
    return error(qq, ii, angle_updates, expect(sqq, sii));
}


#define MAIN_NUM 262144l
static long cos_table[MAIN_NUM];
static long sin_table[MAIN_NUM];
static double expect_table[MAIN_NUM];

#define smNUM 256
static long smcos_table[MAIN_NUM];
static long smsin_table[MAIN_NUM];
static double smexpect_table[MAIN_NUM];

static void build_main_table(void)
{
    for (int i = 0; i != MAIN_NUM; ++i) {
        double angle = 2 * M_PI / MAIN_NUM * (i + drand48());
        long qq = floor(cos(angle) * (1l << 32));
        long ii = floor(sin(angle) * (1l << 32));
        expect_table[i] = expect(qq, ii);
        cos_table[i] = CMASK(qq);
        sin_table[i] = CMASK(ii);
    }
    for (int i = 0; i != smNUM; ++i) {
        int j = i * (MAIN_NUM / smNUM) + rand() % (MAIN_NUM / smNUM);
        smcos_table[i] = cos_table[j];
        smsin_table[i] = sin_table[j];
        smexpect_table[i] = expect_table[j];
    }
}

static void build_angle_updates(int * angle_updates)
{
    //srand48(time(NULL));
    angle_updates[0] = MASK(ANGLE_BITS) + offset[0];
    for (int i = 1; i != ITERATIONS; ++i) {
        angle_updates[i] = AMASK(
            (int) round(atan2(1, 1 << i) * ((2 << ANGLE_BITS) / M_PI)));
        angle_updates[i] += offset[i];
    }
}

static void test_angles(const int * angle_updates, int tt)
{
    double var = 0;
    double sum = 0;
    // First try 256 items, for a quick test.
    for (int i = 0; i < smNUM; ++i) {
        double err = error(smcos_table[i], smsin_table[i], angle_updates,
                           smexpect_table[i]);
//        printf("%f\n", err);
        var += err * err;
        sum += err;
    }

    var = var / smNUM - sum * sum / (smNUM * smNUM);
    if (var > 1.6) {
        //printf("Q %i %.0f\n", tt, var * 1000000);
        return;
    }

    // Full test.
    double fvar = 0;
    sum = 0;
    for (int i = 0; i < MAIN_NUM; ++i) {
        double err = error(cos_table[i], sin_table[i], angle_updates,
                           expect_table[i]);
        fvar += err * err;
        sum += err;
    }

    long eights = 1;
    long oct = 0;
    for (int t = tt; t; t /= 3) {
        oct += eights * (t % 3);
        eights *= 8;
    }

    fvar = fvar / MAIN_NUM - sum * sum / (MAIN_NUM * MAIN_NUM);
    printf("S %016lo %f %f %f\n",
           oct, fvar, sqrt(fvar), fvar - var);
    fflush(stdout);
}

#define NUM_THREADS 4
static void * exhaustive_thread(void * p)
{
    int angle_updates[ITERATIONS];
    build_angle_updates(angle_updates);

    for (int i = (long) p; i < 81 * 81 * 81 * 81; i += NUM_THREADS) {
        // First update the updates.
        int j = 0;
        for (int m = i; m; m /= 3)
            angle_updates[j++] += ((m % 3) ^ 1) - 1;

        test_angles(angle_updates, i);

        j = 0;
        for (int m = i; m; m /= 3)
            angle_updates[j++] -= ((m % 3) ^ 1) - 1;
    }

    return NULL;
}


static int exhaustive(void)
{
    build_main_table();
    pthread_t th[NUM_THREADS];
    for (int i = 0; i < NUM_THREADS; ++i)
        pthread_create(&th[i], NULL, exhaustive_thread, (void*) (long) i);
    for (int i = 0; i < NUM_THREADS; ++i)
        pthread_join(th[i], NULL);
    return 0;
}


typedef struct enum_double {
    int index;
    double value;
} enum_double;


static int compare_enum_double(const void * AA, const void * BB)
{
    const enum_double * A = AA;
    const enum_double * B = BB;
    if (A->value < B->value)
        return 1;
    if (A->value > B->value)
        return -1;
    return 0;
}


static void print_angle(int i, int value)
{
    if (ANGLE_BITS % 4) {
        printf("\"");
        for (int i = ANGLE_BITS - 1; i / 4 == ANGLE_BITS / 4; --i)
            printf("%i", !!(value & (1 << i)));
        printf("\" & ");
    }
    printf("x\"%0*x\"", ANGLE_BITS / 4, value & (int) MASK(ANGLE_BITS & -4));

    if (i == 19)
        printf(");\n");
    else if (i % 4 == 3)
        printf(",\n     ");
    else
        printf(", ");
}


static int angle_table(void)
{
    int angle_updates[ITERATIONS];
    build_angle_updates(angle_updates);

    printf("  type angles_t is array(0 to 19) of unsigned%i;\n", ANGLE_BITS);
    printf("  constant angle_update : angles_t :=\n");
    printf("    (");
    for (int i = 0; i != ITERATIONS; ++i)
        print_angle(i, angle_updates[i]);
    for (int i = ITERATIONS; i < 20; ++i)
        print_angle(i, 0);

    return 0;
}


static inline double cnorm(_Complex double z)
{
    double re = creal(z);
    double im = cimag(z);
    return re * re + im * im;
}


static int circle(bool print)
{
    int angle_updates[ITERATIONS];
    build_angle_updates(angle_updates);

#define NUM (2048)
#define SNUM (NUM / 2 + 1)
    double var = 0;
    double mean = 0;

    static double errors[NUM];
    static complex spectrum[SNUM];
    fftw_plan plan = fftw_plan_dft_r2c_1d(NUM, errors, spectrum, 0);

    for (int i = 0; i != NUM; ++i) {
        double angle = (i + drand48()) * (2 * M_PI / NUM);
        assert (0 < angle && angle < 2 * M_PI);
        word_t qq = CMASK((long) floor(cos(angle) * (1l << 32)));
        word_t ii = CMASK((long) floor(sin(angle) * (1l << 32)));
        double err = terror(qq, ii, angle_updates);
        errors[i] = err;
        var += err * err;
        mean += err;
        if (print)
            printf("%5i % .2f\n", i, err);
    }

    mean /= NUM;
    var = var / NUM - mean * mean;
    fprintf(stderr, "Mean = %f, var = %f, std. dev. = %f\n",
            mean, var, sqrt(var));

    //fftw_execute_dft_r2c(plan, errors, spectrum);
    fftw_execute(plan);

    static enum_double power[SNUM];
    for (int i = 0; i != SNUM; ++i)
        power[i] = (enum_double) { i, cnorm(spectrum[i]) };

    qsort(power, SNUM, sizeof(enum_double), compare_enum_double);
    fprintf(stderr, "Harmonic Amplitude   Real      Imaginary\n");
    for (int i = 0; i != 10; ++i) {
        int index = power[i].index;
        fprintf(stderr, " %7i %8.4f%%  % f % f\n",
                index, sqrt(power[i].value) * (100.0 / NUM),
                creal(spectrum[index]),
                cimag(spectrum[index]));
    }
    fftw_destroy_plan(plan);
    fftw_cleanup();

    return 0;
}


// Check for grossly inaccurate result.
static void check(word_t x, word_t y, const int * angle_updates)
{
    double err = terror(x, y, angle_updates);
    assert(err >= -10);
    assert(err <= 10);
}


// Go around the outside of the square with max coords, and check for
// grossly inaccurate results (presumably due to overflows).
static int square(void)
{
    int angle_updates[ITERATIONS];
    build_angle_updates(angle_updates);

#define SQSIZE (1<<24)
    for (word_t i = -SQSIZE; i != SQSIZE; ++i) {
        word_t small = CMASK((i << (IN_BITS - 1)) / SQSIZE);
        word_t bigpos = (1ll << (IN_BITS - 1)) - 1;
        word_t bigneg = CMASK(~bigpos);
        check(small, bigpos, angle_updates);
        check(bigpos, small, angle_updates);
        check(small, bigneg, angle_updates);
        check(bigneg, small, angle_updates);
    }

    return 0;
}


int main(int argc, char * argv[])
{
    if (argc > 1 && strcmp(argv[1], "ex") == 0)
        return exhaustive();

    if (argc > 1 && strcmp(argv[1], "an") == 0)
        return angle_table();

    if (argc > 1 && strcmp(argv[1], "ta") == 0)
        return circle(true);

    if (argc > 1 && strcmp(argv[1], "sq") == 0)
        return square();

    return circle(false);
}
