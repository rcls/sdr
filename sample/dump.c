#include <getopt.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/mman.h>
#include <fcntl.h>
#include <unistd.h>

#include "lib/usb.h"
#include "lib/util.h"

static const char * outpath;

static void parse_opts(int argc, char * argv[])
{
    while (1) {
        switch (getopt(argc, argv, "o:")) {
        case 'o':
            if (outpath)
                errx(1, "Multiple -o options.\n");
            outpath = optarg;
        case -1:
            return;
        default:
            errx(1, "Bad option.\n");
        }
    }
}


int main(int argc, char * argv[])
{
    parse_opts(argc, argv);

    size_t bufsize = 1;
    for (int i = optind; i < argc; ++i)
        bufsize *= strtoul(argv[i], NULL, 0);
    if (optind >= argc)
        bufsize = 1 << 24;

    bufsize += USB_SLOP;
    unsigned char * buffer = xmalloc(bufsize);

    mlockall(MCL_CURRENT | MCL_FUTURE);
    memset(buffer, 0xff, bufsize);

    libusb_device_handle * dev = usb_open();
    usb_slurp(dev, buffer, bufsize);
    usb_close(dev);

    int outfile = 1;
    if (outpath)
        outfile = checki(open(outpath, O_WRONLY|O_CREAT|O_TRUNC, 0666),
                         "opening output");

    dump_file(outfile, buffer, bufsize);

    if (outpath)
        checki(close(outfile), "closing output");

    exit(EXIT_SUCCESS);
}
