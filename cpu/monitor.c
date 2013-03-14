// A really basic monitor.
#include "registers.h"

#define VTABLE_SIZE 38

#ifndef MINIMIZE
#define MINIMIZE 0
#endif

#define STACK_TOP 0x20002000
#define BASE 0x20001c00

typedef struct sc_tail_t {
    unsigned rcgc[4];
    unsigned scgc[4];
    unsigned dcgc[4];
    unsigned fmpre;
    unsigned fmppe;
    unsigned dummy138[2];
    unsigned usecrl;
} sc_tail_t;

#define SC_TAIL ((volatile sc_tail_t *) 0x400fe100)
_Static_assert(&SC_TAIL->rcgc == &SC->rcgc, "sc tail");

extern unsigned char __unreloc_start, __text_start, __text_end;

#undef SSI

register unsigned next asm ("r8");
register volatile ssi_t * SSI asm ("r9");
register int unlocked asm ("r7");

#define VTABLE ((unsigned *) 0xe000ed08)

static void send(unsigned c)
{
    while ((SSI->sr & 2) == 0);
    SSI->dr = 256 + c;
}


static void send_string(const char * s)
{
    if (MINIMIZE)
        send(*s & 255);
    else
        for (; *s; ++s)
            send(*s & 255);
}


static void send_hex(unsigned n, unsigned len)
{
    unsigned l = len * 4;
    do {
        l -= 4;
        unsigned nibble = (n >> l) & 15;
        if (nibble >= 10)
            nibble += 'a' - '0' - 10;
        send (nibble + '0');
    }
    while (l);
}


static unsigned peek(void)
{
    return next;
}


static unsigned advance_peek(void)
{
    while (1) {
        unsigned s = SSI->sr;
        if (!(s & 16))
            SSI->dr = 0;
        if (s & 4) {
            unsigned w = SSI->dr;
            if (w && w < 256) {
                next = w;
                return w;
            }
        }
    }
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


static unsigned get_hex(unsigned max)
{
    unsigned result = 0;
    unsigned c = skip_space_peek();
    for (unsigned i = 0; i <= max; ++i) {
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


static void invoke(unsigned * vt)
{
    __memory_barrier();
    asm volatile ("mov sp,%0\n" "bx %1\n" :: "r" (vt[0]), "r" (vt[1]));
    __builtin_unreachable();
}


static void command_abort(const char * s)
{
    send_string(s);
    send('\n');
    while (SSI->sr & 16);
    invoke((unsigned *) *VTABLE);
}


static void command_error()
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


static unsigned char * get_address(void)
{
    unsigned char * r = (unsigned char *) get_hex(7);
    command_end();
    return r;
}


static void command_go(void)
{
    *VTABLE = (unsigned) get_address();
    command_abort("Go");
}


static void command_read(void)
{
    unsigned char * address = get_address();

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
    unsigned char * address = (unsigned char *) get_hex(7);
    unsigned words[4];
    unsigned char * bytes = (unsigned char *) words;
    unsigned n = 0;
    for (; n != sizeof words && skip_space_peek() != '\n'; ++n)
        bytes[n] = get_hex(1);

    command_end();

    unsigned end = (unsigned) address + n;
    if (end < n)
        command_abort("? Wrap");

    if ((unsigned) address <= 0x20002000 &&
        (end > STACK_TOP - 128 || end > BASE))
        command_abort("? Monitor");

    if ((unsigned) address >= 0x20000000) {
        // Memory.
        for (unsigned i = n; i--;)
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
}


static void command_erase(void)
{
    unsigned char * address = get_address();

    if ((unsigned) address & ~0xfc00)
        command_abort("? Erase Address");

    if (!unlocked)
        command_abort("? Locked");

    FLASHCTRL->fma = (unsigned) address;
    FLASHCTRL->fmc = 0xa4420002;
    while (FLASHCTRL->fmc & 2);
}


static void command_unlock(void)
{
    if ((unsigned) get_address() != 0x2f5bf358)
        command_error();
    unlocked = 'U';
}


static void command(void)
{
    next = ' ';
    unsigned c = skip_space_peek();
    next = ' ';
    if (c == 'R') {
        command_read();
        return;
    }
    else if (c == 'E')
        command_erase();
    else if (c == 'W')
        command_write();
    else if (c == 'U')
        command_unlock();
    else if (c == 'P')
        command_end();
    else if (c == 'G')
        command_go();
    else if (c != '\n')
        command_error();

    send(c);
}


static void go (void)
{
    __interrupt_disable();

    SSI = (ssi_t *) 0x40008000;

    unlocked = 0;

    while (1) {
        command();
        send('\n');
    }
}


static __attribute__ ((section(".boottext")))
void alternate_boot(void)
{
    unsigned * vt = (unsigned *) 0x800;
    if (*vt >= 0x20000000 && *vt <= 0x20002000) {
        *VTABLE = (unsigned) vt;
        invoke(vt);
    }
}


static __attribute__ ((section(".boottext")))
void monitor_reloc(void)
{
    const unsigned char * src = &__unreloc_start;
    unsigned char * dest = &__text_start;
    for (unsigned i = 0; i != 0x3c0; ++i)
        dest[i] = src[i];

    __memory_barrier();
    //*VTABLE = (unsigned) dest; -- interrupts are disabled.
    asm volatile("bx %0" :: "r"(((unsigned*)dest)[1]));
    __builtin_unreachable();
}


static __attribute__ ((section(".boottext")))
void first(void)
{
    __interrupt_disable();
    volatile ssi_t * SSI = (ssi_t *) 0x40008000;

    SC_TAIL->rcgc[2] = 31;              // GPIOs.

    // Read the SSI data input pin, PA4.  If it is pulled high, try an alternate
    // boot source.
    if (PA->data[16] & 16)
        alternate_boot();

    SC_TAIL->rcgc[1] = 16;              // SSI.
    SC_TAIL->usecrl = 25 - 1;           // Flash speed.

    SSI->cr[1] = 0;                     // Disable.
    SSI->cr[0] = 0xcf;                  // Full rate, SPH=1, SPO=1, 16 bits.
    SSI->cpsr = 2;                      // Prescalar /2.

    PA->afsel = 0x3c;                   // Set SSI pins to alt. function.

    SSI->cr[1] = 2;                     // Master, enable.

    monitor_reloc();
}


// By the time we have relocated, we have disabled interrupts.
static __attribute__ ((section(".boottext")))
void dummy_int(void)
{
}


void * const boot_vtable[] __attribute__((section (".bootstart"),
                                          externally_visible)) = {
    (void*) STACK_TOP, first,
    [2 ... VTABLE_SIZE - 1] = dummy_int
};

void * const vtable[] __attribute__((section (".start"),
                                     externally_visible)) = {
    (void*) STACK_TOP, go };
