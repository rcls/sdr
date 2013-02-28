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
#include "lib/registers.h"

#define PAGE_LEN 264


static unsigned char buffer[131072];


// Use serial or libusb?
#if 0
#include <libusb-1.0/libusb.h>
#include "lib/usb.h"

static libusb_device_handle * dev;

static void open_port (void)
{
    dev = usb_open();
}


static void close_port (void)
{
    usb_close(dev);
}


static void write_exact (const unsigned char * start, unsigned len)
{
    usb_send_bytes(dev, start, len);
}


static void read_exact(unsigned char * buf, int len)
{
    while (len > 0) {
        unsigned char bounce[512];
        int done;
        int r = libusb_bulk_transfer (dev, USB_IN_EP, bounce, 512, &done, 1000);
        if (r < 0 || done < 2)
            errx (1, "read: %i %i", r, done);
        done -= 2;
        if (done > len)
            errx(1, "Expect %i got %i", len, done);
        memcpy(buf, bounce + 2, done);
        buf += done;
        len -= done;
        if (done != 0 && len != 0)
            fprintf(stderr, "Did %i, %i to go\n", done, len);
    }
}


static void flush_ser(void)
{
    unsigned char bounce[512];
    int done;
    while (libusb_bulk_transfer (dev, USB_IN_EP, bounce, 512, &done, 1000) == 0
           && done > 2);
}
#else
#include <termios.h>

static int serial_port;

static void open_port (void)
{
    serial_port = open ("/dev/ttyRadio0", O_RDWR|O_NOCTTY);
    if (serial_port < 0)
        err (1, "open /dev/ttyRadio0\n");

    struct termios options;

    if (tcgetattr (serial_port, &options) < 0)
        err (1, "tcgetattr failed");

    cfmakeraw (&options);

    options.c_cflag |= CREAD | CLOCAL;

    //options.c_lflag &= ~(/* ISIG*/ /* | TOSTOP*/ | FLUSHO);
    //options.c_lflag |= NOFLSH;

    options.c_iflag &= ~(IXOFF | ISTRIP | IMAXBEL);
    options.c_iflag |= BRKINT;

    options.c_cc[VMIN] = 0;
    options.c_cc[VTIME] = 2;

    if (tcsetattr (serial_port, TCSANOW, &options) < 0)
        err (1, "tcsetattr failed\n");

    if (tcflush (serial_port, TCIOFLUSH) < 0)
        err (1, "tcflush failed\n");
}


static void close_port(void)
{
    close(serial_port);
}


static void write_exact (const unsigned char * start, unsigned len)
{
    /* fprintf(stderr, "Send: "); */
    /* for (int i = 0; i != len; ++i) */
    /*     fprintf(stderr, " %02x", start[i]); */
    /* fprintf(stderr, "\n"); */

    while (len) {
        int r = write (serial_port, start, len);
        if (r < 0)
            err(1, "write");
        start += r;
        len -= r;
    }
}


void read_exact(unsigned char * buf, int len)
{
    while (len > 0) {
        int r = read (serial_port, buf, len + 1);
        if (r < 0)
            err (1, "read");
        if (r == 0)
            errx (1, "EOF");
        /* fprintf (stderr, "Read %i of %i\n", r, len); */
        /* for (int i = 0; i != r; ++i) */
        /*     fprintf(stderr, " %02x", buf[i]); */
        /* fprintf(stderr, "\n"); */
        if (r > len)
            err(1, "Too much data: %i > %i\n", r, len);
        buf += r;
        len -= r;
        /* if (len != 0) */
        /*     fprintf (stderr, "Did %i, to go %i\n", r, len); */
    }
}


void check_idle(void)
{
    unsigned char buf;
    if (read(serial_port, &buf, 1) > 0)
        errx(1, "Not idle.\n");
}


void flush_ser(void)
{
    unsigned char buf[512];
    while (read(serial_port, buf, 512) > 0);
}
#endif

static unsigned char * add_be (unsigned char * p,
                               uint64_t word,
                               int bits, bool readback)
{
    for (int i = 0; i != bits; ++i) {
        unsigned data = ((word >> (bits - i - 1)) & 1) ? FLASH_DATA : 0;
        *p++ = REG_FLASH;
        *p++ = data | (readback ? FLASH_XMIT : 0);
        *p++ = REG_FLASH;
        *p++ = data | FLASH_CLK;
    }
    return p;
}


unsigned char * add_bytes (unsigned char * p,
                           const unsigned char * data,
                           int bytes, bool readback)
{
    for (int i = 0; i != bytes; ++i)
        p = add_be(p, data[i], 8, readback);
    return p;
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


static unsigned char * chip_select(unsigned char * p)
{
    *p++ = REG_FLASH;
    *p++ = FLASH_CS;
    return p;
}

static void write_page (const unsigned char * data, unsigned page)
{
    unsigned char * p = chip_select(buffer);

    p = add_be(p, 0x84000000, 32, false);
    p = add_bytes(p, data, PAGE_LEN, false);

    p = chip_select(p);

    p = add_be(p, 0x83, 8, false);
    p = add_be(p, page * 512, 24, false);

    p = chip_select(p);

    write_exact(buffer, p - buffer);

    // Now wait for idle.
    p = chip_select(buffer);
    p = add_be(p, 0xd7, 8, false);
    int i = 0;
    do {
        if (++i >= 10000)
            errx(1, "Timeout waiting for idle");
        p = add_be(p, 0, 8, true);
        write_exact(buffer, p - buffer);
        read_decode_bytes(buffer, 1);
        p = buffer;
    }
    while (!(*buffer & 0x80));

    p = chip_select(p);
    write_exact(buffer, p - buffer);
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
    open_port();

    atexit(close_port);

    // Select SPI readback.
    // Make sure CS, SI are high.
    static const unsigned char init[] = {
        REG_ADDRESS, REG_MAGIC, MAGIC_MAGIC, REG_XMIT, XMIT_FLASH,
        REG_FLASH, FLASH_CS | FLASH_DATA,
        REG_FLASH, FLASH_CS | FLASH_DATA | FLASH_XMIT,
        REG_FLASH, FLASH_CS | FLASH_DATA,
        REG_FLASH, FLASH_CS | FLASH_DATA | FLASH_XMIT };
    write_exact(init, sizeof init);
    flush_ser();

    // Now grab data.  We should get exactly 1 byte, and the overflow bit
    // should be off.
//    sleep (1);
    static const unsigned char pulse[] = {
        REG_FLASH, FLASH_CS | FLASH_DATA };
    write_exact(pulse, sizeof pulse);

    read_exact(buffer, 1);
    if (buffer[0] & FLASH_OVERRUN)
        errx(1, "Still have overrun...\n");
    /* check_idle(); */

    unsigned char * p = chip_select(buffer);

    p = add_be(p, 0x9f, 8, false);
    p = add_be(p, 0, 56, true);

    p = chip_select(p);

    write_exact(buffer, p - buffer);
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
