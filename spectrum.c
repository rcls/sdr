#include "lib/util.h"
#include "lib/usb.h"

#include <assert.h>
#include <stdarg.h>
#include <stdio.h>
#include <stdint.h>
#include <math.h>


typedef struct sample22_config_t {
    unsigned freq:7;
    unsigned table_select:3;
    unsigned shift:5;
    signed offset:18;
} sample22_config_t;


#define ADC_RESET 8
#define ADC_SCLK 4
#define ADC_SDATA 2
#define ADC_SEN 1

typedef struct sample_buffer_t {
    unsigned char * data;
    size_t data_len;
    const unsigned char * best;
    size_t best_len;
} sample_buffer_t;


static inline int get_real(const unsigned char * p)
{
    return (p[0] & 0xfe) * 8 + (p[2] >> 4);
}


static inline int get_imag(const unsigned char * p)
{
    return (p[1] & 0xfe) * 8 + (p[2] & 0xe) + ((p[0] ^ p[1] ^ p[2]) & 1);
}


static void get_samples(libusb_device_handle * dev,
                        sample_buffer_t * buffer, size_t required)
{
    size_t bytes = required * 3 + USB_SLOP;
    if (buffer->data_len < bytes) {
        buffer->data = xrealloc(buffer->data, bytes);
        buffer->data_len = bytes;
    }

    size_t amount = buffer->data_len;
    if (amount > bytes * 2)
        amount = bytes * 2;

    for (int i = 0; i < 10; ++i) {
        usb_slurp(dev, buffer->data, amount);
        buffer->best = buffer->data;
        size_t bytes = amount;
        buffer->best_len = best22(&buffer->best, &bytes);
        if (buffer->best_len >= required) {
            if (i != 0)
                fprintf(stderr, "\n");
            return;
        }
        fprintf(stderr, ".");
    }

    exprintf("\nFailed to get good data (last = %zi, required = %zi).\n",
             buffer->best_len, required);
}


static void sample_config(libusb_device_handle * dev,
                          const sample22_config_t * config)
{
    unsigned char bytes[8];
    bytes[0] = ADC_SEN | ADC_SCLK;
    unsigned freq = config->freq / 15 * 16 + config->freq % 15;
    bytes[1] = 32 + (freq & 31);
    bytes[2] = 64 + (freq >> 5) + config->table_select * 4;
    bytes[3] = 96 + config->shift;
    bytes[4] = 128 + (config->offset & 31);
    bytes[5] = 160 + ((config->offset >> 5) & 31);
    bytes[6] = 192 + ((config->offset >> 10) & 31);
    bytes[7] = 224 + ((config->offset >> 15) & 31);
    // for (int i = 0; i != 8; ++i)
    //     printf(" %02x", bytes[i]);
    // printf("\n");
    usb_send_bytes(dev, bytes, 8);
}


static void adc_bitbang(libusb_device_handle * dev, ...)
{
    va_list args;
    va_start(args, dev);
    unsigned char buffer[512];
    int len = 0;
    while (1) {
        int b = va_arg(args, int);
        if (b < 0)
            break;
        if (len >= 512)
            exprintf("adc_bitbang: too many args.\n");
        buffer[len++] = b;
    }
    va_end(args);
    usb_send_bytes(dev, buffer, len);
}


static void adc_config(libusb_device_handle * dev, ...)
{
    va_list args;
    va_start(args, dev);
    unsigned char buffer[512];
    int len = 0;
    buffer[len++] = ADC_SEN | ADC_SCLK;
    buffer[len++] = ADC_SEN;
    while (1) {
        int w = va_arg(args, int);
        if (w < 0)
            break;
        if (len > 512 - 34)
            exprintf("adc_config: too many args.\n");
        for (int i = 0; i < 16; ++i) {
            int b = (w << i) & 32768 ? ADC_SDATA : 0;
            buffer[len++] = b | ADC_SCLK;
            buffer[len++] = b;
        }
        buffer[len++] = ADC_SEN | ADC_SCLK;
        buffer[len++] = ADC_SEN;
    }
    va_end(args);
    usb_send_bytes(dev, buffer, len);
}


static void gain_controlled_sample(libusb_device_handle * dev,
                                   sample22_config_t * config,
                                   sample_buffer_t * buffer,
                                   size_t required)
{
    int gain = config->shift * 4 + config->table_select;
    for (int i = 0; i < 10; ++i) {
        sample_config(dev, config);
        get_samples(dev, buffer, required);

        const unsigned char * p = buffer->best;
        int64_t re_sum = 0;
        int64_t re_sumsq = 0;
        int64_t im_sum = 0;
        int64_t im_sumsq = 0;
        for (int i = 0; i != required; ++i, p += 3) {
            int re = get_real(p);
            int im = get_real(p);
            if (re >= 1024)
                re -= 2048;
            if (im >= 1024)
                im -= 2048;
            re_sum += re;
            re_sumsq += re * re;
            im_sum += im;
            im_sumsq += im * im;
        }
        double re_mean = re_sum / (double) required;
        double im_mean = im_sum / (double) required;
        double re_sd = sqrt(re_sumsq / (double) required - re_mean * re_mean);
        double im_sd = sqrt(im_sumsq / (double) required - im_mean * im_mean);
        double re_six = fabs(re_mean) + 6 * re_sd;
        double im_six = fabs(im_mean) + 6 * im_sd;

        double max_six = re_six >= im_six ? re_six : im_six;
        if (max_six < 1)
            max_six = 1;
        int incr = floor(3 * (10 - log2(max_six)));
        if (incr == 0) {
            fprintf(stderr, "Choosing gain %i (6sd: %g).\n", gain, max_six);
            return;
        }
        if (incr < 0 && gain <= 0)
            exprintf("Too big %g with zero gain.\n", max_six);
        if (incr > 0 && gain >= 131)
            exprintf("Too small %g with max gain.\n", max_six);
        if (incr < -2)
            incr = -32;

        fprintf(stderr, "Gain %i six sigma %g, adjustment = %i.\n",
                gain, max_six, incr);

        gain += incr;
        if (gain < 0)
            gain = 0;
        if (gain > 131)
            gain = 131;

        if (gain < 4) {
            config->table_select = gain;
            config->shift = 0;
        }
        else {
            config->table_select = 4 + (gain & 3);
            config->shift = (gain - config->table_select) >> 2;
        }
    }
}


int main(void)
{
    libusb_device_handle * dev = usb_open();

    // Reset the ADC.
    adc_bitbang(dev, ADC_RESET|ADC_SCLK|ADC_SEN, ADC_SCLK|ADC_SEN, -1);

    // Reset the sample registers.  We start with max gain on the trig table,
    // and no gain on the shifter.
    sample22_config_t config = {
        .freq = 50, .table_select = 7, .shift = 12, .offset = 0x2000 };
    sample_config(dev, &config);

    // Configure the ADC.  Turn down the gain for linearity.  Turn on offset
    // correction.
    adc_config(dev,
               0x2510, // Gain.
               0x0303, 0x4a01, // Hi perf modes.
               0xcf00, 0x3de0, -1); // Offset correction as quick as possible.

    // Give the offset correction time to settle.
    usleep(200000);
    adc_config(dev, 0xcf80, -1);        // Freeze offset correction.

    sample_buffer_t buffer = { NULL, 0, NULL, 0 };
    gain_controlled_sample(dev, &config, &buffer, 1<<22);

    return 0;
}
