// Analyse a (250MHz / 240) dump of the phase detector output.

#include <fcntl.h>
#include <fftw3.h>
#include <stdlib.h>
#include <unistd.h>

#include "lib/usb.h"
#include "lib/util.h"
#include "lib/registers.h"

#define LENGTH (1<<22)
#define FULL_LENGTH (LENGTH + 65536)
#define BUFFER_SIZE (FULL_LENGTH * 2)

static inline unsigned get16(const unsigned char * p)
{
    return p[0] + p[1] * 256;
}

static void load_samples(const unsigned char * buffer, double * samples)
{
    // Check for overrun flags.  Also chuck at least 4096 samples to let the
    // filters settle.
    int best = 0;
    for (int i = 0; i != FULL_LENGTH; ++i)
        if (buffer[2*i + 1] & 128) {
            fprintf(stderr, "Overrun at %i\n", i);
            best = i;
        }

    if (FULL_LENGTH - best < LENGTH + 4096)
        errx(1, "Only got %i, wanted %i\n", FULL_LENGTH - best, LENGTH + 4096);

    const unsigned char * p = buffer + 2 * (best - 4096);
    int last = get16(p);

    for (int i = 0; i != LENGTH; ++i) {
        p += 2;
        int this = get16(p);
        int delta = (this - last) & 32767;
        last = this;
        if (delta >= 16384)
            delta -= 32768;
        if (delta >= 12288 || delta <= -12288)
            fprintf(stderr, "Delta = %i at %i\n", delta, i);
        samples[i] = delta;
    }
}


int main (int argc, const char ** argv)
{
    if (argc != 3)
        errx(1, "Usage: <freq> <filename>.");

    unsigned long long freq = strtoull(argv[1], NULL, 0);
    freq = freq * 16777216 / 250000;

    libusb_device_handle * dev = usb_open();

    // First turn off output & select channel...
    static unsigned char off[] = {
        REG_ADDRESS, REG_MAGIC, MAGIC_MAGIC,
        REG_XMIT, 0x08,
        REG_RADIO_FREQ(1) + 0, 0xff,
        REG_RADIO_FREQ(1) + 1, 0xff,
        REG_RADIO_FREQ(1) + 2, 0xff,
        REG_RADIO_GAIN(1), 0x80 };
    off[sizeof off - 3] = freq >> 16;
    off[sizeof off - 5] = freq >> 8;
    off[sizeof off - 7] = freq;

    usb_send_bytes(dev, off, sizeof off);
    // Flush usb...
    usb_flush(dev);
    // Turn on phase data, channel 1.
    static const unsigned char on[] = { REG_ADDRESS, REG_XMIT, 0x0d };
    usb_send_bytes(dev, on, sizeof on);

    // Slurp a truckload of data.
    static unsigned char buffer[BUFFER_SIZE];
    usb_slurp(dev, buffer, sizeof buffer);

    // Turn off data.  Turn off the channel.
    off[sizeof off - 1] = 0;
    usb_send_bytes(dev, off, sizeof off);
    // Flush usb...
    usb_flush(dev);
    // Grab a couple of bytes to reset the overrun flag.
    static const unsigned char flip[] = {
        REG_ADDRESS, REG_FLASH, 0x0f, REG_FLASH, 0x07 };
    usb_send_bytes(dev, flip, sizeof flip);
    // Flush usb...
    usb_flush(dev);

    usb_close(dev);

    static double samples[LENGTH];

    load_samples(buffer, samples);

    fftw_plan_with_nthreads(4);
    fftw_plan plan = fftw_plan_r2r_1d(
        LENGTH, samples, samples, FFTW_R2HC, FFTW_ESTIMATE);
    fftw_execute(plan);
    fftw_destroy_plan(plan);

    static float output[LENGTH/2];

    output[0] = 0;                      // Not interesting.
    for (size_t i = 1; i < LENGTH/2; ++i)
        output[i] = samples[i] * samples[i]
            + samples[LENGTH - i] * samples[LENGTH - i];

    int outfile = checki(open(argv[2], O_WRONLY|O_CREAT|O_TRUNC, 0666),
                         "opening output");
    dump_file(outfile, output, LENGTH / 2 * sizeof(float));
    checki(close(outfile), "closing output");

    return 0;
}
