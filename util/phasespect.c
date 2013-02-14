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
#define BUFFER_SIZE (FULL_LENGTH * 2)


static void load_samples(const unsigned char * buffer, double * samples)
{
    // Check for overrun flags.  Also chuck at least 4096 samples to let the
    // filters settle.
    int best = 4096;
    for (size_t i = 4097; i != FULL_LENGTH; ++i)
        if (buffer[2*i + 1] & 128) {
            fprintf(stderr, "Overrun at %zi\n", i);
            best = i;
        }

    if (FULL_LENGTH - best < LENGTH + 1)
        errx(1, "Only got %i, wanted %i\n", FULL_LENGTH - best, LENGTH + 1);

    const unsigned char * p = buffer + 2 * best;
    int last = p[0] + p[1] * 256;

    for (size_t i = 0; i != LENGTH; ++i) {
        p += 2;
        int this = p[0] + p[1] * 256;
        int delta = (this - last) & 32767;
        last = this;
        if (delta >= 16384)
            delta -= 32768;
        if (delta >= 12288 || delta <= -12288)
            fprintf(stderr, "Delta = %i at %zi\n", delta, i);
        samples[i] = delta;
    }
}


int main (int argc, const char ** argv)
{
    if (argc != 3)
        errx(1, "Usage: <freq> <filename>.");

    unsigned freq = strtoul(argv[1], NULL, 0);

    // Slurp a truckload of data.
    unsigned char * buffer = usb_slurp_channel(
        BUFFER_SIZE, XMIT_PHASE|1, freq, 0);

    double * samples = xmalloc(LENGTH * sizeof(double));
    load_samples(buffer, samples);
    free(buffer);

    float * output = spectrum(samples, LENGTH);
    free(samples);

    dump_path(argv[2], output, LENGTH / 2 * sizeof(float));
    free(output);

    return 0;
}
