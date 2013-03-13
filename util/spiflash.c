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


static unsigned char buffer[131072];


static libusb_device_handle * dev;


static void close_port (void)
{
    usb_close(dev);
}


static void read_exact(unsigned char * buf, int len)
{
    while (len > 0) {
        int done = usb_read(dev, buf, len);
        if (done == 0)
            errx (1, "short read");
        buf += done;
        len -= done;
    }
}


static void add_be (uint64_t word, int bits, bool readback)
{
    for (int i = 0; i != bits; ++i) {
        unsigned data = ((word >> (bits - i - 1)) & 1) ? FLASH_DATA : 0;
        usb_write_reg(dev, REG_FLASH, data | (readback ? FLASH_XMIT : 0));
        usb_write_reg(dev, REG_FLASH, data | FLASH_CLK);
    }
}


static void add_bytes (const unsigned char * data, int bytes, bool readback)
{
    for (int i = 0; i != bytes; ++i)
        add_be(data[i], 8, readback);
}


static void read_decode_bytes(unsigned char * buffer, int bytes)
{
    unsigned char bits[bytes * 8];
    read_exact(bits, bytes * 8);
    for (int i = 0; i != bytes; ++i) {
        int byte = 0;
        for (int j = 0; j != 8; ++j) {
            unsigned c = bits[8 * i + j];
            if (c & FLASH_OVERRUN)
                err(1, "Overrun at byte %i offset %i\n", i, j);
            byte = byte * 2 + !!(c & FLASH_RECV);
        }
        buffer[i] = byte;
    }
}


static void chip_select(void)
{
    usb_write_reg(dev, REG_FLASH, FLASH_CS);
}

static int buffer_num;

static void write_page (const unsigned char * data, unsigned page)
{
    chip_select();

    buffer_num = !buffer_num;

    unsigned buffer_write = buffer_num ? 0x84 : 0x87;

    add_be(buffer_write << 24, 32, false);
    add_bytes(data, PAGE_LEN, false);

    chip_select();

    // Now wait for idle.
    chip_select();
    add_be(0xd7, 8, false);
    int i = 0;
    do {
        if (++i >= 10000)
            errx(1, "Timeout waiting for idle");
        add_be(0, 8, true);
        read_decode_bytes(buffer, 1);
    }
    while (!(*buffer & 0x80));

    chip_select();

    unsigned page_write = buffer_num ? 0x83 : 0x86;
    add_be(page_write, 8, false);
    add_be(page * 512, 24, false);
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

    // Select SPI readback.
    // Make sure CS, SI are high.
    usb_write_reg(dev, REG_USB, 0);         // No delay, we have work to do.
    usb_write_reg(dev, REG_XMIT, XMIT_FLASH|XMIT_LOW_LATENCY);
    usb_write_reg(dev, REG_FLASH, FLASH_CS | FLASH_DATA);
    usb_write_reg(dev, REG_FLASH, FLASH_CS | FLASH_DATA | FLASH_XMIT);
    usb_write_reg(dev, REG_FLASH, FLASH_CS | FLASH_DATA);
    usb_write_reg(dev, REG_FLASH, FLASH_CS | FLASH_DATA | FLASH_XMIT);

    usb_flush(dev);

    // Now grab data.  We should get exactly 1 byte, and the overflow bit
    // should be off.
    usb_write_reg(dev, REG_FLASH, FLASH_CS | FLASH_DATA);

    read_exact(buffer, 1);
    if (buffer[0] & FLASH_OVERRUN)
        errx(1, "Still have overrun...\n");
    /* check_idle(); */

    chip_select();

    add_be(0x9f, 8, false);
    add_be(0, 56, true);

    chip_select();

    read_decode_bytes(buffer, 7);
    fprintf(stderr, "ID:");
    for (int i = 0; i != 7; ++i)
        fprintf(stderr, " %02x", buffer[i]);
    fprintf(stderr, "\n");

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
        write_page(q + i * PAGE_LEN, i);
    }
    fprintf(stderr, "\n");

    return 0;
}
