
#include <assert.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>

#define WANTED (1 << 23)
#define BUFSIZE (2 * WANTED + 1048576)
static unsigned char buffer[BUFSIZE];

static const unsigned char * synchronise(const unsigned char * p,
                                         const unsigned char * end,
                                         uint32_t * running)
{
    if (end - p < 64)
        return end;

    uint32_t running1 = 0;
    uint32_t running2 = 0;
    for (int i = 0; i != 32; ++i) {
        running1 = running1 * 2 + (*p++ >= 128);
        running2 = running2 * 2 + (*p++ >= 128);
    }

    while (p < end) {
        uint32_t run_next = running1 * 2 + (*p++ >= 128);
        if (run_next == running2
            // Poly is 0x100802041
            && run_next == running1 * 2 + __builtin_parity(
                running1 & 0x80401020)) {
            *running = run_next;
            return p;
        }
        running1 = running2;
        running2 = run_next;
    }
    *running = 0;
    return p;
}


int main()
{
    int r = read(0, buffer, BUFSIZE);
    if (r < 0) {
        perror("read");
        exit(EXIT_FAILURE);
    }
    fprintf(stderr, "Read %i bytes\n", r);

    if (r < 4096) {
        fprintf(stderr, "Short data (%u bytes)\n", r);
        exit(EXIT_FAILURE);
    }

    const unsigned char * best_start = NULL;
    int best_len = 0;

    const unsigned char * end = buffer + r - 1;
    const unsigned char * p = buffer;
    uint32_t running = 0;
    do {
        const unsigned char * start = synchronise(p, end, &running);
        if (start >= end)
            break;
        for (p = start; p < end; p += 2) {
            int f1 = p[0] & 128;
            int f2 = p[1] & 128;
            if (f1 != f2)
                break;
            uint32_t predicted
                = running * 2 + __builtin_parity(running & 0x80401020);
            running = running * 2 + (f1 != 0);
            if (predicted != running)
                break;
        }
        if (p - start > best_len) {
            best_start = start;
            best_len = p - start;
        }
    } while (1);

    fprintf(stderr, "Best is length %u at offset %zu\n",
            best_len, best_start - buffer);
    if (best_len < WANTED * 2 + 64) {
        fprintf(stderr, "Not enough....\n");
        exit(EXIT_FAILURE);
    }

    assert ((best_len & 1) == 0);

    for (int i = 0; i < WANTED + 2; i += 2) {
        int x = (best_start[i] & 127) * 128 + (best_start[i + 1] & 127);
        printf("%04x\n", x);
    }

    exit(EXIT_SUCCESS);
}
