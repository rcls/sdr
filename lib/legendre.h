#ifndef LEGENDRE_H
#define LEGENDRE_H


// Leaves residuals in Y.
void l_fit(double * restrict coeffs, double * restrict Y,
           unsigned int len, unsigned int order);

// Transform the poly coefficients from the Legendre to monic basis.
void l_coeffs2poly(double * coeffs,
                   double CENTER, double WIDTH, unsigned int order);

// sum_{n=0}^{n=order}(coeffs[n] * P_n(x))
double l_eval(double x, const double * coeffs, unsigned int order);

// map 0...len-1 into [-1, 1].
inline double l_x(unsigned int i, unsigned int len)
{
    return (2 * i + 1) / (double) len - 1;
}

#endif
