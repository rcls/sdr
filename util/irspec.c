// Analyse a (250MHz / 80 / 12) dump of the IR filter output.

#include <stdint.h>
#include <stdlib.h>

#include "lib/registers.h"
#include "lib/usb.h"
#include "lib/util.h"

static inline int get18(const unsigned char * p)
{
    int r = p[0] + p[1] * 256 + (p[2] & 3) * 65536;
    if (r & 131072)
        r -= 262144;
    return r;
}

static void load_samples(float * samples, const unsigned char * buffer,
                         size_t bytes, size_t num_samples)
{
    const unsigned char * best = buffer + 4096 * 3;
    best_flag(&best, num_samples, bytes - 4096 - 3, 3);

    for (size_t i = 0; i < num_samples; ++i)
        samples[i] = get18(best + i * 3);
}


int main (int argc, char * const argv[])
{
    // Slurp a truckload of data.
    size_t bytes;
    size_t num_samples = 22;
    unsigned char * buffer = slurp_getopt(
        argc, argv, SLURP_OPTS, NULL, XMIT_IR|1, &num_samples, &bytes);

    float * samples = xmalloc(num_samples * sizeof * samples);
    load_samples(samples, buffer, bytes, num_samples);
    free(buffer);

    spectrum(optind < argc ? argv[optind] : NULL, samples, num_samples, false);
    free(samples);

    return 0;
}
