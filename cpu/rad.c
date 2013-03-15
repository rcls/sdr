
#include "printf.h"
#include "registers.h"
#include "../lib/registers.h"

#include <stdbool.h>

typedef struct command_t {
    const char * name;
    void (* function)(char *);
} command_t;

void * const vtable[] __attribute__((section (".start"),
                                     externally_visible));
static void run(void);

unsigned rxchar(void)
{
    // RX a byte from the usb stream, by reading channel 0 from the FPGA.  We
    // try and be smart about requesting the data.
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

static inline void write_reg(unsigned r, unsigned v)
{
    txword(r * 512 + 256 + (v & 255));
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
    unsigned i = 0;
    bool skipspace = true;
    while (i < max) {
        unsigned c = rxchar();
        if (c == 27) {
            skipspace = true;
            i = 0;
            continue;
        }
        if (c == ' ') {
            if (!skipspace) {
                line[i++] = 0;
                skipspace = true;
            }
            continue;
        }
        if (c == '\n')
            break;

        line[i++] = c;
        skipspace = false;
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
    puts(m);
    asm volatile("mov sp,%0\n\tb.n %1\n" :: "r"(0x20002000), "i"(run));
    __builtin_unreachable();
}


static void command_reboot(char * params)
{
    puts("Rebooting...\n");
    while (SSI->sr & 16);
    while (true)
        SCB->apint = 0x05fa0004;
}


static void command_echo(char * params)
{
    bool sp = false;
    for (const char * p = params; *p; p = skipstring(p)) {
        if (sp)
            putchar(' ');
        sp = true;
        puts(p);
    }
    putchar('\n');
}


static void command_flash(char * params)
{
    // Flags can be used:
    // </> : leave CS low before/after operation.
    // ? : echo on.
    bool cont_before = false;
    bool cont_after = false;
    bool echo = false;

    // Validate everything first & squash down to an array of nibbles.
    unsigned prev = 0;
    char * end = params;
    for (const char * p = params; *p || prev; ++p) {
        prev = *p;
        switch (*p) {
        case 0:
            continue;
        case '<':
            cont_before = true;
            continue;
        case '>':
            cont_after = true;
            continue;
        case '?':
            echo = true;
            continue;
        }

        unsigned c = *p & 255;
        if (c >= 'a')
            c &= ~32;
        c -= '0';
        if (c >= 10) {
            c -= 'A' - '0' - 10;
            if (c < 10 || c > 15)
                rerun("Illegal flash command.\n");
        }
        *end++ = c;
    }
    unsigned length = (end - params) * 8;
    unsigned rx = 0;
    unsigned tx = 0;
    unsigned word = 0;
    if (!cont_before)
        write_reg(REG_FLASH, FLASH_CS);
    // Flush SSI before we start...
    while (SSI->sr & 20)
        SSI->dr;
    while (rx < length || tx < length) {
        if (tx == length && (SSI->sr & 20) == 0)
            rerun("Huh?  Idle.\n");
        while (SSI->sr & 4) {
            unsigned in = SSI->dr;
            if ((in >> 8) == REG_FLASH * 2 + 1 && rx < tx && (rx++ & 1)) {
                word = word * 2 + (in & FLASH_DATA ? 1 : 0);
                if (echo && (rx & 7) == 0)
                    printf("%x", word & 15);
            }
        }
        if (tx < length && (SSI->sr & 2)) {
            unsigned n = params[tx >> 3];
            n <<= (tx >> 1) & 3;
            SSI->dr = REG_FLASH * 512 + 256
                + (n & 8 ? FLASH_DATA : 0)
                + (tx & 1 ? FLASH_CLK : 0);
            ++tx;
        }
    }
    if (!cont_after)
        write_reg(REG_FLASH, FLASH_CS);
    if (echo)
        putchar('\n');
}


static unsigned hextou(const char * h)
{
    unsigned result = 0;
    do {
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
    while (*++h);
    return result;
}


static unsigned dectou(const char * h)
{
    unsigned result = 0;
    do {
        unsigned c = *h - '0';
        if (c >= 10)
            rerun("Illegal decimal\n");
        result = result * 10 + c;
    }
    while (*++h);
    return result;
}


static void command_write(char * params)
{
    unsigned r = hextou(params);
    unsigned v = hextou(skipstring(params));
    write_reg(r, v);
}


static void command_tune(char * params)
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


static void command_gain(char * params)
{
    unsigned c = dectou(params);
    const char * q = skipstring(params);
    unsigned g = 0;
    if (*q)
        g = dectou(q) + 128;
    write_reg(c * 4 + 19, g);
}


static void command_bandpass(char * params)
{
    unsigned f = dectou(params);
    unsigned g = dectou(skipstring(params));
    f = f / 5 * 8 + f % 5;
    write_reg(REG_BANDPASS_FREQ, f);
    write_reg(REG_BANDPASS_GAIN, g | 0x80);
}


static void command_R(char * params)
{
    unsigned char * address = (unsigned char *) hextou(params);
    const char * q = skipstring(params);
    unsigned length = 16;
    if (*q)
        length = dectou(q);
    while (length) {
        unsigned ll = 16;
        if (length < 16)
            ll = length;

        printf("%p", address);
        unsigned sep = ':';
        for (unsigned i = 0; i != ll; ++i) {
            printf("%c%02x", sep, address[i]);
            sep = ' ';
        }
        putchar('\n');

        length -= ll;
        address += ll;
    }
}


static void command_W(char * params)
{
    unsigned char * address = (unsigned char *) hextou(params);
    int index = 0;
    for (const char * p = skipstring(params); *p; p = skipstring(p))
        params[index++] = hextou(p);
    for (int i = 0; i != index; ++i)
        address[i] = params[i];
}


static void command_G(char * params)
{
    const unsigned * address = (const unsigned *) hextou(params);
    if (*skipstring(params))
        rerun("G only takes 1 parameter\n");

    asm volatile("mov sp,%0\nbx %1\n" :: "r"(address[0]), "r"(address[1]));
    __builtin_unreachable();
}


static void command_adc(char * params)
{
    for (const char * p = params; *p; p = skipstring(p)) {
        write_reg(REG_ADC, ADC_SEN | ADC_SCLK);
        write_reg(REG_ADC, ADC_SEN);

        if (streq(p, "reset")) {
            write_reg(REG_ADC, ADC_SEN|ADC_RESET);
            write_reg(REG_ADC, ADC_SEN);
            continue;
        }

        unsigned v = hextou(p);
        for (int i = 32768; i; i >>= 1) {
            write_reg(REG_ADC, (v & i ? ADC_SDATA : 0) | ADC_SCLK);
            write_reg(REG_ADC, v & i ? ADC_SDATA : 0);
        }
    }
    write_reg(REG_ADC, ADC_SEN | ADC_SCLK);
    write_reg(REG_ADC, ADC_SEN);
}



static void command_nop(char * params)
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
    { "R", command_R },
    { "W", command_W },
    { "G", command_G },
    { "nop", command_nop },
    { "flash", command_flash },
    { "adc", command_adc },
    { "", command_nop },
    { NULL, NULL }
};


static void command(void)
{
    char line[82];
    getline(line, 80);

    for (const command_t * c = commands; c->name; ++c) {
        if (streq(c->name, line)) {
            c->function((char *) skipstring(line));
            return;
        }
    }
    printf("Unknown command: '%s'\n", line);
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
    SSI->cr[0] = 0xcf;                  // SPH=1, SPO=1, SPI, 16 bits.
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
