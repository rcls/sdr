// Spi master echo.
#include "registers.h"

unsigned rxbyte(void)
{
    // RX a byte.  Read channel 1.
    while (SSI->sr & 16);
    while (SSI->sr & 4)
        SSI->dr;                        // Flush.
    while (1) {
        SSI->dr = 0;                    // Read channel 0.
        while (!(SSI->sr & 4));
        unsigned word = SSI->dr;
        if (word & 255)
            return word & 255;
    }
}

void txbyte(unsigned byte)
{
    while ((SSI->sr & 2) == 0);
    SSI->dr = 0x300 + byte;             // Write channel 1.
}

void first (void)
{
    __interrupt_disable();
    SC->rcgc[2] = 31;                   // GPIOs.
    SC->rcgc[1] = 16;                   // SSI.

    SSI->cr[1] = 0;                     // Disable.
    SSI->cr[0] = 0x00cf;                // /1, SPH=1, SPO=1, SPI, 16 bits.
    SSI->cpsr = 2;                      // Prescalar /2.

    PA->afsel = 0x3c;                   // Set SSI pins to alt. function.

    SSI->cr[1] = 2;                     // Master, enable.
    for (int i = 0; i != 1000000; ++i)
        asm volatile("");
    PE->dir |= 2;                       // Led out.
    PE->data[2] = 0;

    while (1) {
        unsigned b = rxbyte();
        PE->data[2] ^= 2;
        txbyte(b ^ 1);
    }
}


void dummy_int(void)
{
}


void * const vtable[] __attribute__((section (".start"),
                                     externally_visible)) = {
    (void*) 0x20002000, first,
    [2 ... 37] = dummy_int
};
