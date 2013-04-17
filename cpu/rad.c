
#include "command.h"
#include "printf.h"
#include "registers.h"
#include "../lib/registers.h"

const void * const vtable[] __attribute__((section (".start"),
                                           externally_visible));

static const command_t commands[] = {
    { "wr", command_write },
    { "rd", command_read },
    { "echo", command_echo },
    { "reboot", command_reboot },
    { "bandpass", command_bandpass },
    { "tune", command_tune },
    { "gain", command_gain },
    { "R", command_R },
    { "W", command_W },
    { "G", command_G },
    { "nop", command_nop },
    { "flash", command_flash },
    { "adc", command_adc },
    { "pll", command_pll_report },
    { "", command_nop },
    { NULL, NULL }
};


__attribute__((noreturn)) void run(void)
{
    while (1)
        command(commands, NULL);
}


static void start(void)
{
    __interrupt_disable();
    SC->rcgc[2] = 31;                   // GPIOs.
    SC->rcgc[1] = 16;                   // SSI.

    SSI->cr[1] = 0;                     // Disable.
    SSI->cr[0] = 0xcf;                  // SPH=1, SPO=1, SPI, 16 bits.
    SSI->cpsr = 2;                      // Prescalar /2.

    PA->afsel = 0x3c;                   // Set SSI pins to alt. function.

    SSI->cr[1] = 2;                     // Master, enable.

    PE->dir |= 2;

    rerun("Welcome\n");
}


static void dummy_int(void)
{
}


const void * const vtable[] = {
    (void*) 0x20002000, start,
    [2 ... 37] = dummy_int,
    [38] = commands
};
