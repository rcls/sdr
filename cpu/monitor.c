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
extern unsigned char __bss_start;
extern unsigned char __bss_end;

typedef struct global_t {
    unsigned next;
    unsigned char * global_address;
    bool unlocked;
} global_t;

#define next (((global_t *) 0x20001ff0)->next)
#define global_address (((global_t *) 0x20001ff0)->global_address)
#define unlocked (((global_t *) 0x20001ff0)->unlocked)

static bool isblank(int c)
{
    return c == ' ' || c == '\r' || c == '\t';
}


static void send(unsigned c)
{
    while ((SSI->sr & 2) == 0);
    SSI->dr = c & 255;
}


static void send_string(const char * s)
{
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
    for (; isblank(b); b = advance_peek());
    return b;
}


static unsigned skip_space_get(void)
{
    unsigned b;
    do
        b = get();
    while (b < 32 && b != 10);
    return b;
}


static unsigned get_hex(unsigned max)
{
    unsigned result = 0;
    unsigned c = peek();
    for (unsigned i = 0; i < max; ++i) {
        if (c >= 'a')
            c &= ~32;                   // Upper case.
        c -= '0';
        if (c >= 10) {
            c -= 'A' - '0' - 10;
            if (c < 10 || c > 15)
                break;
        }
        result = result * 16 + c;
        c = advance_peek();
    }
    skip_space_peek();
    return result;
}


static unsigned char * get_address(void)
{
    unsigned c = skip_space_peek();
    if (c == '\n' || c == ':')
        return global_address;
    else
        return (unsigned char *) get_hex(8);
}


static void command_error()
{
    while (get() != '\n');
    send('?');
}


static bool command_end()
{
    if (skip_space_get() == '\n')
        return true;
    command_error();
    return false;
}


static void run(unsigned * vtable) __attribute__((noreturn));
static void run(unsigned * vtable)
{
    *VTABLE = (unsigned) vtable;
    __interrupt_disable();
    asm volatile ("mov sp,%0\n"
                  "bx %1\n" :: "r" (vtable[0]), "r" (vtable[1]));
    __builtin_unreachable();
}


static void command_go(void)
{
    unsigned char * address = get_address();
    if (!command_end())
        return;

    send_string("Go\n");
    while ((SSI->sr & 0x11) != 1);

    run ((unsigned *) address);
}


static void command_address(void)
{
    if (skip_space_peek() == '\n') {
        command_error();
        return;
    }

    unsigned char * address = get_address();
    if (!command_end())
        return;

    send('A');
    global_address = address;
}


static void command_read(void)
{
    unsigned char * address = get_address();
    if (!command_end())
        return;
    send_hex((unsigned) address, 8);
    send(':');
    for (int i = 0; i != 16; ++i) {
        send(' ');
        send_hex(*address++, 2);
    }
    global_address = address;
}


static void command_write(void)
{
    unsigned char * address = get_address();
    if (next == ':')
        next = 0;
    unsigned char bytes[16];
    unsigned n = 0;
    for (; n != sizeof bytes && skip_space_peek() != '\n'; ++n)
        bytes[n] = get_hex(2);

    if (!command_end())
        return;

    unsigned end = (unsigned) address + n;
    if ((unsigned) address < 0x20002000 && end > 0x20001f00) {
        send_string("? Stack");
        return;
    }

    if (end < n) {
        send_string("? Wrap");
        return;
    }

    unsigned text_start = *VTABLE;
    unsigned text_end = text_start + (&__text_end - &__text_start);
    if (end > text_start && (unsigned) address < text_end) {
        send_string("? Monitor text");
        return;
    }

    if ((unsigned) address >= 0x20000000) {
        // Memory.
        unsigned char * src = bytes;
        for (unsigned i = 0; i != n; ++i)
            *address++ = *src++;
    }
    else {
        // Flash...
        if ((3 & (unsigned) address) || (3 & n)) {
            send_string("? Alignment");
            return;
        }
        for (int i = 0; i != n; ++i)
            if (address[i] != 0xff) {
                send_string("? Not erased");
                return;
            }
        if (!unlocked) {
            send_string("? Locked");
            return;
        }

        n >>= 2;
        unsigned char * src = bytes;
        for (int i = 0; i != n; ++i) {
            unsigned w = *src++;
            w += *src++ << 8;
            w += *src++ << 16;
            w += *src++ << 24;
            FLASHCTRL->fmd = w;
            FLASHCTRL->fma = (unsigned) address;
            FLASHCTRL->fmc = 0xa4420001;
            while (FLASHCTRL->fmc & 1);
            address += 4;
        }
    }

    send('W');

    global_address = address;
}


static void command_erase(void)
{
    unsigned char * address = get_address();
    if (!command_end())
        return;

    if ((unsigned) address >= 0x65536) {
        send_string("? Address");
        return;
    }
    if ((unsigned) address & 1023) {
        send_string("? Alignment");
        return;
    }

    if (!unlocked) {
        send_string("? Locked");
        return;
    }

    FLASHCTRL->fma = (unsigned) address;
    FLASHCTRL->fmc = 0xa4420002;
    while (FLASHCTRL->fmc & 2);

    send('E');
}


static void monitor_reloc(void)
{
    unsigned char * src = (unsigned char *) *VTABLE;
    void * ramtop = (void *) 0x20001800;
    if (src == ramtop)
        return;

    unsigned char * dest = ramtop;
    unsigned char * end = src + (&__text_end - &__text_start);
    for (unsigned char * p = src; p != end; ++p)
        *dest++ = *p;

    unsigned diff = ramtop - (void *) &__text_start;
    unsigned * newvtable = ramtop;
    for (int i = 1; i != VTABLE_SIZE; ++i)
        newvtable[i] += diff;
    run (ramtop);
}


static void command_unlock(void)
{
    for (const unsigned char * p = (unsigned char *) "nlock!Me"; *p; ++p) {
        if (advance_peek() != *p) {
            command_error();
            return;
        }
        next = 0;
    }
    if (!command_end())
        return;
    unlocked = 1;
    send('U');
}


static void command(void)
{
    switch (skip_space_get()) {
    case 'A':
        command_address();
        break;
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
        if (command_end())
            send('P');
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
    SC->rcgc[2] |= 31;                  // GPIOs.
    SC->usecrl = 12;

    // Just to be safe.  Also takes clock cycles...
    *VTABLE = (unsigned) vtable;

    // Now read the SSI data input pin, PA4.  If it is pulled high, try an
    // alternate boot source.
    if (PA->data[16] & 16)
        alternate_boot();

    if (RELOCATE)
        monitor_reloc();

    SC->rcgc[1] |= 16;                  // SSI.
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
