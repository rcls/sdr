// Send commands to the ADS41B49.

// Hiperf mod-1: 0303, mode-2 4a01

// Gain: default is 2550, 2510 gives better linearity.

#include <libusb-1.0/libusb.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "lib/usb.h"
#include "lib/util.h"

#define ADC_RESET 8
#define ADC_SCLK 4
#define ADC_SDATA 2
#define ADC_SEN 1

#define BUFLEN 512
static unsigned char buffer[BUFLEN];
static int offset = 0;

static void putbyte(int c)
{
    if (offset >= BUFLEN)
        exprintf("Too long.\n");
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
    command_t mode = mode_unknown;
    for (int i = 1; i < argc; ++i) {
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
            for (int j = (rest - argv[i] - 2) & -2; j >= 0; j -= 2)
                putbyte(data >> j * 4);
            break;
        default:
            exprintf("Select mode.\n");
        }
    }

    libusb_device_handle * dev = usb_open();
    int transferred;
    if (libusb_bulk_transfer(dev, USB_OUT_EP, buffer, offset,
                             &transferred, 100) != 0
        || transferred != offset)
        exprintf("libusb_bulk_transfer failed.\n");
    usb_close(dev);

    return EXIT_SUCCESS;
}
