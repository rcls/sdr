#define _GNU_SOURCE
#include <err.h>
#include <fcntl.h>
#include <stdarg.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#include "lib/util.h"
#include "lib/usb.h"
#include "lib/registers.h"

#define PAGE_LEN 264


static unsigned char buffer[4096];

static libusb_device_handle * dev;

static void close_port (void)
{
    usb_close(dev);
}


static ssize_t cookie_write(void * cookie, const char * buf, size_t size)
{
    usb_send_bytes(dev, buf, size);
    return size;
}


static cookie_io_functions_t cookie_io = { NULL, cookie_write, NULL, NULL };


static int buffer_num;

static void write_page (FILE * o, const unsigned char * data, unsigned page)
{
    buffer_num = !buffer_num;

    unsigned buffer_write = buffer_num ? 0x84 : 0x87;

    fprintf(o, "flash %02x 000000 >\n", buffer_write);
    for (unsigned start = 0; start < PAGE_LEN;) {
        unsigned l = PAGE_LEN - start;
        if (l > 16)
            l = 16;
        fprintf(o, "flash <> ");
        for (unsigned i = start; i != start + l; ++i)
            fprintf(o, "%02x", data[i]);
        fprintf(o, "\n");
        start += l;
    }
    fprintf(o, "flash\n");

    // Now wait for idle.
    int i = 0;
    fprintf(o, "flash d7 >\n");
    do {
        if (++i >= 10000)
            errx(1, "Timeout waiting for idle");
        fprintf(o, "flash <>? 00\n");
        fflush(o);
        int n;
        do {
            n = usb_read(dev, buffer, sizeof buffer);
        }
        while (n == 0);
        if (n != 3 || buffer[2] != '\n')
            errx(1, "Huh '%.*s'?\n", n, buffer);
        buffer[2] = 0;
    }
    while (strtoul((char*) buffer, NULL, 16) < 128);

    fprintf(o, "flash\n");
    unsigned page_write = buffer_num ? 0x83 : 0x86;
    fprintf(o, "flash %02x %06x\n", page_write, page * 512);
    fflush(o);
}


static const unsigned char * bitfile_find_stream(const unsigned char * p,
                                                 const unsigned char ** pend)
{
    const unsigned char * end = *pend;

    static unsigned char header[] = {
        0, 9, 0x0f, 0xf0, 0x0f, 0xf0, 0x0f, 0xf0, 0x0f, 0xf0, 0, 0, 1 };

    if (end - p < sizeof(header) || memcmp(p, header, sizeof header) != 0)
        errx(1, "File does not start with header.\n");

    p += sizeof header;

    while (1) {
        if (end - p < 3)
            errx(1, "EOF, no data.\n");

        int section = *p;
        if (section == 'e')
            // This is it.
            break;

        if (section < 'a' || section > 'd')
            errx(1, "Section 0x%02x is unknown\n", section);

        int len = p[1] * 256 + p[2];
        p += 3;
        if (end - p < len)
            errx(1, "Section '%c' length %u overruns...\n", section, len);

        static const char * const tags[] = {
            "Design", "Part", "Date", "Time"
        };
        fprintf(stderr, "%s\t: %.*s\n", tags[section - 'a'], len, p);
        p += len;
    }

    unsigned len = (p[1] << 24) + p[2] * 65536 + p[3] * 256 + p[4];
    p += 5;

    if (end - p < len)
        errx(1, "Data length overruns file.\n");

    if (end - p > len)
        warnx("Data followed by %zu trailing bytes.\n", end - p - len);

    fprintf(stderr, "Data block is %u bytes long.\n", len);

    *pend = p + len;
    return p;
}


int main(int argc, char * argv[])
{
    dev = usb_open();

    atexit(close_port);
    usb_flush(dev);

    FILE * o = fopencookie(dev, "w", cookie_io);

    fprintf(o, "nop\n");
    fprintf(o, "wr %02x %02x\n", REG_XMIT, XMIT_CPU_SSI|XMIT_LOW_LATENCY);
    fprintf(o, "flash ? 9f00000000000000\n");
    fflush(o);

    int len = usb_read(dev, buffer, sizeof buffer);
    fprintf(stderr, "%.*s", len, buffer);

    if (argc == 1)
        return 0;

    int file = checki(open(argv[1], O_RDONLY), "open");
    unsigned char * blob = NULL;
    size_t offset = 0;
    size_t size = 0;
    slurp_file(file, &blob, &offset, &size);

    // Make sure we have enough room for padding...
    if (size < offset + PAGE_LEN)
        blob = xrealloc (blob, offset + PAGE_LEN);

    const unsigned char * end = blob + offset;
    const unsigned char * q = bitfile_find_stream (blob, &end);
    memset ((unsigned char *) end, 0xff, PAGE_LEN);

    unsigned pages = (end - q + PAGE_LEN - 1) / PAGE_LEN;

    for (unsigned i = 0; i < pages; ++i) {
        fprintf(stderr, "\rpage %i", i);
        write_page(o, q + i * PAGE_LEN, i);
    }
    fclose(o);
    fprintf(stderr, "\n");
    return 0;
}
