#include <fftw3.h>
#include <math.h>
#include <stdio.h>
#include <stdlib.h>

#define FREQ (1e8 / 7.0)

#define SIZE (1<<24)
#define HALF (SIZE/2)
#define HALFp1 (HALF + 1)
static double in[SIZE];
static double out[SIZE];
/* static int indexes[HALFp1]; */

/*
static int cmp(const void * AA, const void * BB)
{
    const int * A = AA;
    const int * B = BB;
    double a = out[*A];
    double b = out[*B];
    if (a == b)
        return 0;
    return a < b ? 1 : -1;
}
*/

int main()
{
    int seen[16384];

    for (int i = 0; i < SIZE; ++i) {
        int x;
        if (scanf("%x", &x) < 1) {
            fprintf(stderr, "Failed to read input.\n");
            exit(1);
        }
        in[i] = x;
        if (x < 0 || x >= 16384) {
            fprintf(stderr, "Out of range: [%d] = %d\n", i, x);
            exit(1);
        }
        seen[x] = 1;
    }

    int j = 0;
    for (int i = 0; i < 16384; ++i)
        if (seen[i])
            seen[i] = j++;

    for (int i = 0; i < SIZE; ++i)
        in[i] = seen[(int) in[i]];

    fprintf(stderr, "Got data...\n");

    fftw_plan plan = fftw_plan_r2r_1d(SIZE, in, out, FFTW_R2HC, FFTW_ESTIMATE);

    fprintf(stderr, "Executing...\n");

    fftw_execute(plan);

    for (int i = 1; i < HALF; ++i)
        out[i] = out[i] * out[i] + out[SIZE - i] * out[SIZE - i];
    //out[0] = out[0] * out[0];
    out[HALF] = out[HALF] * out[HALF];
    out[0] = 0;
    /* out[HALF] = 0; */

#if 1
    const int ROWS = 1024;
    for (int i = 0; i < ROWS; ++i) {
        for (int mult = 1; mult * ROWS <= HALF; mult *= 2) {
            int low = i * mult;
            int high = (i + 1) * mult;
            double power = 0;
            for (int k = low; k != high; ++k)
                power += out[k];
            double freq = (low + high - 1) * (0.5 * FREQ / SIZE);
            printf("%g\t%g\t", freq, power);
        }
        printf("\n");
    }
#else

    /* qsort(indexes, HALFp1, sizeof(indexes[0]), cmp); */

    for (int i = 0; i < HALFp1; ++i) {
        /* int idx = indexes[i]; */
        int idx = i;
        printf("%g %i %g\n", out[idx], idx, 1e9 / 333 / SIZE * idx);
    }
#endif

    return 0;
}
