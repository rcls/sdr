#include "lib/util.h"
#include "lib/usb.h"
#include "lib/registers.h"

#include <assert.h>
#include <complex.h>
#include <fftw3.h>
#include <stdarg.h>
#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>
#include <math.h>

static size_t size = 65536;

typedef struct sample_buffer_t {
    unsigned char * data;
    size_t data_len;
    const unsigned char * best;
} sample_buffer_t;


// size/4+1 coefficients for adjusting the spectrum for the frequency response.
static double * filter_adjust;


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


static void get_samples(sample_buffer_t * buffer, size_t required)
{
    size_t bytes = required * 4;
    if (bytes < USB_SLOP)
        bytes *= 2;
    else
        bytes += USB_SLOP;
    if (buffer->data_len < bytes) {
        buffer->data = xrealloc(buffer->data, bytes);
        buffer->data_len = bytes;
    }

    size_t amount = buffer->data_len;
    if (amount > bytes * 2)
        amount = bytes * 2;

    size_t best_len;
    for (int i = 0; i < 10; ++i) {
        // Start the sample output.
        usb_write_reg(REG_XMIT, XMIT_TURBO|XMIT_BANDPASS);

        usb_slurp(buffer->data, amount);

        usb_xmit_idle();
        usb_flush();

        buffer->best = buffer->data + 8192;
        size_t bytes = amount - 8192;
        best_len = best30(&buffer->best, &bytes);
        if (best_len >= required) {
            //buffer->best += 4 * (best_len - required);
            if (i != 0)
                fprintf(stderr, "\n");
            return;
        }
        fprintf(stderr, ".");
    }

    errx(1, "\nFailed to get good data (last = %zi, required = %zi).\n",
         best_len, required);
}


static void sample_config(int freq, int gain)
{
    usb_printf("bandpass %i %i\n", freq, gain);
    usb_echo();
}


static void gain_controlled_sample(
    int freq, int * gain, sample_buffer_t * buffer, size_t required)
{
    const int max_gain = 63;
    for (int i = 0; i < 10; ++i) {
        sample_config(freq, *gain);
        get_samples(buffer, required);

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
        if (incr == 0
            || (*gain == 0 && incr < 0)
            || (*gain == max_gain && incr > 0)) {
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


static void peak_remove(complex float * p)
{
    double total = 0;
    for (int i = 1; i != 16; ++i)
        total += cmodsq(p[i]) + cmodsq(p[-i]);
    if (total < cmodsq(*p))
        *p = 0;
}


static void get_spectrum(int gain, const unsigned char * data)
{
    static complex float * xfrm;        // size complex coefficients.
    static fftwf_plan plan;
    static float * buffer;              // size/2 real coefficients.
    if (!xfrm) {
        xfrm = fftwf_malloc (size * sizeof * xfrm);
        plan = fftwf_plan_dft_1d(size, xfrm, xfrm, FFTW_FORWARD, FFTW_ESTIMATE);
        buffer = xmalloc (size / 2 * sizeof * buffer);
    }
    // We frequency shift by nyquist.  This puts the data that we are interested
    // in in the middle of the transform, saving us from bothering about
    // wrap-around.
    for (int i = 0; i != size/2; ++i) {
        xfrm[2*i] = get_real(data) + I * get_imag(data);
        data += 4;
        xfrm[2*i+1] = - get_real(data) - I * get_imag(data);
        data += 4;
    }
    fftwf_execute(plan);
    // Knock out isolated peaks near 0 or +/- size/4.  We get these apparently
    // as subharmonics of the clock.
    peak_remove(xfrm + size/4);
    peak_remove(xfrm + size/2);
    peak_remove(xfrm + 3*size/4);
    // Now compute the powers, applying jaggedification corresponding to a
    // raised cosine window.
    double scale = exp2(gain * -0.5);
    for (int i = 0; i != size / 4; ++i) {
        int j = size/4 + i;
        buffer[i] = cmodsq(xfrm[j] - 0.5 * (xfrm[j-1] + xfrm[j+1]))
            * scale * filter_adjust[size/4 - i];
    }
    for (int i = 0; i != size / 4; ++i) {
        int j = size/2 + i;
        buffer[i + size/4] = cmodsq(xfrm[j] - 0.5 * (xfrm[j-1] + xfrm[j+1]))
            * scale * filter_adjust[i];
    }
    dump_file(1, buffer, size / 2 * sizeof * buffer);
}


static inline double invsinc(double x)
{
    return x / sin(x);
}


int main(int argc, const char ** argv)
{
    if (argc >= 2)
        size = strtoul(argv[1], NULL, 0);
    if (size <= 25)
        size = 1 << size;
    if (size <= 100)
        size *= 1024;
    fprintf(stderr, "Size = %zd\n", size);
    if (size & 3)
        errx(1, "Size must be a multiple of 4");

    // Build the coefficients to adjust for the frequency response of the
    // sampler bandpass filter.
    filter_adjust = xmalloc (size * sizeof * filter_adjust);
    filter_adjust[0] = 1;
    const double B = M_PI / 80 / size;
    for (int i = 1; i <= size/4; ++i) {
        double factor = invsinc(B * 65 * i) * invsinc(B * 74 * i)
            * invsinc(B * 87 * i) * invsinc(B * 99 * i) * invsinc(B * 106 * i);
        assert(fabs(factor) > 1);
        if (fabs(factor) >= 3)
            errx(1, "%i : %g\n", i, factor);
        assert(fabs(factor) < 3);
        filter_adjust[i] = factor * factor;
    }

    fftwf_init_threads();
    fftwf_plan_with_nthreads(4);

    usb_open();
    usb_xmit_idle();
    usb_echo();
    fprintf(stderr, "Usb open\n");

    // Reset the ADC.
    usb_write_reg(REG_ADC, ADC_RESET|ADC_SCLK|ADC_SEN);
    usb_write_reg(REG_ADC, ADC_SCLK|ADC_SEN);

    usb_flush();

    // Configure the ADC.  Turn down the gain for linearity.  Turn on offset
    // correction.
    adc_config(0,
               0x2510, // Gain.
               0x0303, 0x4a01, // Hi perf modes.
               0xcf00, 0x3de0, -1); // Offset correction as quick as possible.

    // Give the offset correction time to settle.
    usleep(200000);
    adc_config(0, 0xcf80, -1);        // Freeze offset correction.

    int gain = 48;
    sample_buffer_t buffer = { NULL, 0, NULL };
    for (int i = 1; i < 160; i += 2) {
        gain_controlled_sample(i, &gain, &buffer, size);
        get_spectrum(gain, buffer.best);
    }

    usb_write_reg(REG_BANDPASS_GAIN, 0); // Turn off the sampler unit.

    usb_close();

    return 0;
}
