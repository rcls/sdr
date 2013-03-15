// Select a boot source.  Either flash+1k or flash+2k.
#include "registers.h"

#define STACK_TOP 0x20002000
#define VTABLE_SIZE 38

static void boot(unsigned * vt)
{
    asm volatile ("mov sp,%0\n" "bx %1\n" :: "r" (vt[0]), "r" (vt[1]));
    __builtin_unreachable();
}


static void first(void)
{
    __interrupt_disable();
    SC->rcgc[2] = 31;                   // GPIOs.

    unsigned v = * (unsigned *) 0x800;
    unsigned * address = (unsigned *) 0x400;
    if (v >= 0x20000000 && v <= 0x20002000 && (PA->data[16] & 16))
        address =  (unsigned *) 0x800;

    boot(address);
}


static void dummy_int(void)
{
}

void * const vtable[] __attribute__((section (".start"),
                                     externally_visible)) = {
    (void*) STACK_TOP, first,
    [2 ... VTABLE_SIZE - 1] = dummy_int
};
