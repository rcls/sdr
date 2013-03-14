// Analyse a (250MHz / 240) dump of the phase detector output.

#include <fcntl.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>

#include "lib/usb.h"
#include "lib/util.h"
#include "lib/registers.h"

#define LENGTH (1<<22)
#define FULL_LENGTH (LENGTH + 65536)
#define BUFFER_SIZE (FULL_LENGTH * 3)


static void load_samples(const unsigned char * buffer, float * samples)
{
    // Check for overrun flags.  Also chuck at least 4096 samples to let the
    // filters settle.
    int best = 4096;
    for (size_t i = 4097; i != FULL_LENGTH; ++i)
        if (buffer[3*i + 2] & 128) {
            fprintf(stderr, "Overrun at %zi\n", i);
            best = i;
        }

    if (FULL_LENGTH - best < LENGTH + 1)
        errx(1, "Only got %i, wanted %i\n", FULL_LENGTH - best, LENGTH + 1);

    const unsigned char * p = buffer + 3 * best;
    int last = p[0] + p[1] * 256 + p[2] * 65536;

    for (size_t i = 0; i != LENGTH; ++i) {
        p += 3;
        int this = p[0] + p[1] * 256 + p[2] * 65536;
        int delta = (this - last) & 0x3ffff;
        last = this;
        if (delta >= 0x20000)
            delta -= 0x40000;
        if (delta >= 0x18000 || delta <= -0x18000)
            fprintf(stderr, "Delta = %i at %zi\n", delta, i);
        samples[i] = delta;
    }
}


int main (int argc, const char ** argv)
{
    if (argc != 3)
        errx(1, "Usage: <freq> <filename>.");

    char * dag;
    unsigned freq = strtoul(argv[1], &dag, 0);
    if (*dag)
        errx(1, "Usage: <freq> <filename>.");

    // Slurp a truckload of data.
    unsigned char * buffer = usb_slurp_channel(
        BUFFER_SIZE, XMIT_PHASE|1, freq, 0);
    usb_close();

    float * samples = malloc(LENGTH * sizeof * samples);
    load_samples(buffer, samples);
    free(buffer);

    spectrum(argv[2], samples, LENGTH, false);
    free(samples);

    return 0;
}
