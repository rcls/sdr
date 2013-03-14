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

static void basic(const char * comm)
{
    usb_printf("%s\n", comm);
    unsigned got;
    unsigned lastnz;
    do {
        lastnz = 0;
        got = usb_read(raw, sizeof raw);
        for (unsigned i = 0; i != got; ++i)
            if (raw[i]) {
                lastnz = raw[i];
                putchar(raw[i]);
            }
    }
    while (got != 0 && lastnz != 10);
}


int main(int argc, char * argv[])
{
    usb_open();
    usb_flush();

    for (int i = 1; i < argc; ++i)
        basic(argv[i]);

    return 0;
}
