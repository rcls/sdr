#include <math.h>
#include <stdio.h>

int main(void)
{
    const int base = 80;
//    static const int N[] = { 49, 56, 65, 74, 79 };
    static const int N[] = { 65, 74, 87, 99, 106 };
    const int offset = 21;
    for (int i = 0; i != 32; ++i) {
        int sum = offset;
        for (int j = 0; j != 5; ++j)
            if (i & (1 << j))
                sum += N[j];
        printf(
            "        when %2i => op(%i) <= op_add; -- %3i = %i*%i +%2i = %i",
            sum % base, __builtin_popcount(i), sum,
            sum / base, base, sum % base, offset);
        for (int j = 0; j != 5; ++j)
            if (i & (1 << j))
                printf(" +%i", N[j]);
        printf("\n");
    }

    for (int i = 0; i != 4; ++i) {
        double scale = sqrt(sqrt(2 << i)) * 65536;
        printf("    -- Scale = %g.\n", scale);
        for (int j = 0; j != 256; ++j) {
            if (j % 4 == 0)
                printf("    ");
            int val = 0;
            if (j % 8 < 5) {
                int jj = j / 8 * 5 + j % 8;
                val = round(-scale * cos(jj * (0.5 * M_PI / base)));
            }
            printf("\"%i%i\" & x\"%04x\",%c",
                   (val & 131072) != 0, (val & 65536) != 0, val & 65535,
                   j % 4 == 3 ? '\n' : ' ');
        }
    }

    return 0;
}
