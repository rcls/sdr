#include <libusb-1.0/libusb.h>
#include <stdarg.h>
#include <stdio.h>
#include <string.h>

#include "lib/usb.h"
#include "lib/util.h"
#include "lib/registers.h"

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

    usb_printf(dev, "nop\n");

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


size_t usb_read(libusb_device_handle * dev, void * buffer, size_t len)
{
    // Read until we're full or we get two consecutive empties.
    size_t total = 0;
    int empty = 0;
    while (len > 0) {
        unsigned char bounce[512];      // Fucking FTDI.
        int transferred = 0;
        int l = len - total + 2;
        if (l > sizeof bounce)
            l = sizeof bounce;
        int r = libusb_bulk_transfer(dev, USB_IN_EP, bounce, l,
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


void usb_flush(libusb_device_handle * dev)
{
    // FTDI makes this hard.  Wait for 2 empty transfers.
    if (usb_read(dev, NULL, 8192) == 8192)
        errx(1, "Failed to drain usb.");
}


void usb_echo(libusb_device_handle * dev)
{
    unsigned char data[8192];
    size_t l = usb_read(dev, data, 8192);
    fwrite(data, l, 1, stderr);
}


void usb_printf(libusb_device_handle * dev, const char * format, ...)
{
    va_list args;
    va_start(args, format);
    va_list argl;
    va_copy(argl, args);
    int l = vsnprintf(NULL, 0, format, argl);
    va_end(argl);
    char buf[l + 1];
    vsnprintf(buf, l + 1, format, args);
    va_end(args);
    usb_send_bytes(dev, buf, l);
}


void usb_write_reg(libusb_device_handle * dev, unsigned reg, unsigned val)
{
    usb_printf(dev, "wr %x %x\n", reg, val);
}


void usb_xmit_idle(libusb_device_handle * dev)
{
    usb_write_reg(dev, REG_XMIT, XMIT_CPU_SSI|XMIT_PUSH);
    usb_write_reg(dev, REG_XMIT, XMIT_CPU_SSI|XMIT_LOW_LATENCY);
}


unsigned char * usb_slurp_channel(libusb_device_handle * devo,
                                  size_t length, int source,
                                  int freq, int gain)
{
    libusb_device_handle * dev = devo;
    if (dev == NULL)
        dev = usb_open();

    usb_xmit_idle(dev);

    // First turn off output & select channel...
    int channel = source & 3;

    bool radio = (source & 0x1c) == XMIT_PHASE || (source & 0x1c) == XMIT_IR;
    if (radio && freq >= 0)
        usb_printf(dev, "tune %i %i\n", channel, freq);

    if (radio && gain >= 0)
        usb_printf(dev, "gain %i %i\n", channel, gain);

    bool sample = (source & 0x1c) == XMIT_SAMPLE;
    if (sample && freq >= 0)
        usb_write_reg(dev, REG_SAMPLE_RATE, freq);

    if (sample && gain >= 0) {
        usb_write_reg(dev, REG_SAMPLE_DECAY_LO, gain & 255);
        usb_write_reg(dev, REG_SAMPLE_DECAY_HI, gain >> 8);
    }

    // Flush usb...
    usb_flush(dev);
    // Turn on the data channel.
    usb_write_reg(dev, REG_XMIT, source);

    // Slurp a truckload of data.
    unsigned char * buffer = xmalloc(length);
    memset(buffer, 0xff, length);       // Try to get us in RAM.
    usb_slurp(dev, buffer, length);

    // Turn off data.
    usb_xmit_idle(dev);

    // Flush usb...
    usb_flush(dev);

    if (devo == NULL)
        usb_close(dev);

    return buffer;
}


void adc_config(libusb_device_handle * dev, int clock, ...)
{
    clock = clock ? ADC_CLOCK_SELECT : 0;
    va_list args;
    va_start(args, clock);

    usb_write_reg(dev, REG_ADC, clock | ADC_SEN | ADC_SCLK);
    usb_write_reg(dev, REG_ADC, clock | ADC_SEN);
    while (1) {
        int w = va_arg(args, int);
        if (w < 0)
            break;
        /* if (len > sizeof(buffer) - 100) */
        /*     errx(1, "adc_config: too many args.\n"); */
        for (int i = 0; i < 16; ++i) {
            int b = (w << i) & 32768 ? ADC_SDATA : 0;
            usb_write_reg(dev, REG_ADC, clock | b | ADC_SCLK);
            usb_write_reg(dev, REG_ADC, clock | b);
        }
        usb_write_reg(dev, REG_ADC, clock | ADC_SEN | ADC_SCLK);
        usb_write_reg(dev, REG_ADC, clock | ADC_SEN);
        usb_echo(dev);
    }
    va_end(args);
}
