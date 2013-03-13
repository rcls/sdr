
#include "registers.h"
#include "../lib/registers.h"

#include <stdbool.h>

typedef struct command_t {
    const char * name;
    void (* function)(const char *);
} command_t;

void * const vtable[] __attribute__((section (".start"),
                                     externally_visible));
static void run(void);

unsigned rxchar(void)
{
    // RX a byte from the usb stream, by reading channel 0 from the FPGA.
    // We try and be smart about requesting the data.
    while (1) {
        unsigned s = SSI->sr;
        if (s & 4) {
            unsigned w = SSI->dr;
            if (w && w < 256)
                return w;
        }
        if ((s & 16) != 16)
            SSI->dr = 0;
    }
}

static void txword(unsigned val)
{
    while ((SSI->sr & 2) == 0);
    SSI->dr = val;
}

static inline void write_reg(unsigned r, unsigned v)
{
    txword(r * 512 + 256 + (v & 255));
}


static void putchar(unsigned c)
{
    txword(0x100 + c);
}

static void putstring(const char * s)
{
    while (*s)
        putchar(255 & *s++);
}


static const char * skipstring(const char * s)
{
    while (*s++);
    return s;
}


// Get a line split into a list on nul terminated words finishing with an extra
// nul.  Might take up to 2 extra for the final nuls.
static void getline(char * restrict line, unsigned max)
{
    bool skipspace = true;
    unsigned i = 0;
    while (i < max) {
        unsigned c = rxchar();
        if (c == ' ') {
            if (skipspace)
                continue;

            line[i++] = 0;
            skipspace = true;
            continue;
        }
        if (c == '\n')
            break;

        skipspace = false;
        line[i++] = c;
    }
    line[i++] = 0;
    line[i++] = 0;
}


static bool streq(const char * a, const char * b)
{
    for (unsigned i = 0;; ++i)
        if (a[i] != b[i])
            return false;
        else if (!a[i])
            return true;
}


static __attribute__((noreturn)) void rerun(const char * m)
{
    putstring(m);
    asm volatile("mov sp,%0\n\tbx %1\n" :: "r"(0x20002000), "r"(run));
    __builtin_unreachable();
}


static void command_reboot(const char * params)
{
    putstring("reboot\n");
    while (SSI->sr & 16);
    while (true)
        SCB->apint = 0x05fa0004;
}


static void command_echo(const char * params)
{
    bool sp = false;
    while (*params) {
        if (sp)
            putchar(' ');
        sp = true;
        putstring(params);
        params = skipstring(params);
    }
    putchar('\n');
}


static unsigned hextou(const char * h)
{
    unsigned result = 0;
    for (; *h; ++h) {
        unsigned c = *h;
        if (c >= 'a')
            c -= 32;                    // Upper case.
        c -= '0';
        if (c >= 10) {
            c -= 'A' - '0' - 10;
            if (c < 10 || c > 15)
                rerun("Illegal hex\n");
        }
        result = result * 16 + c;
    }
    return result;
}


static unsigned dectou(const char * h)
{
    unsigned result = 0;
    for (; *h; ++h) {
        unsigned c = *h - '0';
        if (c >= 10)
            rerun("Illegal decimal\n");
        result = result * 10 + c;
    }
    return result;
}


static void command_write(const char * params)
{
    unsigned r = hextou(params);
    unsigned v = hextou(skipstring(params));
    write_reg(r, v);
}


static void command_tune(const char * params)
{
    unsigned c = dectou(params);
    unsigned f;

    if (params[-1] == 'h') {
        f = hextou(skipstring(params));
    }
    else {
        f = dectou(skipstring(params));
        unsigned hi = f * 67;
        unsigned long long big = f * 467567319ull;
        f = hi + (big >> 32);
    }
    write_reg(c * 4 + 16, f);
    write_reg(c * 4 + 17, f >> 8);
    write_reg(c * 4 + 18, f >> 16);
}


static void command_gain(const char * params)
{
    unsigned c = dectou(params);
    params = skipstring(params);
    unsigned g = 0;
    if (*params)
        g = dectou(params) + 128;
    write_reg(c * 4 + 19, g);
}


static void command_bandpass(const char * params)
{
    unsigned f = dectou(params);
    unsigned g = dectou(skipstring(params));
    f = f / 5 * 8 + f % 5;
    write_reg(REG_BANDPASS_FREQ, f);
    write_reg(REG_BANDPASS_GAIN, g | 0x80);
}


static void command_nop(const char * params)
{
}


static const command_t commands[] = {
    { "wr", command_write },
    { "echo", command_echo },
    { "reboot", command_reboot },
    { "bandpass", command_bandpass },
    { "tune", command_tune },
    { "tuneh", command_tune },
    { "gain", command_gain },
    { "nop", command_nop },
    { "", command_nop },
    { NULL, NULL }
};


static void command(void)
{
    char line[82];
    getline(line, 80);

    for (const command_t * c = commands; c->name; ++c) {
        if (streq(c->name, line)) {
            c->function(skipstring(line));
            return;
        }
    }
    putstring("Unknown command: '");
    putstring(line);
    putstring("'\n");
}


static __attribute__((noreturn)) void run(void)
{
    while (1)
        command();
}


static void start(void)
{
    __interrupt_disable();
    SC->rcgc[2] = 31;                   // GPIOs.
    SC->rcgc[1] = 16;                   // SSI.

    SSI->cr[1] = 0;                     // Disable.
    SSI->cr[0] = 0x01cf;                // /1, SPH=1, SPO=1, SPI, 16 bits.
    SSI->cpsr = 2;                      // Prescalar /2.

    PA->afsel = 0x3c;                   // Set SSI pins to alt. function.

    SSI->cr[1] = 2;                     // Master, enable.

    SC->rcgc[2] |= 16;
    PE->dir |= 2;

    rerun("Welcome\n");
}


static void dummy_int(void)
{
}


void * const vtable[] = {
    (void*) 0x20002000, start,
    [2 ... 37] = dummy_int
};
