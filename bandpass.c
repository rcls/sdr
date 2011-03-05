#include <assert.h>
#include <complex.h>
#include <math.h>
#include <stdio.h>

typedef struct filter_t {
    // Inline series.
    double r1;
    double c1;
    double l1;
    // Parallel to ground.
    double r2;
    double c2;
    double l2;
} filter_t;

static complex series_impedance(const filter_t * f, double omega)
{
    return f->r1 - I/(f->c1 * omega) + f->l1 * omega * I;
}

static complex parallel_impedance(const filter_t * f, double omega)
{
    double zr = f->r2;
    double zl = f->l2 * omega;
    double cc = f->c2 * omega;

    return zr * zl * I / (zr - zr*cc*zl + zl * I);
}

static inline double cnorm(_Complex double z)
{
    double re = creal(z);
    double im = cimag(z);
    return re * re + im * im;
}

static double power_response(const filter_t * f, double omega)
{
    complex ss = series_impedance(f, omega);
    complex pp = parallel_impedance(f, omega);

    return cnorm(pp) / cnorm(ss+pp);
}


// Find the peak power response.  Return omega, and fill in power.
// Returns zero if things are out of whack.
static double power_response_peak(const filter_t * f, double * power)
{
    double low_omega = 1e7;
    double big_omega = 5 * 1e9;
    double mid_omega = (low_omega + big_omega) * 0.5;

    double low_power = power_response(f, low_omega);
    double mid_power = power_response(f, mid_omega);
    double big_power = power_response(f, big_omega);

    if (mid_power <= low_power || mid_power <= big_power) {
        *power = 0;
        return 0;
    }

    while (low_power < mid_power && big_power < mid_power) {
        double lm_omega = (low_omega + mid_omega) * 0.5;
        double mb_omega = (mid_omega + big_omega) * 0.5;
        double lm_power = power_response(f, lm_omega);
        double mb_power = power_response(f, mb_omega);
        if (lm_power > mid_power) {
            if (mb_power > mid_power)
                // Wierdness.
                break;

            big_omega = mid_omega;
            big_power = mid_power;
            mid_omega = lm_omega;
            mid_power = lm_power;
        }
        else if (mb_power > mid_power) {
            low_omega = mid_omega;
            low_power = mid_power;
            mid_omega = mb_omega;
            mid_power = mb_power;
        }
        else if (low_power != lm_power || big_power != mb_power) {
            low_omega = lm_omega;
            low_power = lm_power;
            big_omega = mb_omega;
            big_power = mb_power;
        }
        else
            break;                      // Done...
    }

    assert(low_omega <= mid_omega);
    assert(mid_omega <= big_omega);
    assert(big_omega - mid_omega < 1);
    assert(mid_omega - low_omega < 1);

    *power = mid_power;
    return mid_omega;
}


static double low_3db(const filter_t * filter,
                      double peak_omega, double peak_power)
{
    double low_omega = 1e7;
    double big_omega = peak_omega;
    double target_power = peak_power * 0.5;

    while (low_omega < big_omega) {
        double mid_omega = (low_omega + big_omega) * 0.5;
        double mid_power = power_response(filter, mid_omega);

        if (mid_power < target_power && low_omega != mid_omega)
            low_omega = mid_omega;
        else if (mid_power >= target_power && mid_omega != big_omega)
            big_omega = mid_omega;
        else
            break;
    }

    assert(low_omega <= big_omega);
    assert(big_omega - low_omega < 0.5);

    return big_omega;
}


static double high_3db(const filter_t * filter,
                       double peak_omega, double peak_power)
{
    double low_omega = peak_omega;
    double big_omega = 5e9;
    double target_power = peak_power * 0.5;

    while (low_omega < big_omega) {
        double mid_omega = (low_omega + big_omega) * 0.5;
        double mid_power = power_response(filter, mid_omega);

        if (mid_power > target_power && low_omega != mid_omega)
            low_omega = mid_omega;
        else if (mid_power <= target_power && mid_omega != big_omega)
            big_omega = mid_omega;
        else
            break;
    }

    assert(low_omega <= big_omega);
    assert(big_omega - low_omega < 0.5);

    return big_omega;
}

#define MHZ (2e6 * M_PI)

int main()
{
    filter_t f = { 50, 7.5e-9, 112e-9, 50, 100e-12, 8.2e-9 };

    double peak_power;
    double peak_omega = power_response_peak(&f, &peak_power);

    printf("At %f MHz, %f\n",
           peak_omega / MHZ, peak_power);
    double low3db = low_3db(&f, peak_omega, peak_power);
    double high3db = high_3db(&f, peak_omega, peak_power);
    printf("3db range %f MHz to %f MHz\n",
           low3db / MHZ, high3db / MHZ);

    for (double freq = 10; freq < 1000; freq *= 1.1) {
        printf("%f,%f\n",
               freq,
               power_response(&f, freq * MHZ));
    }

    return 0;
}
