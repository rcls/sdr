// Analyse a (250MHz / 80 / 12) dump of the IR filter output.

#include <stdint.h>
#include <stdlib.h>

#include "lib/registers.h"
#include "lib/usb.h"
#include "lib/util.h"

#define LENGTH (1<<18)
#define FULL_LENGTH (LENGTH + 65536)
#define BUFFER_SIZE (FULL_LENGTH * 3)

static inline int get18(const unsigned char * p)
{
    int r = p[0] + p[1] * 256 + (p[2] & 3) * 65536;
    if (r & 131072)
        r -= 262144;
    return r;
}

static void load_samples(const unsigned char * buffer, float * samples)
{
    size_t start = 4096;                // Biff at least 4096 samples.
    for (size_t i = 4097; i != FULL_LENGTH; ++i)
        if ((buffer[i * 3 + 2]) & 128)
            start = i;

    if (FULL_LENGTH - start < LENGTH)
        errx(1, "Only got %zi out of required %i.",
             FULL_LENGTH - start, LENGTH);

    const unsigned char * p = buffer + 3 * start;

    for (int i = 0; i < LENGTH; ++i)
        samples[i] = get18(p + i * 3);
}


int main (int argc, const char ** argv)
{
    if (argc != 3)
        errx(1, "Usage: <freq> <filename>.");

    unsigned freq = strtoul(argv[1], NULL, 0);

    // Slurp a truckload of data.
    unsigned char * buffer = usb_slurp_channel(
        NULL, BUFFER_SIZE, XMIT_IR|1, freq, 0);

    float * samples = xmalloc(LENGTH * sizeof * samples);
    load_samples(buffer, samples);
    free(buffer);

    float * output = spectrum(samples, LENGTH);
    free(samples);

    dump_path(argv[2], output, LENGTH / 2 * sizeof(float));
    free(output);

    return 0;
}
