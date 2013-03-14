
#include "printf.h"
#include "registers.h"
#include "stdarg.h"
#include "stdbool.h"

void txword(unsigned val)
{
    while ((SSI->sr & 2) == 0);
    SSI->dr = val;
}


void putchar(int byte)
{
    txword(0x100 + byte);
}


void puts(const char * s)
{
    for (; *s; s++)
        putchar (*s);
}


static void format_string(const char * s, unsigned width, unsigned char fill)
{
    for (const char * e = s; *e; ++e, --width)
        if (width == 0)
            break;
    for (; width != 0; --width)
        putchar(fill);
    for (; *s; ++s)
        putchar(*s);
}


static void format_number(unsigned long value, unsigned base, unsigned lower,
                          bool sgn, unsigned width, unsigned char fill)
{
    unsigned char c[23];
    unsigned char * p = c;
    if (sgn && (long) value < 0)
        value = -value;
    else
        sgn = false;

    do {
        unsigned digit = value % base;
        if (digit >= 10)
            digit += 'A' - '0' - 10 + lower;
        *p++ = digit + '0';
        value /= base;
    }
    while (value);

    if (!sgn)
        ;
    else if (fill == ' ')
        *p++ = '-';
    else {
        putchar('-');
        if (width > 0)
            --width;
    }

    while (width > p - c) {
        putchar(fill);
        --width;
    }

    while (p != c)
        putchar(*--p);
}


void printf (const char * restrict f, ...)
{
    va_list args;
    va_start (args, f);
    const unsigned char * s;

    for (s = (const unsigned char *) f; *s; ++s) {
        if (*s != '%') {
            putchar(*s);
            continue;
        }

        ++s;
        unsigned char fill = ' ';
        if (*s == '0')
            fill = '0';

        unsigned width = 0;
        for (; *s >= '0' && *s <= '9'; ++s)
            width = width * 10 + *s - '0';
        unsigned base = 0;
        unsigned lower = 0;
        bool sgn = false;
        unsigned lng = 0;
        for (; *s == 'l'; ++s)
            ++lng;
        switch (*s) {                   // We don't cope with '\0'.  Who cares.
        case 'c': ;
            putchar(va_arg(args, unsigned)); // FIXME - modifiers.
            break;
        case 'x':
            lower = 0x20;
        case 'X':
            base = 16;
            break;
        case 'i':
        case 'd':
            sgn = true;
        case 'u':
            base = 10;
            break;
        case 'o':
            base = 8;
            break;
        case 'p': {
            void * value = va_arg(args, void *);
            if (width == 0)
                width = 8;
            format_number((unsigned) value, 16, 32, false, width, '0');
            break;
        }
        case 's':
            format_string(va_arg(args, const char *), width, fill);
            break;
        }
        if (base != 0) {
            unsigned long value;
            if (lng)
                value = va_arg(args, unsigned long);
            else if (sgn)
                value = va_arg(args, int);
            else
                value = va_arg(args, unsigned);
            format_number(value, base, lower, sgn, width, fill);
        }
    }

    va_end(args);
}
