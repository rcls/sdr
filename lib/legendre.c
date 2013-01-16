// Fit a Polynomial to a sequence of (x,y) data with a polynomial.
// Instead of computing appropriate orthogonal polynomials, we just use Legendre
// polynomials and iterate; we will have many data points and lowish order, so
// the finite sums should be close enough to the integrals to make things
// converge ok.

#include "legendre.h"

#include <stdio.h>
#include <string.h>

#define M(len) (2.0 / (len))
#define C(len) (1.0 / (len) - 1)

#define L(n) (2*(n)+1.0) / ((n)+1), (n) / ((n)+1.0),
#define K(n) L(n) L(n+1) L(n+2)  L(n+3)  L(n+4)  L(n+5)  L(n+6)  L(n+7)
#define J(n) K(n) K(n+8) K(n+16) K(n+24) K(n+32) K(n+40) K(n+48) K(n+56)
static const double LCOEFF[512] = { J(0) J(64) J(128) J(192) };


double l_eval(double x, const double * coeffs, unsigned int order)
{
    double result = *coeffs++;
    if (order == 0)
        return result;
    double prev = 1;
    double current = x;
    for (unsigned int n = 1; n < order; ++n) {
        result += current * *coeffs++;
        double next = LCOEFF[2*n] * x * current - LCOEFF[2*n+1] * prev;
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


void l_fit(double * __restrict__ coeffs, double * __restrict__ Y,
           unsigned int len, unsigned int order)
{
    if (order == 0) {
        double sum = 0;
        for (unsigned int i = 0; i < len; ++i)
            sum += Y[i];
        *coeffs = sum / len;
        for (unsigned int i = 0; i < len; ++i)
            Y[i] -= *coeffs;
        return;
    }

    double M = M(len);
    double C = C(len);
    double norms[order + 1];
    double inners[order + 1];
    for (unsigned int n = 0; n <= order; ++n)
        norms[n] = inners[n] = 0;
    norms[0] = len;
    norms[1] = (len * (double) len - 1) * (1 / 3.0) / len;
    for (unsigned int i = 0; i < len; ++i) {
        double x = M * i + C;
        double prev = 1;
        double current = x;
        inners[0] += Y[i];
        inners[1] += x * Y[i];
        for (unsigned int n = 1; n < order; ++n) {
            double next = LCOEFF[2*n] * x * current - LCOEFF[2*n+1] * prev;
            norms[n+1] += next * next;
            inners[n+1] += next * Y[i];
            prev = current;
            current = next;
        }
    }
    for (unsigned int n = 0; n <= order; ++n) {
        coeffs[n] = inners[n] / norms[n];
        fprintf(stderr, "%i: %g = %g/%g\n", n, coeffs[n], inners[n], norms[n]);
    }

    double first_norm = 0;
    for (unsigned int i = 0; i < len; ++i) {
        double y = l_eval(M * i + C, coeffs, order);
        Y[i] -= y;
        first_norm += y * y;
    }

    int count = 0;
    double this_norm;
    do {
        for (unsigned int n = 0; n <= order; ++n)
            inners[n] = 0;
        for (unsigned int i = 0; i < len; ++i) {
            double x = M * i + C;
            double prev = 1;
            double current = x;
            inners[0] += Y[i];
            if (order >= 1)
                inners[1] += x * Y[i];
            for (unsigned int n = 1; n < order; ++n) {
                double next = LCOEFF[2*n] * x * current - LCOEFF[2*n+1] * prev;
                inners[n+1] += next * Y[i];
                prev = current;
                current = next;
            }
        }
        for (unsigned int n = 0; n <= order; ++n) {
            inners[n] /= norms[n];
            fprintf(stderr, "%i: %g = %g + %g\n",
                    n, coeffs[n] + inners[n], coeffs[n], inners[n]);
            coeffs[n] += inners[n];
        }
        this_norm = 0;
        for (unsigned int i = 0; i < len; ++i) {
            double y = l_eval(M * i + C, inners, order);
            Y[i] -= y;
            this_norm += y * y;
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
