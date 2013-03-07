#include <err.h>
#include <libusb-1.0/libusb.h>
#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "lib/registers.h"
#include "lib/usb.h"
#include "lib/util.h"

// Buffer overruns?  What buffer overruns.  :-)
unsigned char raw[4096];

static unsigned char * add_byte(unsigned char * p, unsigned val)
{
    //printf("Byte %02x\n", val);
    for (unsigned bit = 128; bit; bit >>= 1) {
        *p++ = REG_CPU_SSI;
        *p++ = (val & bit) ? CPU_SSI_DATA : 0;
        *p++ = REG_CPU_SSI;
        *p++ = (val & bit) ? CPU_SSI_DATA|CPU_SSI_CLK : CPU_SSI_CLK;
    }
    return p;
}


static unsigned decode_byte(unsigned char * p)
{
    unsigned b = 0;
    for (int i = 0; i != 8; ++i)
        b = b * 2 + (p[i] & 1);
    return b;
}


static void read_exact(libusb_device_handle * dev, void * p, size_t len)
{
    if (len != usb_read(dev, p, len))
        errx(1, "Short read\n");
}


static void command(libusb_device_handle * dev, const unsigned char * command,
                    unsigned len, unsigned zeros)
{
    unsigned char * p = raw;
    *p++ = REG_ADDRESS;
    *p++ = REG_CPU_SSI;
    *p++ = CPU_SSI_FSS|CPU_SSI_CLK;
    p = add_byte(p, len + 2);
    unsigned checksum = 0;
    for (unsigned i = 0; i < len; ++i)
        checksum += command[i];
    p = add_byte(p, checksum);
    for (unsigned i = 0; i < len; ++i)
        p = add_byte(p, command[i]);
    for (unsigned i = 0; i < zeros; ++i)
        p = add_byte(p, 0);

    usb_send_bytes(dev, raw, p - raw);
    read_exact(dev, raw, 8 * (2 + len + zeros));
    if ((raw[0] & ~1) != 0x40)
        errx(1, "Unsynchronised");
}


static void command_with_ack(libusb_device_handle * dev,
                             const unsigned char * comm,
                             unsigned len, unsigned max_poll)
{
    unsigned zeros = 20;
    command(dev, comm, len, zeros);
    len += 2;

    unsigned i = 0;
    while (1) {
        for (unsigned i = len; i != len + zeros; ++i) {
            unsigned b = decode_byte(raw + 8 * i);
            if (b == 0xcc)
                return;                 // Good.

            if (b != 0)
                errx(1, "Expected ACK got %02x", b);
        }

        if (i++ >= max_poll)
            errx(1, "No response");

        len = 0;
        zeros = 1;
        unsigned char * p = add_byte(raw, 0);
        usb_send_bytes(dev, raw, p - raw);
        read_exact(dev, raw, 8);
    }
}


static void check_status(libusb_device_handle * dev)
{
    static const unsigned char x23 = 0x23;
    command(dev, &x23, 1, 50);

    int got = 0;
    for (int i = 0; i != 50; ++i) {
        unsigned b = decode_byte (raw + 24 + i * 8);
        if (got != 0 || b != 0)
            raw[got++] = b;
    }
    if (got < 4)
        errx(1, "Got %i bytes needed 4\n", got);

    if (raw[0] != 0xcc || raw[1] != 0x03 || raw[2] != 0x40 || raw[3] != 0x40)
        errx(1, "Expected cc 03 40 40, got %02x %02x %02x %02x",
             raw[0], raw[1], raw[2], raw[3]);

    unsigned char * p = raw;
    p = add_byte(p, 0xcc);
    usb_send_bytes(dev, raw, p - raw);
    read_exact(dev, raw, 8);
}


static void basic(libusb_device_handle * dev, int argc, char * argv[])
{
    unsigned char bytes[argc];

    for (int i = 1; i < argc; ++i) {
        char * remain;
        bytes[i] = strtoul(argv[i], &remain, 16);
        if (*remain)
            errx(1, "Not valid hex: %s\n", argv[i]);
    }

    command(dev, bytes + 1, argc - 1, 50);
    bool started;
    for (int i = 0; i < 50 + argc - 1; ++i) {
        unsigned b = decode_byte(raw + i * 8);
        if (b)
            started = true;
        if (started)
            printf("%02x ", b);
    }
    printf("\n");
}


static void finish(int st, void * d)
{
    libusb_device_handle * dev = d;
    unsigned char * p = raw;
    *p++ = REG_ADDRESS;
    *p++ = REG_XMIT;
    *p++ = XMIT_IDLE;
    *p++ = REG_CPU_SSI;
    *p++ = CPU_SSI_FSS|CPU_SSI_CLK;
    usb_send_bytes(dev, raw, p - raw);
    usb_close(dev);
}


static void download(libusb_device_handle * dev,
                     int argc, char * argv[])
{
    unsigned start = strtoul(argv[2], NULL, 16);
    unsigned len = strtoul(argv[3], NULL, 0);
    unsigned char command[9];
    command[0] = 0x21;
    command[1] = start >> 24;
    command[2] = start >> 16;
    command[3] = start >> 8;
    command[4] = start;
    command[5] = len >> 24;
    command[6] = len >> 16;
    command[7] = len >> 8;
    command[8] = len;
    command_with_ack(dev, command, 9, 10000);
    check_status(dev);
}


static void data(libusb_device_handle * dev,
                 int argc, char * argv[])
{
    size_t offset = 0;
    size_t length = 0;
    unsigned char * buffer = NULL;
    slurp_path(argv[2], &buffer, &offset, &length);
    size_t wanted = strtoul(argv[3], NULL, 0);
    if (offset < wanted)
        errx(1, "Wanted %zu bytes, got %zu", wanted, offset);
    for (size_t i = 0; i < wanted;) {
        unsigned len = 8;
        if (wanted - i < 8)
            len = wanted - i;
        unsigned char command[9];
        command[0] = 0x24;
        memcpy(command + 1, buffer + i, len);
        command_with_ack(dev, command, 9, 10000);
        i += len;
    }
}


static void run(libusb_device_handle * dev,
                int argc, char * argv[])
{
    unsigned address = strtoul(argv[2], NULL, 16);
    unsigned char command[5];
    command[0] = 0x22;
    command[1] = address >> 24;
    command[2] = address >> 16;
    command[3] = address >> 8;
    command[4] = address;
    command_with_ack(dev, command, 5, 5);
}


int main(int argc, char * argv[])
{
    libusb_device_handle * dev = usb_open();
    on_exit(finish, dev);

    static unsigned char setup[] = {
        REG_ADDRESS, REG_MAGIC, MAGIC_MAGIC,
        REG_USB, 255,                   // Slow
        REG_CPU_SSI, CPU_SSI_FSS|CPU_SSI_CLK,
        REG_XMIT, XMIT_IDLE|XMIT_PUSH,  // Flush out data.
        REG_XMIT, XMIT_IDLE,
        REG_XMIT, XMIT_CPU_SSI|1|XMIT_LOW_LATENCY,
    };

    usb_send_bytes(dev, setup, sizeof setup);
    usb_flush(dev);

    if (argc <= 1 || (argc == 2 && strcmp(argv[1], "ping") == 0)) {
        static const unsigned char x20 = 0x20;
        command_with_ack(dev, &x20, 1, 5);
    }
    else if (argc == 2 && strcmp(argv[1], "status") == 0)
        check_status(dev);
    else if (argc == 4 && strcmp(argv[1], "download") == 0)
        download(dev, argc, argv);
    else if (argc == 4 && strcmp(argv[1], "data") == 0)
        data(dev, argc, argv);
    else if (argc == 3 && strcmp(argv[1], "run") == 0)
        run(dev, argc, argv);
    else
        basic(dev, argc, argv);
}
