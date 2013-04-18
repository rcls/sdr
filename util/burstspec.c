// Analyse a burst capture.

#include <stdint.h>
#include <stdlib.h>
#include <string.h>

#include "lib/registers.h"
#include "lib/usb.h"
#include "lib/util.h"

#define BURST_SIZE 2048

static inline int get14(const unsigned char * p)
{
    int r = (p[0] + p[1] * 256) & 0x3fff;
    if (r & 0x2000)
        r -= 0x4000;
    return r;
}


static void load_samples(float * samples, const unsigned char * buffer,
                         size_t num_samples)
{
    const unsigned char * p = buffer + num_samples * 2 - BURST_SIZE * 4;
    if (memcmp(p, p + BURST_SIZE * 2, BURST_SIZE * 2) != 0)
        errx(1, "Copies do not match.");

    for (int i = 0; i < BURST_SIZE; ++i)
        samples[i] = get14(p + 2 * i);
}


int main (int argc, char * const argv[])
{
    // Slurp a truckload of data.
    usb_open();

    usb_write_reg(REG_FLASH, 0x0f);
    usb_write_reg(REG_FLASH, 0x4f);
    usb_write_reg(REG_FLASH, 0x0f);

    size_t num_samples = BURST_SIZE * 2;
    size_t bytes;
    unsigned char * buffer = slurp_getopt(
        argc, argv, SLURP_OPTS, NULL, XMIT_BURST, &num_samples, &bytes);
    usb_close();

    const unsigned char * best = buffer;
    best_flag(&best, BURST_SIZE * 2, bytes, 2);

    float * samples = xmalloc(BURST_SIZE * sizeof * samples);
    load_samples(samples, best, num_samples);
    free(buffer);

    spectrum(optind < argc ? argv[optind] : NULL, samples, BURST_SIZE, false);
    free(samples);

    return 0;
}
