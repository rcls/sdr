#include <stdio.h>

#include "lib/util.h"

int main()
{
    unsigned char * buffer = NULL;
    size_t bufpos = 0;
    size_t bufsize = 0;

    slurp_file(0, &buffer, &bufpos, &bufsize);

    fprintf(stderr, "Read %zi bytes.\n", bufpos);

    const unsigned char * best = buffer;
    size_t bestsize = bufpos;

    size_t samples = best14(&best, &bestsize);

    fprintf(stderr, "Best is length %zu at offset %zu, giving %zu samples.\n",
            bestsize, best - buffer, samples);

    for (int i = 0; i < bestsize; i += 2)
        printf("%4i\n", best[i] + (best[i+1] & 0x3f) * 256);

    return 0;
}
