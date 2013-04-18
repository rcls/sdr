// Analyse a (250MHz / 80) dump of the phase detector output.

#include <fcntl.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>

#include "lib/usb.h"
#include "lib/util.h"
#include "lib/registers.h"


static void load_samples(float * samples, const unsigned char * buffer,
                         size_t num_samples, size_t bytes)
{
    // Check for overrun flags.  Also chuck at least 4096 samples to let the
    // filters settle.
    buffer += 3 * 4096;
    size_t got = best_flag(&buffer, bytes - 3 * 4096, 3);
    if (got < num_samples)
        errx(1, "Only got %zi expected %zi.", got, num_samples);

    samples[0] = 0;              // The windowing kills the first sample anyway.
    int last = buffer[0] + buffer[1] * 256 + buffer[2] * 65536;

    for (size_t i = 1; i != num_samples; ++i) {
        int this = buffer[3*i] + buffer[3*i+1] * 256 + buffer[3*i+2] * 65536;
        int delta = (this - last) & 0x3ffff;
        last = this;
        if (delta >= 0x20000)
            delta -= 0x40000;
        if (delta >= 0x18000 || delta <= -0x18000)
            fprintf(stderr, "Delta = %i at %zi\n", delta, i);
        samples[i] = delta;
    }
}


int main (int argc, char * const argv[])
{
    // Slurp a truckload of data.
    size_t bytes;
    size_t num_samples = 22;
    unsigned char * buffer = slurp_getopt(
        argc, argv, SLURP_OPTS, NULL, XMIT_PHASE|1, &num_samples, &bytes);
    usb_close();

    float * samples = malloc(num_samples * sizeof * samples);
    load_samples(samples, buffer, num_samples, bytes);
    free(buffer);

    spectrum(optind < argc ? argv[optind] : NULL, samples, num_samples, false);
    free(samples);

    return 0;
}
