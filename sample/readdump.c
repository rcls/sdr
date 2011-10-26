
#include <unistd.h>
#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>

#define WANTED 16777216
#define BUFSIZE (2 * WANTED)
static unsigned char buffer[BUFSIZE];

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
    const unsigned char * p = buffer;
    uint32_t running = 0;
    for (int i = 0; i != 32; ++ i)
        running = running * 2 + (*p++ >= 128);

    const unsigned char * last_bad = p - 1;
    const unsigned char * best_bad = last_bad;
    int best_len = 0;
    for (; p != end; ++p) {
        // Poly is 0x100802041
        uint32_t predicted
            = running * 2 + __builtin_parity(running & 0x80401020);
        running = running * 2 + (*p >= 128);
        if (running == predicted)
            continue;
        if (p - last_bad > best_len) {
            best_bad = last_bad;
            best_len = p - last_bad;
        }
        last_bad = p;
    }
    if (p - last_bad > best_len) {
        best_bad = last_bad;
        best_len = p - last_bad;
    }
    fprintf(stderr, "Best is length %u at offset %zu\n",
             best_len, best_bad - buffer);
    if (best_len < WANTED + 64) {
        fprintf(stderr, "Not enough....\n");
        exit(EXIT_FAILURE);
    }
    const unsigned char * start = best_bad + 32;
    end = start + WANTED;
    for (p = start; p != end; ++p) {
        int x = *p & 127;
        printf("%04x\n", 8192 + x - 2 * (x & 64));
    }

    exit(EXIT_SUCCESS);
}
