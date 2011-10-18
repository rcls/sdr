#include <getopt.h>
#include <libusb-1.0/libusb.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/mman.h>
#include <fcntl.h>
#include <unistd.h>

#include "lib/util.h"

#define INTF 0
#define EP 0x81
#define NUM_URBS 256
#define XLEN 512

#define SLOP (NUM_URBS * XLEN * 2)

static unsigned char * buffer;
static unsigned char * bufend;
static unsigned char * bufptr;
static int outstanding = 0;

static const char * outpath;

static void finish(struct libusb_transfer * u)
{
    if (u->status != LIBUSB_TRANSFER_COMPLETED)
        exprintf("usb transfer failed\n");

    if (u->actual_length < 2)
        exprintf("huh? short packet\n");

    int l = u->actual_length - 2;
    if (l > bufend - bufptr)
        l = bufend - bufptr;
    memcpy(bufptr, u->buffer + 2, l);
    bufptr += l;

    if (bufptr == bufend) {
        libusb_free_transfer(u);
        --outstanding;
    }
    else if (libusb_submit_transfer(u) != 0)
        exprintf("libusb_submit_transfer failed\n");
}


static void parse_opts(int argc, char * argv[])
{
    while (1) {
        switch (getopt(argc, argv, "o:")) {
        case 'o':
            if (outpath)
                exprintf("Multiple -o options.\n");
            outpath = optarg;
        case -1:
            return;
        default:
            exprintf("Bad option.\n");
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

    bufsize += SLOP;
    buffer = xmalloc(bufsize);
    bufptr = buffer;
    bufend = buffer + bufsize;

    mlockall(MCL_CURRENT | MCL_FUTURE);
    memset(buffer, 0xff, bufsize);

    if (libusb_init(NULL) < 0)
        exprintf("libusb_init failed\n");

    libusb_device_handle * dev = libusb_open_device_with_vid_pid(
        NULL, 0x0403, 0x6010);
    if (dev == NULL)
        exprintf("libusb_open_device failed\n");

    int r = libusb_detach_kernel_driver(dev, INTF);
    if (r != 0 && r != LIBUSB_ERROR_NOT_FOUND)
        exprintf("libusb_detach_kernel_driver failed\n");

    if (libusb_claim_interface(dev, INTF) != 0)
        exprintf("libusb_claim_interface failed\n");

    //static libusb_transfer urbs[NUM_URBS];
    static unsigned char bounce[NUM_URBS][XLEN];
    for (int i = 0; i != NUM_URBS; ++i) {
        struct libusb_transfer * u = libusb_alloc_transfer(0);
        u->dev_handle = dev;
        u->flags = 0;
        u->endpoint = EP;
        u->type = LIBUSB_TRANSFER_TYPE_BULK;
        u->timeout = 0;
        u->length = XLEN;
        u->callback = finish;
        u->buffer = bounce[i];
        u->num_iso_packets = 0;
        if (libusb_submit_transfer(u) != 0)
            exprintf("libusb_submit_transfer failed\n");
        ++outstanding;
    }

    while (outstanding > 0)
        if (libusb_handle_events(NULL) != 0)
            exprintf("libusb_handle_events failed!\n");

    int outfile = 1;
    if (outpath)
        outfile = checki(open(outpath, O_WRONLY|O_CREAT|O_TRUNC, 0666),
                         "opening output");

    for (const unsigned char * p = buffer; p != bufend;)
        p += checkz(write(outfile, p, bufend - p), "writing output");

    if (outpath)
        checki(close(outfile), "closing output");

    if (libusb_release_interface(dev, INTF) != 0)
        exprintf("libusb_release_interface failed\n");

    r = libusb_attach_kernel_driver(dev, INTF);
    if (r != 0)
        exprintf("libusb_attach_kernel_driver failed %d!\n", r);

    exit(EXIT_SUCCESS);
}
