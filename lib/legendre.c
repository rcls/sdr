// Fit a Polynomial to a sequence of (x,y) data with a polynomial.
// Instead of computing appropriate orthogonal polynomials, we just use Legendre
// polynomials and iterate; we will have many data points and lowish order, so
// the finite sums should be close enough to the integrals to make things
// converge ok.

#include "legendre.h"
#include <string.h>

#include <stdio.h>
static double legendre(double x, unsigned int order)
{
    if (order == 0)
        return 1;
    double prev = 1;
    double current = x;
    for (unsigned int n = 1; n < order; ++n) {
        double next = ((2*n+1) * x * current - n * prev) / (n + 1);
        prev = current;
        current = next;
    }
    //printf ("P_%i(%g)=%g\n", order, x, current);
    return current;
}


double l_eval(double x, const double * coeffs, unsigned int order)
{
    double result = *coeffs++;
    if (order == 0)
        return result;
    double prev = 1;
    double current = x;
    for (unsigned int n = 1; n < order; ++n) {
        result += current * *coeffs++;
        double next = ((2*n+1) * x * current - n * prev) / (n + 1);
        prev = current;
        current = next;
    }
    return result + current * *coeffs;
}


// Coefficients of X**power in P_order.  Fill in a (order+1)^2 sized array,
// coeffs of the same poly are contiguous.
static void l_coeff(double * CC, unsigned int order,
                    double CENTER, double WIDTH)
{
    CC[0] = 1;
    unsigned int size = (order + 1) * (order + 1);
    for (unsigned int i = 1; i < size; ++i)
        CC[i] = 0;

    if (order == 0)
        return;

    CC[order] = -CENTER/WIDTH;
    CC[order + 1] = 1 / WIDTH;

    double * prev = CC;
    double * current = CC + order+1;
    for (int n = 1; n < order; ++n) {
        double * next = current + order+1;
        next[0] = n * prev[0] / (n + 1);
        for (int i = 0; i < n; ++i)
            next[i+1] = ((2*n+1) * current[i] + prev[i+1]) / (n + 1);
        prev = current;
        current = next;
    }
}


static double l_norm_sq (int len, unsigned int order)
{
    double sum = 0;
    double M = M(len);
    double C = C(len);
    for (unsigned int i = 0; i != len; ++i) {
        double l = legendre(M * i + C, order);
        sum += l * l;
    }
    return sum;
}


static double inner_pr(const double * Y, unsigned int len, unsigned int order)
{
    double sum = 0;
    double M = M(len);
    double C = C(len);
    for (int i = 0; i != len; ++i)
        sum += Y[i] * legendre(M * i + C, order);
    return sum;
}


void l_fit(double * __restrict__ coeffs, double * __restrict__ Y,
           int len, unsigned int order)
{
    double norms[order + 1];
    double first_norm = 0;
    double M = M(len);
    double C = C(len);
    for (unsigned int n = 0; n <= order; ++n) {
        norms[n] = l_norm_sq(len, n);
        double ip = inner_pr(Y, len, n);
        coeffs[n] = ip / norms[n];
        fprintf(stderr, "%i: %g [%g/%g]\n", n, coeffs[n], ip, norms[n]);
        first_norm += ip * coeffs[n];
        for (unsigned int i = 0; i < len; ++i)
            Y[i] -= coeffs[n] * legendre(M * i + C, n);
    }
    double this_norm;
    int count = 0;
    do {
        this_norm = 0;
        for (unsigned int n = 0; n <= order; ++n) {
            double a = inner_pr(Y, len, n);
            double bb = a / norms[n];
            fprintf(stderr, "%i: %g = %g + %g\n",
                    n, coeffs[n] + bb, coeffs[n], bb);
            coeffs[n] += bb;
            this_norm += a * bb;
            for (unsigned int i = 0; i < len; ++i)
                Y[i] -= bb * legendre(M * i + C, n);
        }
    }
    while (this_norm * 1e20 > first_norm && ++count < 10);
    fprintf(stderr, "Iterations = %i\n", count);
}


// Transform from linear sum of Legendre polys to linear sum of monics.
// CENTER and WIDTH (actually the half-width) allow taking "Legendre" polys
// on [CENTER-WIDTH,CENTER+WIDTH] instead of [-1,+1].
void l_coeffs2poly(double * coeffs,
                   double CENTER, double WIDTH, unsigned int order)
{
    double CC[(order + 1) * (order + 1)];
    l_coeff(CC, order, CENTER, WIDTH);
    double result[order + 1];
    result[0] = coeffs[0];

    for (int n = 1; n <= order; ++n) {
        double * r = CC + n * (order + 1);
        for (int i = 0; i <= n; ++i)
            result[i] += coeffs[n] * *r++;
        *r = coeffs[n] * *r;
    }
    memcpy(coeffs, result, (order + 1) * sizeof(double));
}
