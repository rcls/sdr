#include <libusb-1.0/libusb.h>
#include <stdarg.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/mman.h>
#include <unistd.h>

#define INTF 0
#define EP 0x81
#define NUM_URBS 128
#define XLEN 512

#define SLOP (NUM_URBS * XLEN * 2)
#define BUFSIZE (16777216 + SLOP)
/* #define SLOP 0 */
/* #define BUFSIZE 1024 */

static unsigned char buffer[BUFSIZE];
#define BUFEND (buffer + sizeof(buffer))
static unsigned char * bufptr = buffer;
int outstanding = 0;

typedef struct libusb_transfer libusb_transfer;

static void exprintf(const char * f, ...) __attribute__(
    (__noreturn__, __format__(__printf__, 1, 2)));
static void exprintf(const char * f, ...)
{
    va_list args;
    va_start(args, f);
    vfprintf(stderr, f, args);
    va_end(args);
    exit(EXIT_FAILURE);
}

static void experror(const char * m) __attribute__((__noreturn__));
static void experror(const char * m)
{
    perror(m);
    exit(EXIT_FAILURE);
}

static void finish(libusb_transfer * u)
{
    if (u->status != LIBUSB_TRANSFER_COMPLETED)
        exprintf("usb transfer failed\n");

    if (u->actual_length < 2)
        exprintf("huh? short packet\n");

    int l = u->actual_length - 2;
    if (l > BUFEND - bufptr)
        l = BUFEND - bufptr;
    memcpy(bufptr, u->buffer + 2, l);
    bufptr += l;

    if (bufptr == BUFEND)
        --outstanding;
    else if (libusb_submit_transfer(u) != 0)
        exprintf("libusb_submit_transfer failed\n");
}

int main()
{
    if (libusb_init(NULL) < 0)
        exprintf("libusb_init failed\n");

    libusb_device_handle * dev = libusb_open_device_with_vid_pid(
        NULL, 0x0403, 0x6010);
    if (dev == NULL)
        exprintf("libusb_open_device failed\n");

    int r = libusb_detach_kernel_driver(dev, INTF);
    if (r != 0 && r != LIBUSB_ERROR_NOT_FOUND)
        exprintf("libusb_detach_kernel_driver failed\n");

    //static libusb_transfer urbs[NUM_URBS];
    static unsigned char bounce[NUM_URBS][XLEN];
    for (int i = 0; i != NUM_URBS; ++i) {
        libusb_transfer * u = libusb_alloc_transfer(0);
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

    mlockall(MCL_CURRENT | MCL_FUTURE);
    memset(buffer, 0xff, BUFSIZE);

    while (outstanding > 0)
        if (libusb_handle_events(NULL) != 0)
            exprintf("libusb_handle_events failed!\n");

    for (const unsigned char * p = buffer + SLOP; p != BUFEND;) {
        ssize_t r = write(1, p, BUFEND - p);
        if (r < 0)
            experror("write");
        p += r;
    }

    libusb_attach_kernel_driver(dev, INTF);

    exit(EXIT_SUCCESS);
}
