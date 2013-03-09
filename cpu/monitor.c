// A really basic monitor.
#include "registers.h"

#include <stdbool.h>

#define VTABLE_SIZE 38

#ifndef RELOCATE
#define RELOCATE 0
#endif

#ifndef MINIMIZE
#define MINIMIZE 1
#endif

#if MINIMIZE
#define STACK_TOP 0x20002000
#else
#define STACK_TOP 0x20001b00
#endif

#if !RELOCATE
#define BASE &__text_start
#elif MINIMIZE
#define BASE 0x20001c00
#else
#define BASE 0x20001b00
#endif


extern void * const vtable[] __attribute__((section (".start"),
                                            externally_visible));

extern unsigned char __text_start;

static const unsigned char __text_end __attribute__((section(".poststart")));

#undef SSI

register unsigned next asm ("r7");
register unsigned * VTABLE asm("r8");
register volatile ssi_t * SSI asm ("r9");
register bool unlocked asm ("r10");

static void send(unsigned c)
{
    while ((SSI->sr & 2) == 0);
    SSI->dr = c & 255;
}

static void send_string(const char * s)
{
    if (MINIMIZE)
        send(*s);
    else
        for (; *s; ++s)
            send(*s);
}

static void send_hex(unsigned n, unsigned len)
{
    for (unsigned l = len; l--;) {
        unsigned nibble = (n >> (l * 4)) & 15;
        if (nibble >= 10)
            nibble += 'a' - '0' - 10;
        send (nibble + '0');
    }
}


static unsigned peek(void)
{
    return next;
}


static unsigned advance_peek(void)
{
    do {
        while ((SSI->sr & 4) == 0)
            SSI->dr = 0;
        next = SSI->dr;
    }
    while (next == 0);
    return next;
}


static unsigned get(void)
{
    unsigned byte = next;
    advance_peek();
    return byte;
}


static unsigned skip_space_peek(void)
{
    unsigned b = peek();
    while (b == ' ')
        b = advance_peek();
    return b;
}


static unsigned skip_space_get(void)
{
    skip_space_peek();
    return get();
}


static unsigned get_hex(unsigned max)
{
    unsigned result = 0;
    unsigned c = skip_space_peek();
    for (unsigned i = 0; i < max; ++i) {
        if (c >= 'a')
            c -= 32;                    // Upper case.
        c -= '0';
        if (c >= 10) {
            c -= 'A' - '0' - 10;
            if (c < 10 || c > 15)
                break;
        }
        result = result * 16 + c;
        c = advance_peek();
    }
    return result;
}


static unsigned char * get_address(void)
{
    return (unsigned char *) get_hex(8);
}


static __attribute__((noreturn)) void invoke(unsigned * vt)
{
    __memory_barrier();
    asm volatile ("mov sp,%0\n" "bx %1\n" :: "r" (vt[0]), "r" (vt[1]));
    __builtin_unreachable();
}


static __attribute__((noreturn)) void command_abort(const char * s)
{
    send_string(s);
    send('\n');
    while ((SSI->sr & 0x11) != 1);
    invoke((unsigned *) *VTABLE);
}


static __attribute__((noreturn)) void command_error()
{
    while (peek() != '\n')
        get();
    command_abort("?");
}


static void command_end()
{
    if (skip_space_peek() != '\n')
        command_error();
}


static void command_go(void)
{
    unsigned char * address = get_address();
    command_end();

    *VTABLE = (unsigned) address;
    command_abort("Go");
}


static void command_read(void)
{
    unsigned char * address = get_address();
    command_end();
    send_hex((unsigned) address, 8);
    char sep = ':';
    for (int i = 0; i != 16; ++i) {
        send(sep);
        send_hex(address[i], 2);
        sep = ' ';
    }
}


static void command_write(void)
{
    unsigned char * address = get_address();
    unsigned words[4];
    unsigned char * bytes = (unsigned char *) words;
    unsigned n = 0;
    for (; n != sizeof words && skip_space_peek() != '\n'; ++n)
        bytes[n] = get_hex(2);

    command_end();

    unsigned end = (unsigned) address + n;
    if (end < n)
        command_abort("? Wrap");

#if MINIMIZE && RELOCATE
    if ((unsigned) address <= 0x20002000 &&
        (end > STACK_TOP - 128 || end > BASE))
        command_abort("? Monitor");
#else
    if ((unsigned) address < STACK_TOP && end > STACK_TOP - 128)
        command_abort("? Stack");

    unsigned text_start = (unsigned) vtable;
    unsigned text_end = (unsigned) &__text_end;
    if (end > text_start && (unsigned) address < text_end)
        command_abort("? Monitor text");
#endif

    if ((unsigned) address >= 0x20000000) {
        // Memory.
        for (unsigned i = 0; i != n; ++i)
            address[i] = bytes[i];
    }
    else {
        // Flash...
        if ((3 & (unsigned) address) || (3 & n))
            command_abort("? Alignment");
        for (int i = 0; i != n; ++i)
            if (address[i] != 0xff)
                command_abort("? Not erased");

        if (!unlocked)
            command_abort("? Locked");

        for (int i = 0; i != n; i += 4) {
            FLASHCTRL->fmd = * (unsigned *) (bytes + i);
            FLASHCTRL->fma = (unsigned) address + i;
            FLASHCTRL->fmc = 0xa4420001;
            while (FLASHCTRL->fmc & 1);
        }
    }

    send('W');
}


static void command_erase(void)
{
    unsigned char * address = get_address();
    command_end();

    if ((unsigned) address & ~0xfc00)
        command_abort("? Erase Address");

    if (!unlocked)
        command_abort("? Locked");

    FLASHCTRL->fma = (unsigned) address;
    FLASHCTRL->fmc = 0xa4420002;
    while (FLASHCTRL->fmc & 2);

    send('E');
}


static __attribute__ ((noreturn, section(".posttext")))
void monitor_reloc(void)
{
    unsigned char * src = (unsigned char *) *VTABLE;
    unsigned char * dest = (unsigned char *) BASE;
    for (unsigned i = 0; i != &__text_end - src; ++i)
        dest[i] = src[i];

    unsigned diff = dest - src;
    unsigned * newvtable = (unsigned *) dest;
    for (int i = 1; i != VTABLE_SIZE; ++i)
        newvtable[i] += diff;
    __memory_barrier();
    *VTABLE = (unsigned) dest;
    invoke(newvtable);
}


static void command_unlock(void)
{
    for (const unsigned char * p = (unsigned char *) "nlock!Me"; *p; ++p) {
        if (advance_peek() != *p)
            command_error();
        next = 0;
    }
    command_end();
    unlocked = 1;
    send('U');
}


static void command(void)
{
    next = ' ';
    switch (skip_space_get()) {
    case 'R':
        command_read();
        break;
    case 'E':
        command_erase();
        break;
    case 'W':
        command_write();
        break;
    case 'U':
        command_unlock();
        break;
    case 'P':
        command_end();
        send_string("Ping");
        break;
    case 'G':
        command_go();
        break;
    default:
        command_error();
    }
    send('\n');
}


static __attribute__ ((section(".posttext")))
void alternate_boot(void)
{
    unsigned * altvtable = (unsigned *) 0x800;
    if (*altvtable >= 0x20000000 && *altvtable <= 0x20002000) {
        *VTABLE = (unsigned) altvtable;
        invoke(altvtable);
    }
}


static __attribute__ ((noinline, section(".posttext")))
void first(void)
{
    // Read the SSI data input pin, PA4.  If it is pulled high, try an alternate
    // boot source.
    if (PA->data[16] & 16)
        alternate_boot();

    if (RELOCATE)
        monitor_reloc();
}


static void go (void)
{
    __interrupt_disable();
    SC->rcgc[2] = 31;                   // GPIOs.
    SC->rcgc[1] = 16;                   // SSI.
    SC->usecrl = 12;

    VTABLE = (unsigned *) 0xe000ed08;
    if ((*VTABLE & 0xffff) == 0)
        first();

#ifndef SSI
    SSI = (ssi_t *) 0x40008000;
#endif

    SSI->cr[1] = 4;                     // Slave, disable.
    SSI->cr[0] = 0xc7;                  // Full rate, SPH=1, SPO=1, SPI, 8 bits.
    SSI->cpsr = 2;                      // Prescalar /2.

    PA->afsel = 0x3c;                   // Set SSI pins to alt. function.

    SSI->cr[1] = 6;                     // Slave, enable.

    unlocked = 0;

    while (1)
        command();
}


void dummy_int(void)
{
}


void * const vtable[VTABLE_SIZE] = {
    (void*) STACK_TOP, go,
    [2 ... VTABLE_SIZE - 1] = dummy_int
};
