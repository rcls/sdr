#include "lib/util.h"
#include "lib/usb.h"
#include "lib/registers.h"

#include <assert.h>
#include <complex.h>
#include <fftw3.h>
#include <stdarg.h>
#include <stdio.h>
#include <stdint.h>
#include <math.h>

#define SIZE (1<<22)

typedef struct sample_buffer_t {
    unsigned char * data;
    size_t data_len;
    const unsigned char * best;
    size_t best_len;
} sample_buffer_t;


static double filter_adjust[SIZE/4 + 1];


static inline int get_real(const unsigned char * p)
{
    int a = (p[1] & 127) * 256 + p[0];
    if (a < 16384)
        return a;
    else
        return a - 32768;
}


static inline int get_imag(const unsigned char * p)
{
    int a = (p[3] & 127) * 256 + p[2];
    if (a < 16384)
        return a;
    else
        return a - 32768;
}


static void get_samples(libusb_device_handle * dev,
                        sample_buffer_t * buffer, size_t required)
{
    size_t bytes = required * 4 + USB_SLOP;
    if (buffer->data_len < bytes) {
        buffer->data = xrealloc(buffer->data, bytes);
        buffer->data_len = bytes;
    }

    size_t amount = buffer->data_len;
    if (amount > bytes * 2)
        amount = bytes * 2;

    for (int i = 0; i < 10; ++i) {
        usb_slurp(dev, buffer->data, amount);
        buffer->best = buffer->data + 8192;
        size_t bytes = amount - 8192;
        buffer->best_len = best30(&buffer->best, &bytes);
        if (buffer->best_len >= required) {
            if (i != 0)
                fprintf(stderr, "\n");
            return;
        }
        fprintf(stderr, ".");
    }

    errx(1, "\nFailed to get good data (last = %zi, required = %zi).\n",
         buffer->best_len, required);
}


static void sample_config(libusb_device_handle * dev, int freq, int gain)
{
    unsigned char bytes[5];
    bytes[0] = REG_ADDRESS;
    bytes[1] = REG_SAMPLE_FREQ;
    bytes[2] = freq / 5 * 8 + freq % 5;
    bytes[3] = REG_SAMPLE_GAIN;
    bytes[4] = gain;
    usb_send_bytes(dev, bytes, 5);
}


static void adc_config(libusb_device_handle * dev, ...)
{
    va_list args;
    va_start(args, dev);
    unsigned char buffer[512];
    int len = 0;
    buffer[len++] = REG_ADDRESS;
    buffer[len++] = REG_ADC;
    buffer[len++] = ADC_SEN | ADC_SCLK;
    buffer[len++] = REG_ADC;
    buffer[len++] = ADC_SEN;
    while (1) {
        int w = va_arg(args, int);
        if (w < 0)
            break;
        if (len > sizeof(buffer) - 100)
            errx(1, "adc_config: too many args.\n");
        for (int i = 0; i < 16; ++i) {
            int b = (w << i) & 32768 ? ADC_SDATA : 0;
            buffer[len++] = REG_ADC;
            buffer[len++] = b | ADC_SCLK;
            buffer[len++] = REG_ADC;
            buffer[len++] = b;
        }
        buffer[len++] = REG_ADC;
        buffer[len++] = ADC_SEN | ADC_SCLK;
        buffer[len++] = REG_ADC;
        buffer[len++] = ADC_SEN;
    }
    va_end(args);
    usb_send_bytes(dev, buffer, len);
}


static void gain_controlled_sample(libusb_device_handle * dev,
                                   int freq, int * gain,
                                   sample_buffer_t * buffer,
                                   size_t required)
{
    const int max_gain = 63;
    for (int i = 0; i < 10; ++i) {
        sample_config(dev, freq, *gain | 0x80);
        get_samples(dev, buffer, required);

        const unsigned char * p = buffer->best;
        int64_t re_sum = 0;
        int64_t re_sumsq = 0;
        int64_t im_sum = 0;
        int64_t im_sumsq = 0;
        for (int i = 0; i != required; ++i, p += 4) {
            int re = get_real(p);
            int im = get_imag(p);
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
        int incr = floor(3 * (14 - log2(max_six)));
        if (incr == 0 || (incr >= -1 && incr <= 1 && i >= 8) ||
            (*gain == 0 && incr < 0)) {
            fprintf(stderr, "Freq %i choosing gain %i (6sd: %g). %g %g %g\n",
                    freq, *gain, max_six,
                    25.0 / 32 * (freq - 1),
                    25.0 / 32 * freq,
                    25.0 / 32 * (freq + 1));
            return;
        }
        if (incr < 0 && *gain <= 0)
            errx(1, "Too big %g (means %g,%g  sd %g,%g) with zero gain.\n",
                 max_six, re_mean, im_mean, re_sd, im_sd);
        if (incr > 0 && *gain >= max_gain)
            errx(1, "Too small %g with max gain.\n", max_six);
        if (incr < -3)
            incr = -16;

        fprintf(stderr, "   gain %i six sigma %g, adjustment = %i.\n",
                *gain, max_six, incr);

        *gain += incr;
        if (*gain < 0)
            *gain = 0;
        if (*gain > max_gain)
            *gain = max_gain;
    }
    errx(1, "Failed to converge...\n");
}


static double cmodsq(complex z)
{
    double r = creal(z);
    double i = cimag(z);
    return r * r + i * i;
}


static void get_spectrum(int gain, const unsigned char * data)
{
    static complex xfrm[SIZE];
    static fftw_plan plan;
    static float buffer[SIZE / 2];
    if (!plan)
        plan = fftw_plan_dft_1d(SIZE, xfrm, xfrm, FFTW_FORWARD, FFTW_ESTIMATE);
    for (int i = 0; i != SIZE; ++i) {
        xfrm[i] = (get_real(data) + I * get_imag(data) + 0.5 + 0.5 * I)
            * (1 - cos (2 * M_PI * i / SIZE));
        data += 4;
    }
    fftw_execute(plan);
    double scale = exp2(gain * -0.5);
    for (int i = 0; i != SIZE / 4; ++i)
        buffer[i] = cmodsq(xfrm[SIZE - SIZE/4 + i]) * scale
            * filter_adjust[SIZE/4 - i];
    for (int i = 0; i != SIZE / 4; ++i)
        buffer[i + SIZE/4] = cmodsq(xfrm[i]) * scale
            * filter_adjust[i];
    dump_file(1, buffer, sizeof(buffer));
}


static inline double invsinc(double x)
{
    return x / sin(x);
}

int main(void)
{
    filter_adjust[0] = 1;
    const double B = M_PI / 80 / SIZE;
    for (int i = 1; i <= SIZE/4; ++i) {
        double factor = invsinc(B * 65 * i) * invsinc(B * 74 * i)
            * invsinc(B * 87 * i) * invsinc(B * 99 * i) * invsinc(B * 106 * i);
        assert(fabs(factor) > 1);
        if (fabs(factor) >= 3)
            errx(1, "%i : %g\n", i, factor);
        assert(fabs(factor) < 3);
        filter_adjust[i] = factor * factor;
    }

    fftw_init_threads();
    fftw_plan_with_nthreads(4);

    libusb_device_handle * dev = usb_open();

    // Reset the ADC.
    static const unsigned char adc_reset[] = {
        REG_ADDRESS,
        REG_MAGIC, MAGIC_MAGIC, REG_XMIT, XMIT_FLASH,
        REG_ADC, ADC_RESET|ADC_SCLK|ADC_SEN,
        REG_ADC, ADC_SCLK|ADC_SEN };
    usb_send_bytes(dev, adc_reset, sizeof adc_reset);

    usb_flush(dev);

    // Start the sample output.
    static const unsigned char start[] = {
        REG_ADDRESS, REG_XMIT, XMIT_TURBO|XMIT_SAMPLE30 };
    usb_send_bytes(dev, start, sizeof start);

    // Configure the ADC.  Turn down the gain for linearity.  Turn on offset
    // correction.
    adc_config(dev,
               0x2510, // Gain.
               0x0303, 0x4a01, // Hi perf modes.
               0xcf00, 0x3de0, -1); // Offset correction as quick as possible.

    // Give the offset correction time to settle.
    usleep(200000);
    adc_config(dev, 0xcf80, -1);        // Freeze offset correction.

    int gain = 48;
    sample_buffer_t buffer = { NULL, 0, NULL, 0 };
    for (int i = 1; i < 160; i += 2) {
        gain_controlled_sample(dev, i, &gain, &buffer, SIZE);
        get_spectrum(gain, buffer.best);
    }

    // Turn off the sampler unit.
    sample_config(dev, 0, 0);

    usb_close(dev);

    return 0;
}
