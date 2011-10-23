
#include <stdlib.h>

#include "lib/util.h"

// sum 1 to 1<<n of 1/n.
double harmonics[21] = {
    1,
    1.5,
    2.083333333333333,
    2.7178571428571425,
    3.3807289932289928,
    4.05849519543652,
    4.7438909037057684,
    5.4331470925891718,
    6.124344962817279,
    6.816516534549721,
    7.5091756722781309,
    8.2020787718177157,
    8.8951038969663205,
    9.5881900460953062,
    10.281306710008447,
    10.974438632012157,
    11.667578183235779,
    12.360721549113009,
    13.053866822327958,
    13.747013049214495,
    14.440159752937513,
};


double sum(const float * restrict p, int order)
{
    switch (order) {
    case 0:
        return p[0];
    case 1:
        return p[0] + p[1];
    case 2:
        return (p[0] + p[1]) + (p[2] + p[3]);
    default:
        order -= 1;
        return sum(p, order) + sum(p + (1 << order), order);
    }
}


double max(const float * restrict p, int count)
{
    double m = *p;
    for (int i = 1; i < count; ++i)
        if (p[i] > m)
            m = p[i];
    return m;
}


int main(int argc, const char * const * argv)
{
    if (argc < 2)
        exprintf("Order?\n");

    int order = strtol(argv[1], NULL, 0);
    if (order < 1 || order > 20)
        exprintf("Order should be between 1 and 20.\n");

    size_t stride = 1 << order;

    unsigned char * buffer= NULL;
    size_t bytes = 0;
    size_t size = 0;
    slurp_file(0, &buffer, &bytes, &size);
    float * input = (float *) buffer;
    size_t count = bytes / sizeof(float) / stride;
    float * output = xmalloc(count * 2 * sizeof(float));

    // Knock out isolated peaks near powers of two...
    for (size_t i = 1<<20; i < bytes / sizeof(float); i += 1<<20) {
        double below = max(input + i - 16, 16);
        double above = max(input + i + 1, 16);
        double big = above > below ? above : below;
        if (input[i] > big * 10)
            input[i] = big;
    }

    for (size_t i = 0; i != count; ++i) {
        output[i*2] = sum(input + i * stride, order) / stride;
        output[i*2+1] = max(input + i * stride, stride) / harmonics[order];
    }

    dump_file(1, output, count * 2 * sizeof(float));
    return 0;
#if 0
    for (int i = 0; i <= 20; ++i)
        printf("%.17g,\n", harmonic(1, 1 << i));
    for (int i = 0; i <= 20; ++i)
        printf("%g\n", harmonic(1, 1 << i) - harmonics[i]);
    return 0;
#endif
}
