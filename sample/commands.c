// Send commands to the ADS41B49.

// Hiperf mod-1: 0303, mode-2 4a01

// Gain: default is 2550, 2510 gives better linearity.

#include <err.h>
#include <libusb-1.0/libusb.h>
#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "lib/usb.h"
#include "lib/util.h"
#include "lib/registers.h"

#define BUFLEN 512
static unsigned char buffer[BUFLEN];
static int offset = 0;

static void addressed_transfer(libusb_device_handle * dev,
                               const unsigned char * buffer, int len)
{
    unsigned char bytes[len * 2 + 1];
    bytes[0] = REG_ADDRESS;
    for (int i = 0; i != len; ++i) {
        bytes[i * 2 + 1] = REG_ADC;
        bytes[i * 2 + 2] = buffer[i];
    }
    usb_send_bytes(dev, bytes, len * 2 + 1);
}

static void putbyte(int c)
{
    if (offset >= BUFLEN)
        errx(1, "Too long.\n");
    buffer[offset++] = c;
}


static void adc_bit(int c)
{
    // First with clk high, then with clock low...
    putbyte(c | ADC_SCLK);
    putbyte(c & ~ADC_SCLK);
}

static void adc_data(unsigned long long data, int bits)
{
    for (int i = bits; i-- > 0;)
        adc_bit((data & (1ull << i)) ? ADC_SDATA : 0);
}

static void adc_cordon(void)
{
    adc_bit(ADC_SEN);
}

static void adc_reset(void)
{
    putbyte(ADC_RESET | ADC_SCLK | ADC_SEN);
    putbyte(ADC_SCLK | ADC_SEN);
}

typedef enum command_t {
    mode_unknown,
    mode_adc,
    mode_raw
} command_t;


int main(int argc, const char * const * argv)
{
    bool direct = false;
    command_t mode = mode_unknown;
    for (int i = 1; i < argc; ++i) {
        if (strcmp(argv[i], "direct") == 0) {
            direct = true;
            continue;
        }

        if (strcmp(argv[i], "adc_reset") == 0) {
            adc_reset();
            continue;
        }

        if (strcmp(argv[i], "adc") == 0) {
            mode = mode_adc;
            continue;
        }

        if (strcmp(argv[i], "raw") == 0) {
            mode = mode_raw;
            continue;
        }

        char * rest = NULL;
        unsigned long long data = strtoull(argv[i], &rest, 16);
        if (rest == NULL || *rest) {
            fprintf(stderr, "Failed to parse arg %i\n", i);
            return EXIT_FAILURE;
        }
        switch (mode) {
        case mode_adc:
            adc_cordon();
            adc_data(data, 4 * (rest - argv[i]));
            adc_cordon();
            break;
        case mode_raw:
            // Little endian...
            for (int j = 0; j < rest - argv[i]; j += 2)
                putbyte(data >> j * 4);
            break;
        default:
            errx(1, "Select mode.\n");
        }
    }

    libusb_device_handle * dev = usb_open();
    fprintf(stderr, "%u bytes to do...\n", offset);
    for (int i = 0; i != offset; ++i)
        fprintf(stderr, " %02x", buffer[i]);
    fprintf(stderr, "\n");
    if (direct)
        usb_send_bytes(dev, buffer, offset);
    else
        addressed_transfer(dev, buffer, offset);
    usb_close(dev);

    return EXIT_SUCCESS;
}
