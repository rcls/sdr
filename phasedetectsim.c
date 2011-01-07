// Simulation of the phasedetect algorithm, for validating the accuracy etc.
#include <assert.h>
#include <math.h>
#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>

#define IN_BITS 36
#define OUT_BITS 19
#define ANGLE_BITS (OUT_BITS - 2)
#define ITERATIONS 16
#define ROUNDOFF_BIT 0
#define TRUNCATE_BIT 1

#define MASK(n) ((1l << (n)) - 1)
#define BIT(v, i) (!!((v) & (1l << (i))))

#define CMASK(v) ((v) & MASK(IN_BITS))
#define IMASK(v) ((v) & MASK(IN_BITS + 1))
#define AMASK(v) ((v) & MASK(OUT_BITS))

#define CTOP(v) BIT((v), IN_BITS - 1)
#define ITOP(v) BIT((v), IN_BITS)

typedef unsigned long word_t;
static const int offset[ITERATIONS] = { -1, 0, 0, 0, 0, 0, 0, 0, 0 };

static int angle_updates[ITERATIONS];

word_t phasedetect(word_t qq, word_t ii)
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

    if (BIT(angle, ROUNDOFF_BIT))
        angle += 1 << ROUNDOFF_BIT;
    angle &= ~MASK(ROUNDOFF_BIT);
    angle &= ~MASK(TRUNCATE_BIT);

    return angle;
}


static double error(word_t qq, word_t ii, double expect)
{
    unsigned got = phasedetect(qq, ii);
    double err = got - expect;
    if (err < -(1 << (OUT_BITS - 1)))
        err += 1 << OUT_BITS;
    else if (err > (1 << (OUT_BITS - 1)))
        err -= 1 << OUT_BITS;
    return err;
}


static double terror(word_t qq, word_t ii)
{
#define SSHIFT (sizeof(long) * 8 - IN_BITS)
    long sqq = ((long) qq << SSHIFT) >> SSHIFT;
    long sii = ((long) ii << SSHIFT) >> SSHIFT;
    assert(CMASK(sqq) == qq);
    assert(CMASK(sii) == ii);
    assert((sqq < 0) == CTOP(qq));
    assert((sii < 0) == CTOP(ii));
    double expect =
        atan2(sii + 0.5, sqq + 0.5) * ((2 << ANGLE_BITS) / M_PI) + 0.5;
    return error(qq, ii, expect);
}

#include <time.h>
int main(void)
{
    //srand48(time(NULL));
    angle_updates[0] = MASK(ANGLE_BITS) + offset[0];
    for (int i = 1; i != ITERATIONS; ++i) {
        angle_updates[i] = MASK(ANGLE_BITS)
            & (int) round(atan2(1, 1 << i) * ((2 << ANGLE_BITS) / M_PI));
        angle_updates[i] += offset[i];
    }

#define NUM 2048
    double errors[NUM];
    double sum = 0;
    for (int i = 0; i != NUM; ++i) {
        double angle = (i + drand48()) * (2 * M_PI / NUM);
        assert (0 < angle && angle < 2 * M_PI);
        word_t qq = CMASK((long) floor(cos(angle) * (1l << 32)));
        word_t ii = CMASK((long) floor(sin(angle) * (1l << 32)));
        errors[i] = terror(qq, ii);
        sum += errors[i];
        printf("%5i % .2f\n", i, errors[i]);
    }

    double mean = sum / NUM;
    double sumvar = 0;
    for (int i = 0; i != NUM; ++i) {
        double offset = errors[i] - mean;
        sumvar += offset * offset;
    }
    fprintf(stderr, "Mean = %f, var = %f, std. dev. = %f\n", mean,
            sumvar / NUM, sqrt(sumvar / NUM));
    return 0;
}
