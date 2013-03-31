
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
        if (c == '\n' || c == '\r')
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
    asm volatile("mov sp,%0\n\tb.w %1\n" :: "r"(0x20002000), "i"(run));
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
    if (h[0] == '0' && h[1] == 'x')
        h += 2;

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
    if (h[0] == '0' && h[1] == 'x')
        return hextou(h);

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


static void read_registers(unsigned reg, unsigned count,
                           unsigned char * restrict result)
{
    // Flush SSI before we start...
    while (SSI->sr & 20)
        SSI->dr;
    unsigned leadin = count;
    if (leadin > 8)
        leadin = 8;
    for (unsigned i = 0; i < leadin; ++i)
        SSI->dr = (reg + i) * 512;
    for (unsigned i = 0; i < count; ++i) {
        while (!(SSI->sr & 4));         // Wait for data.
        unsigned v = SSI->dr;
        if (v >> 8 != (reg + i) * 2)
            rerun("Bogus register read\n");
        result[i] = v;
        if (i + leadin < count)
            SSI->dr = (reg + i + leadin) * 512;
    }
}


static void command_read(char * params)
{
    unsigned base = hextou(params);
    const char * p = skipstring(params);
    unsigned count = 1;
    if (*p)
        count = dectou(p);

    for (unsigned row = base; row != base + count;) {
        unsigned amount = base + count - row;
        if (amount > 16)
            amount = 16;
        unsigned char responses[16];
        read_registers(row, amount, responses);
        printf("%02x:", row);
        for (unsigned i = 0; i != amount; ++i)
            printf(" %02x", responses[i]);
        printf("\n");
        row += amount;
    }
}


static void tune_report(int channel)
{
    union {
        unsigned char c[4];
        unsigned u;
    } response;
    read_registers(REG_RADIO_FREQ(channel), 4, response.c);
    unsigned rawf = response.u & 0xffffff;
    unsigned long long longf = 250000000ull * 256 * rawf;
    unsigned hertz = longf >> 32;
    if (channel < 3) {
        printf("%d: %9d Hz, gain = %d * 6dB\n",
               channel, hertz, response.c[3] & 15);
        return;
    }

    read_registers(REG_PLL_DECAY, 1, response.c);
    printf("%d: %9d Hz, gain = %d,%d * 6dB, decay = %d\n",
           channel, hertz, response.c[3] & 15, (response.c[3] >> 4) & 15,
           response.c[0]);
}


static void command_tune(char * params)
{
    if (*params == 0) {
        for (int i = 0; i != 4; ++i)
            tune_report(i);
        unsigned char a;
        read_registers(REG_AUDIO_CHANNEL, 1, &a);
        printf("Audio is channel %i\n", a & 3);
        return;
    }

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


static void command_pll_report(char * params)
{
    // The parameters from the VHDL...
    txword(REG_PLL_CAPTURE * 512);      // Capture the pll regs.
    unsigned reg[3];
    read_registers(REG_PLL_FREQ, sizeof reg, (unsigned char *) reg);
    // Convert the frequencies to 32+32 fixed point hertz.
    long long frq = reg[0] * 250000000ull;
    unsigned char decay;
    read_registers(REG_PLL_DECAY, 1, &decay);
    if (decay >= 12)
        decay -= 4;

    const int target_width = 10;
    const int beta_base = 8;
    const int alpha_base = beta_base + 3;
    const int error_width = 32;
    const int error_drop = 12;

    const int right =
        // Scaling of error
        17 + 3 * beta_base + target_width + 3 *decay - error_drop
        // Left shift by alpha_base + decay
        - alpha_base - decay
        // Convert top 32-bits to (mod 2**32).
        - error_width;
    int ierr = reg[1];
    char errs = ' ';
    if (ierr < 0) {
        errs = '-';
        ierr = -ierr;
    }
    long long err;
    if (right >= 0)
        err = 250000000ull * (ierr >> right);
    else
        err = 250000000ull * (ierr << -right);

    // FIXME - redo the error to frequency conversion.
    printf("%d.%06d  %c%d.%06d %x %x %d %d\n",
           (unsigned) (frq >> 32),
           (unsigned) ((frq & 0xfffffffful) * 1000000 >> 32),
           errs, (unsigned) (err >> 32),
           (unsigned) ((err & 0xfffffffful) * 1000000 >> 32),
           reg[1], reg[2],
           32 - __builtin_clz(reg[1] < 0 ? -reg[1] : reg[1]),
           32 - __builtin_clz(reg[2]));
}


static void command_gain(char * params)
{
    unsigned c = dectou(params);
    const char * p = skipstring(params);
    unsigned g = dectou(p);
    p = skipstring(p);
    if (*p)
        g = g + 16 * dectou(p);
    else if (c == 3 && g < 16)
        g *= 17;
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
    { "rd", command_read },
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
    { "pll", command_pll_report },
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
    SSI->cr[0] = 0x01cf;                // SPH=1, SPO=1, SPI, 16 bits.
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
