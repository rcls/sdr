// Output the angle_update table for the phase detector arctan computation.
#include <stdio.h>
#include <math.h>

#define BITS 16
#define NIBBLES (BITS / 4)
#define USED_ITERATIONS 16
#define TOTAL_ITERATIONS 20
#define MASK(n) ((1 << (n)) - 1)
static void print(int i, int value)
{
    if (BITS != NIBBLES * 4) {
        printf("\"");
        for (int i = BITS - 1; i >= NIBBLES * 4; --i)
            printf("%i", !!(value & (1 << i)));
        printf("\" & ");
    }
    printf("x\"%0*x\"", NIBBLES, value & MASK(4 * NIBBLES));

    if (i == TOTAL_ITERATIONS - 1)
        printf(");\n");
    else if (i % 4 == 3)
        printf(",\n     ");
    else
        printf(", ");
}


int main(void)
{
    printf("  type angles_t is array(0 to %i) of unsigned%i;\n",
           TOTAL_ITERATIONS - 1, BITS);
    printf("  constant angle_update : angles_t :=\n");
    printf("    (");
    print(0, MASK(BITS));
    for (int i = 1; i != USED_ITERATIONS; ++i) {
        double radians = atan2(1, 1 << i);
        print(i, (int) round(radians * ((2 << BITS) / M_PI)));
    }
    for (int i = USED_ITERATIONS; i != TOTAL_ITERATIONS; ++i)
        print(i, 0);
    return 0;
}
