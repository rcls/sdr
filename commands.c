// Send commands to the thing.

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define ADC_RESET 8
#define ADC_SCLK 4
#define ADC_SDATA 2
#define ADC_SEN 1

void send_bit(int c)
{
    // First with clk high, then with clock low...
    putchar(c | ADC_SCLK);
    putchar(c & ~ADC_SCLK);
}

void send_data(unsigned long long data, int bits)
{
    for (int i = bits; i-- > 0;)
        send_bit((data & (1ull << i)) ? ADC_SDATA : 0);
}

void send_cordon(void)
{
    send_bit(ADC_SEN);
}

int main(int argc, const char * const * argv)
{
    for (int i = 1; i < argc; ++i) {
        char * rest = NULL;
        unsigned long long data = strtoull(argv[i], &rest, 16);
        if (rest == NULL || *rest) {
            fprintf(stderr, "Failed to parse arg %i\n", i);
            return EXIT_FAILURE;
        }
        send_cordon();
        send_data(data, 4 * (rest - argv[i]));
    }
    send_cordon();
    return EXIT_SUCCESS;
}
