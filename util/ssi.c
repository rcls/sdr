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
    for (unsigned i = 0; i < len; ++i)
        p = add_byte(p, command[i]);
    for (unsigned i = 0; i < zeros; ++i)
        p = add_byte(p, 0);

    usb_send_bytes(dev, raw, p - raw);
    read_exact(dev, raw, 8 * (len + zeros));
    if ((raw[0] & ~1) != 0x40)
        errx(1, "Unsynchronised");
}


static void basic(libusb_device_handle * dev, const char * comm)
{
    unsigned send = strlen(comm);
    unsigned char buffer[send + 1];
    memcpy(buffer, comm, send);
    buffer[send] = 10;
    ++send;
    unsigned recv = 50;
    unsigned last;
    unsigned lastnz;
    do {
        command(dev, buffer, send, recv);
        lastnz = 0;
        for (int i = 0; i < send + recv; ++i) {
            last = decode_byte(raw + i * 8);
            if (last) {
                lastnz = last;
                putchar(last);
            }
        }
        send = 0;
        recv = 31;
    }
    while (lastnz != 0 && (lastnz != 10 || last != 0));
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

    for (int i = 1; i < argc; ++i)
        basic(dev, argv[i]);
}
