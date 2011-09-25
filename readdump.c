
#include <unistd.h>
#include <stdio.h>
#include <stdlib.h>

#define BUFSIZE 16777216
static unsigned char buffer[BUFSIZE];

static unsigned int wash(unsigned int x)
{
    return x;
//    return ((x & 0x5555555) << 1) | ((x & 0xaaaaaaaa) >> 1);
}


int main()
{
    int r = read(0, buffer, BUFSIZE);
    if (r < 0) {
        perror("read");
        exit(EXIT_FAILURE);
    }

    if (r < 4096) {
        fprintf(stderr, "Short data (%u bytes)\n", r);
        exit(EXIT_FAILURE);
    }

    const unsigned char * end = buffer + r;
    int state = 0;
    int counter = 0;
    for (const unsigned char * p = buffer; p != end; ++p) {
        switch (state) {
        default:
            if (*p & 128) {
                counter = *p;
                state = 1;
            }
            break;
        case 1:
            if (*p & 128) {
                printf("Sync not high byte at offset %#zx\n", p - buffer);
                counter = *p;
                state = 1;
            }
            else {
                state = 2;
            }
            break;
        case 2:
            if (*p & 128) {
                printf("Sync not low byte at offset %#zx\n", p - buffer);
                counter = *p;
                state = 1;
            }
            else {
                printf("%04x\n", wash(p[-1] * 128 + *p));
                state = 3;
            }
            break;
        case 3:
            if (*p & 128) {
                if (((counter + 1) & 127) != (*p & 127))
                    printf("Sync skip at offset %#zx\n", p - buffer);
                counter = *p;
                state = 1;
            }
            else {
                printf("No sync at offset %#zx\n", p - buffer);
                state = 0;
            }
        }
    }
    exit(EXIT_FAILURE);
}