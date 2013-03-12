#include <err.h>
#include <libusb-1.0/libusb.h>
#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "lib/usb.h"
#include "lib/util.h"

// Buffer overruns?  What buffer overruns.  :-)
unsigned char raw[4096];

static unsigned char * add_byte(unsigned char * p, unsigned val)
{
    //printf("Byte %02x\n", val);
    *p++ = val;
    return p;
}


static void command(libusb_device_handle * dev, const char * command,
                    unsigned len)
{
    unsigned char * p = raw;
    for (unsigned i = 0; i < len; ++i)
        p = add_byte(p, command[i]);

    p = add_byte(p, '\n');
    usb_send_bytes(dev, raw, p - raw);
}


static void basic(libusb_device_handle * dev, const char * comm)
{
    unsigned send = strlen(comm);
    command(dev, comm, send);
    unsigned got;
    unsigned lastnz;
    do {
        lastnz = 0;
        got = usb_read(dev, raw, sizeof raw);
        for (unsigned i = 0; i != got; ++i)
            if (raw[i]) {
                lastnz = raw[i];
                putchar(raw[i]);
            }
    }
    while (got != 0 && lastnz != 10);
}


static void finish(int st, void * d)
{
    libusb_device_handle * dev = d;
    usb_close(dev);
}


int main(int argc, char * argv[])
{
    libusb_device_handle * dev = usb_open();
    on_exit(finish, dev);

    /* static unsigned char setup[] = { */
    /*     REG_ADDRESS, REG_MAGIC, MAGIC_MAGIC, */
    /*     REG_USB, 255,                   // Slow */
    /*     REG_XMIT, XMIT_IDLE|XMIT_PUSH,  // Flush out data. */
    /*     REG_XMIT, XMIT_IDLE, */
    /*     REG_XMIT, XMIT_CPU_SSI|XMIT_LOW_LATENCY, */
    /* }; */

    /* usb_send_bytes(dev, setup, sizeof setup); */
    usb_flush(dev);

    for (int i = 1; i < argc; ++i)
        basic(dev, argv[i]);
}
