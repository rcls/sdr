#include <err.h>
#include <libusb-1.0/libusb.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "lib/registers.h"
#include "lib/usb.h"

unsigned char raw_buffer[4096];

static unsigned char * add_byte(unsigned char * p, unsigned val)
{
    printf("Byte %02x\n", val);
    for (unsigned bit = 128; bit; bit >>= 1) {
        *p++ = REG_CPU_SSI;
        *p++ = (val & bit) ? CPU_SSI_DATA : 0;
        *p++ = REG_CPU_SSI;
        *p++ = (val & bit) ? CPU_SSI_DATA|CPU_SSI_CLK : CPU_SSI_CLK;
    }
    return p;
}


static unsigned char * read_upto(libusb_device_handle * dev,
                                 unsigned char * buffer, size_t len)
{
    // Read until we're full or we get two consecutive empties.
    int empty = 0;
    while (len > 0) {
        unsigned char bounce[512];      // Fucking FTDI.
        int transferred = 0;
        int l = sizeof bounce;
        if (len + 2 < l)
            l = len + 2;
        int r = libusb_bulk_transfer(dev, USB_IN_EP, bounce, l,
                                     &transferred, 10);
        fprintf(stderr, "In %i (%i)\n", transferred, r);
        if (r != 0)
            errx(1, "Read failed: %i", r);

        if (transferred <= 2 && ++empty >= 2)
            break;
        if (transferred <= 2)
            continue;
        empty = 0;
        transferred -= 2;
        memcpy(buffer, bounce + 2, transferred);
        buffer += transferred;
        len -= transferred;
    }
    return buffer;
}

#include <unistd.h>
int main(int argc, char * argv[])
{
    libusb_device_handle * dev = usb_open();

    static unsigned char setup[] = {
        REG_ADDRESS, REG_MAGIC, MAGIC_MAGIC,
        REG_USB, 255,                    // Slow
        REG_XMIT, XMIT_IDLE|XMIT_PUSH,  // Flush out data.
        REG_XMIT, XMIT_IDLE,
        REG_CPU_SSI, CPU_SSI_FSS|CPU_SSI_CLK,
        REG_XMIT, XMIT_CPU_SSI|1|XMIT_LOW_LATENCY,
    };

    usb_send_bytes(dev, setup, sizeof setup);
    usb_flush(dev);

    // Buffer overruns... who cares.
    unsigned char * p = raw_buffer;
    *p++ = REG_ADDRESS;
    *p++ = REG_CPU_SSI;
    *p++ = CPU_SSI_FSS|CPU_SSI_CLK;

    p = add_byte(p, argc + 1);
    unsigned checksum = 0;
    for (int i = 1; i < argc; ++i)
        checksum += strtoul(argv[i], NULL, 16);
    p = add_byte(p, checksum & 255);
    for (int i = 1; i < argc; ++i)
        p = add_byte(p, strtoul(argv[i], NULL, 16));

    *p++ = REG_CPU_SSI;
    *p++ = CPU_SSI_FSS|CPU_SSI_CLK;

    for (int i = 1; i < 10; ++i)
        p = add_byte(p, 0);

    *p++ = REG_CPU_SSI;
    *p++ = CPU_SSI_FSS|CPU_SSI_CLK;

    for (unsigned char * q = raw_buffer; q != p; ++q)
        printf("%02x ", *q);
    printf("\n");

    usb_send_bytes(dev, raw_buffer, p - raw_buffer);
    sleep(1);
    unsigned char * end = read_upto(dev, raw_buffer, sizeof raw_buffer);

    for (unsigned char * p = raw_buffer; p != end; ++p)
        printf("%02x ", *p);
    printf("\n");

    usb_close(dev);
}
