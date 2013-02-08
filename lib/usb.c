#include <libusb-1.0/libusb.h>
#include <string.h>

#include "lib/usb.h"
#include "lib/util.h"

#define INTF 0
#define NUM_URBS 256
#define XLEN 512

libusb_device_handle * usb_open(void)
{
    if (libusb_init(NULL) < 0)
        errx(1, "libusb_init failed\n");

    libusb_device_handle * dev = libusb_open_device_with_vid_pid(
        NULL, 0x0403, 0x6010);
    if (dev == NULL)
        errx(1, "libusb_open_device failed\n");

    int r = libusb_detach_kernel_driver(dev, INTF);
    if (r != 0 && r != LIBUSB_ERROR_NOT_FOUND)
        errx(1, "libusb_detach_kernel_driver failed\n");

    if (libusb_claim_interface(dev, INTF) != 0)
        errx(1, "libusb_claim_interface failed\n");

    return dev;
}

void usb_close(libusb_device_handle * dev)
{
    if (libusb_release_interface(dev, INTF) != 0)
        errx(1, "libusb_release_interface failed\n");

    int r = libusb_attach_kernel_driver(dev, INTF);
    if (r != 0)
        errx(1, "libusb_attach_kernel_driver failed %d!\n", r);

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


void usb_slurp(libusb_device_handle * dev, void * buffer, size_t len)
{
    unsigned char bounce[XLEN];
    buffer_ptr ptr = { buffer, len, 0, 0 };

    for (int i = 0; i != NUM_URBS; ++i) {
        struct libusb_transfer * u = libusb_alloc_transfer(0);
        u->dev_handle = dev;
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


void usb_send_bytes(libusb_device_handle * dev, const void * data, size_t len)
{
    int transferred;
    if (libusb_bulk_transfer(dev, USB_OUT_EP, (void *) data, len,
                             &transferred, 100) != 0
        || transferred != len)
        errx(1, "libusb_bulk_transfer failed.\n");
}
