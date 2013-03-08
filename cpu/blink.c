#include <stddef.h>

#include "registers.h"

static void go(void)
{
    // Led is on Pin 36 PE1
    asm volatile("cpsid i\n");
    SC->rcgc[2] |= 16;
    PE->dir |= 2;
    while (1) {
        for (int i = 0; i != 1000000; ++i)
            asm volatile("");
        PE->data[255] ^= 2;
    }
}

static void dummy_int(void)
{
}

extern void * start[] __attribute__((section (".start"), externally_visible));
void * start[] = {
    (void*) 0x20001ff0, go, dummy_int, dummy_int,
    dummy_int, dummy_int, dummy_int, dummy_int,
    dummy_int, dummy_int, dummy_int, dummy_int,
    dummy_int, dummy_int, dummy_int, dummy_int,
    dummy_int, dummy_int, dummy_int, dummy_int,
    dummy_int, dummy_int, dummy_int, dummy_int,
    dummy_int, dummy_int, dummy_int, dummy_int,
    dummy_int, dummy_int, dummy_int, dummy_int,
    dummy_int, dummy_int, dummy_int, dummy_int,
    dummy_int, dummy_int,
};

_Static_assert(sizeof start == 38 * sizeof * start, "vector size");
