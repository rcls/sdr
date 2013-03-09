// A really basic monitor.
#include "registers.h"

#include <stdbool.h>

#define VTABLE ((unsigned *) 0xe000ed08)
#define VTABLE_SIZE 38

#ifndef RELOCATE
#define RELOCATE 0
#endif

extern void * const vtable[] __attribute__((section (".start"),
                                            externally_visible));

extern unsigned char __text_start;
extern unsigned char __text_end;

#undef SSI
register volatile ssi_t * SSI asm ("r10");

register unsigned next asm ("r6");
register bool unlocked asm ("r11");

static void send(unsigned c)
{
    while ((SSI->sr & 2) == 0);
    SSI->dr = c & 255;
}

#if 0
static void send_string(const char * s)
{
    for (; *s; ++s)
        send(*s);
}
#else
#define send_string(s) send (*(s))
#endif

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
    while (next == 0) {
        while ((SSI->sr & 4) == 0)
            SSI->dr = 0;
        next = SSI->dr;
    }
    return next;
}


static unsigned get(void)
{
    unsigned byte = peek();
    next = 0;
    return byte;
}


static unsigned advance_peek(void)
{
    next = 0;
    return peek();
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
    unsigned b;
    do
        b = get();
    while (b == ' ');
    return b;
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


static __attribute__((noreturn)) void invoke(unsigned * vtable)
{
    asm volatile ("mov sp,%0\n"
                  "bx %1\n" :: "r" (vtable[0]), "r" (vtable[1]));
    __builtin_unreachable();
}


static __attribute__((noreturn)) void run(unsigned * vtable)
{
    *VTABLE = (unsigned) vtable;
    invoke(vtable);
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
    while (get() != '\n');
    command_abort("?");
}


static void command_end()
{
    if (skip_space_get() != '\n')
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
    if (next == ':')
        next = 0;
    unsigned words[4];
    unsigned char * bytes = (unsigned char *) words;
    unsigned n = 0;
    for (; n != sizeof words && skip_space_peek() != '\n'; ++n)
        bytes[n] = get_hex(2);

    command_end();

    unsigned end = (unsigned) address + n;
    if ((unsigned) address < 0x20002000 && end > 0x20001f00)
        command_abort("? Stack");

    if (end < n)
        command_abort("? Wrap");

    unsigned text_start = *VTABLE;
    unsigned text_end = text_start + (0x7ff & (unsigned) &__text_end);
    if (end > text_start && (unsigned) address < text_end)
        command_abort("? Monitor text");

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

    if ((unsigned) address >= 0x65536)
        command_abort("? Address");

    if ((unsigned) address & 1023)
        command_abort("? Alignment");

    if (!unlocked)
        command_abort("? Locked");

    FLASHCTRL->fma = (unsigned) address;
    FLASHCTRL->fmc = 0xa4420002;
    while (FLASHCTRL->fmc & 2);

    send('E');
}


static void monitor_reloc(void)
{
    unsigned char * src = &__text_start;
    void * ramtop = (void *) 0x20001800;
    if (src != (unsigned char *) *VTABLE)
        return;

    unsigned char * dest = ramtop;
    for (unsigned i = 0; i != &__text_end - src; ++i)
        dest[i] = src[i];

    unsigned diff = (unsigned char *) ramtop - src;
    unsigned * newvtable = ramtop;
    for (int i = 1; i != VTABLE_SIZE; ++i)
        newvtable[i] += diff;
    run (ramtop);
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
        send('Q');
        break;
    case 'G':
        command_go();
        break;
    default:
        command_error();
    }
    send('\n');
}


static void alternate_boot(void)
{
    unsigned * altvtable = (unsigned *) 0x800;
    if (*altvtable >= 0x20000000 && *altvtable <= 0x20002000)
        run(altvtable);
}


static void go (void)
{
    __interrupt_disable();
    SC->rcgc[2] = 31;                   // GPIOs.
    SC->usecrl = 12;

    // Just to be safe.  Also takes clock cycles...
    *VTABLE = (unsigned) vtable;

    // Now read the SSI data input pin, PA4.  If it is pulled high, try an
    // alternate boot source.
    if (PA->data[16] & 16)
        alternate_boot();

    if (RELOCATE)
        monitor_reloc();

#ifndef SSI
    SSI = (ssi_t *) 0x40008000;
#endif

    SC->rcgc[1] = 16;                   // SSI.
    SSI->cr[1] = 4;                     // Slave, disable.
    SSI->cr[0] = 0xc7;                  // Full rate, SPH=1, SPO=1, SPI, 8 bits.
    SSI->cpsr = 2;                      // Prescalar /2.

    PA->afsel = 0x3c;                   // Set SSI pins to alt. function.

    SSI->cr[1] = 6;                     // Slave, enable.

    next = 0;
    unlocked = 0;

    while (1)
        command();
}


void dummy_int(void)
{
}


void * const vtable[] = {
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

_Static_assert(sizeof vtable == VTABLE_SIZE * 4, "vector size");
