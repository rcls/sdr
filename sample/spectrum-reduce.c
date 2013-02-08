
#include <stdlib.h>
#include <fcntl.h>

#include "lib/util.h"


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
    if (argc != 4)
        errx(1, "Arguments <in> <out> <order>");

    int order = strtol(argv[3], NULL, 0);
    if (order < 1 || order > 20)
        errx(1, "Order should be between 1 and 20.");

    size_t stride = 1 << order;

    unsigned char * buffer= NULL;
    size_t bytes = 0;
    size_t size = 0;
    slurp_path(argv[1], &buffer, &bytes, &size);
    float * input = (float *) buffer;
    size_t count = bytes / sizeof(float) / stride;
    float * output = xmalloc(count * sizeof(float));

    // Knock out isolated peaks near powers of two...
    for (size_t i = 1<<20; i < bytes / sizeof(float); i += 1<<20) {
        double below = max(input + i - 16, 16);
        double above = max(input + i + 1, 16);
        double big = above > below ? above : below;
        if (input[i] > big * 10)
            input[i] = big;
    }

    for (size_t i = 0; i != count; ++i)
        output[i] = sum(input + i * stride, order) / stride;

    int out = checki(open(argv[2], O_WRONLY), "open output");
    dump_file(out, output, count * sizeof(float));
    checki(close(out), "close output");
    return 0;
}
