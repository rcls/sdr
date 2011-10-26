#include <stdio.h>

#include "lib/util.h"

int main(void)
{
    unsigned char * buffer = NULL;
    size_t bufpos = 0;
    size_t bufsize = 0;

    slurp_file(0, &buffer, &bufpos, &bufsize);

    fprintf(stderr, "Read %zi bytes.\n", bufpos);

    const unsigned char * best = buffer;
    size_t bestsize = bufpos;

    size_t samples = best22(&best, &bestsize);

    fprintf(stderr, "Best is length %zu at offset %zu, giving %zu samples.\n",
            bestsize, best - buffer, samples);

    for (int i = 0; i < bestsize; i += 3) {
        int re = (best[i] & 0xfe) * 8 + (best[i+2] >> 4);
        int im = (best[i+1] & 0xfe) * 8 + (best[i+2] & 0xe)
            + ((best[i] ^ best[i+1] ^ best[i+2]) & 1);
        printf("%4i %4i\n", re, im);
    }

    return 0;
}
