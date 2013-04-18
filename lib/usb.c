#define _GNU_SOURCE
#include <libusb-1.0/libusb.h>
#include <stdarg.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/mman.h>

#include "lib/usb.h"
#include "lib/util.h"
#include "lib/registers.h"

#define INTF 0
#define NUM_URBS 256
#define XLEN 512

libusb_device_handle * usb_device;
FILE * usb_stream;

static ssize_t cookie_write(void * cookie, const char * buf, size_t size)
{
    // Guard against recursion due to error exits.
    static bool reenter = false;
    if (reenter || usb_device == NULL)
        return 0;

    reenter = true;
    usb_send_bytes(buf, size);
    reenter = false;
    return size;
}


static cookie_io_functions_t cookie_io = { NULL, cookie_write, NULL, NULL };


static void close_stream(void)
{
    if (usb_stream) {
        FILE * s = usb_stream;
        usb_stream = 0;
        fflush(s);
        fclose(s);
    }
}


void usb_open(void)
{
    if (usb_device != NULL)
        return;

    if (libusb_init(NULL) < 0)
        errx(1, "libusb_init failed\n");

    usb_device = libusb_open_device_with_vid_pid(NULL, 0x0403, 0x6010);
    if (usb_device == NULL)
        errx(1, "libusb_open_device failed\n");

    int r = libusb_detach_kernel_driver(usb_device, INTF);
    if (r != 0 && r != LIBUSB_ERROR_NOT_FOUND)
        errx(1, "libusb_detach_kernel_driver failed\n");

    if (libusb_claim_interface(usb_device, INTF) != 0)
        errx(1, "libusb_claim_interface failed\n");
    atexit(usb_close);

    usb_stream = fopencookie(usb_device, "w", cookie_io);

    // Line buffered by default.
    setvbuf(usb_stream, NULL, _IOLBF, 0);
}


void usb_close(void)
{
    close_stream();

    libusb_device_handle * dev = usb_device;
    if (dev == NULL)
        return;

    usb_device = NULL;

    if (libusb_release_interface(dev, INTF) != 0)
        errx(1, "libusb_release_interface failed\n");

    // Ignore errors from this, the kernel module might not be present.
    libusb_attach_kernel_driver(dev, INTF);

    libusb_close(dev);
}

typedef struct buffer_ptr {
    unsigned char * buffer;
    size_t len;
    size_t offset;
    int outstanding;
} buffer_ptr;


static void finish(struct libusb_transfer * u)
{
    if (u->status != LIBUSB_TRANSFER_COMPLETED)
        errx(1, "usb transfer failed\n");

    if (u->actual_length < 2)
        errx(1, "huh? short packet\n");

    buffer_ptr * p = u->user_data;
    int l = u->actual_length - 2;
    if (l > p->len - p->offset)
        l = p->len - p->offset;
    memcpy(p->buffer + p->offset, u->buffer + 2, l);
    p->offset += l;

    if (p->offset >= p->len) {
        libusb_free_transfer(u);
        --p->outstanding;
    }
    else if (libusb_submit_transfer(u) != 0)
        errx(1, "libusb_submit_transfer failed\n");
}


static long intarg(void)
{
    char * dag;
    long r = strtol(optarg, &dag, 0);
    if (*dag)
        errx(1, "Expected number not %s.", optarg);
    return r;
}


void usb_slurp(void * buffer, size_t len)
{
    unsigned char bounce[XLEN];
    buffer_ptr ptr = { buffer, len, 0, 0 };

    for (int i = 0; i != NUM_URBS; ++i) {
        struct libusb_transfer * u = libusb_alloc_transfer(0);
        u->dev_handle = usb_device;
        u->flags = 0;
        u->endpoint = USB_IN_EP;
        u->type = LIBUSB_TRANSFER_TYPE_BULK;
        u->timeout = 0;
        u->length = XLEN;
        u->callback = finish;
        u->user_data = &ptr;
        u->buffer = bounce;
        u->num_iso_packets = 0;
        if (libusb_submit_transfer(u) != 0)
            errx(1, "libusb_submit_transfer failed\n");
        ++ptr.outstanding;
    }

    while (ptr.outstanding > 0)
        if (libusb_handle_events(NULL) != 0)
            errx(1, "libusb_handle_events failed!\n");
}


void usb_send_bytes(const void * data, size_t len)
{
    int transferred;
    int r = libusb_bulk_transfer(usb_device, USB_OUT_EP, (void *) data, len,
                                 &transferred, 100);
    if (r != 0)
        errx(1, "libusb_bulk_transfer failed (%i).", r);
    if (transferred != len)
        errx(1, "libusb_bulk_transfer short (%i v %zi).", transferred, len);
}


size_t usb_read(void * buffer, size_t len)
{
    // Read until we're full or we get two consecutive empties.
    fflush(usb_stream);
    size_t total = 0;
    int empty = 0;
    while (len > 0) {
        unsigned char bounce[512];      // Fucking FTDI.
        int transferred = 0;
        int l = len - total + 2;
        if (l > sizeof bounce)
            l = sizeof bounce;
        int r = libusb_bulk_transfer(usb_device, USB_IN_EP, bounce, l,
                                     &transferred, 10);
        if (r == LIBUSB_ERROR_TIMEOUT)
            return total;

        if (r != 0 && r != LIBUSB_ERROR_OVERFLOW)
            errx(1, "libusb_bulk_transfer IN failed: %i", r);

        if (transferred <= 2 && ++empty >= 2)
            break;
        if (transferred <= 2)
            continue;
        empty = 0;
        transferred -= 2;
        if (buffer != NULL)
            memcpy(buffer + total, bounce + 2, transferred);
        total += transferred;
    }
    return total;
}


void usb_flush(void)
{
    fflush(usb_stream);
    // FTDI makes this hard.  Wait for 2 empty transfers.
    if (usb_read(NULL, 8192) == 8192)
        errx(1, "Failed to drain usb.");
}


void usb_echo(void)
{
    fflush(usb_stream);
    unsigned char data[8192];
    size_t l = usb_read(data, 8192);
    fwrite(data, l, 1, stderr);
}


void usb_printf(const char * format, ...)
{
    va_list args;
    va_start(args, format);
    vfprintf(usb_stream, format, args);
    va_end(args);
}


void usb_write_reg(unsigned reg, unsigned val)
{
    // This will normally be the first command we send, so include an escape
    // character to ignore any preceding data.
    fprintf(usb_stream, "\033wr %x %x\n", reg, val & 255);
}


void usb_xmit_idle(void)
{
    usb_write_reg(REG_XMIT, XMIT_CPU_SSI|XMIT_PUSH);
    usb_write_reg(REG_XMIT, XMIT_CPU_SSI|XMIT_LOW_LATENCY);
}


unsigned char * slurp_getopt(
    int argc, char * const argv[], const char * optstring, int (*cb) (int),
    int source, size_t * restrict num_samples, size_t * restrict bytes)
{
    long channel = source & 3;
    const char * frequency = NULL;
    long gain = -1;
    long rate = -1;
    long decay = -1;
    source &= ~3;

    static int sample_sizes[8] = { 3, 2, 4, 3, 4, 2, 1, 1 };

    int c;
    do {
        c = getopt(argc, argv, optstring);
        if (cb != NULL)
            c = cb(c);
        switch (c) {
        case 'c':
            channel = intarg();
            if (channel < 0 || channel > 3)
                errx(1, "Channel must be 0 to 3 inclusive.");
            break;
        case 'f':
            frequency = optarg;
            break;
        case 'g':
            gain = intarg();
            break;
        case 'r':
            rate = intarg();
            break;
        case 'd':
            decay = intarg();
            break;
        case 'n':
            *num_samples = intarg();
            break;
        case 's':
            source = intarg();
            break;
        case 0:
        case -1:
            break;
        case '?':
            exit(1);
        default:
            abort();
        }
    }
    while (c != -1);

    usb_open();

    // Turn off data.
    usb_xmit_idle();

    if (rate >= 0)
        usb_write_reg(REG_SAMPLE_RATE, rate);

    if (gain >= 0)
        usb_printf("gain %li %li\n", channel, gain);

    if (decay >= 0 && (source & 0x1c) == XMIT_SAMPLE) {
        usb_write_reg(REG_SAMPLE_DECAY_LO, decay);
        usb_write_reg(REG_SAMPLE_DECAY_HI, decay >> 8);
    }
    else if (decay >= 0)
        usb_write_reg(REG_PLL_DECAY, decay);

    if (frequency != NULL)
        usb_printf("tune %li %s\n", channel, frequency);

    usb_echo();

    if (*num_samples < 25)
        *num_samples = 1 << *num_samples;

    *bytes = *num_samples * sample_sizes[(source >> 2) & 7];
    if (*bytes < 65536)
        *bytes *= 2;
    else
        *bytes += 65536;

    unsigned char * buffer = xmalloc(*bytes);
    mlock(buffer, *bytes);
    memset(buffer, 0xff, *bytes);

    usb_write_reg(REG_XMIT, source + channel);
    fflush(usb_stream);
    usb_slurp(buffer, *bytes);

    // Turn off data and flush out any remainders.
    usb_xmit_idle();
    usb_flush();
    usb_printf("\n");
    fflush(usb_stream);
    usb_read(NULL, 1);

    return buffer;
}
