#include <libusb-1.0/libusb.h>
#include <stdarg.h>
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


static void usb_flush1(libusb_device_handle * dev)
{
    for (int i = 0; i != 256; ++i) {
        int transferred;
        unsigned char buffer[512];
        int r = libusb_bulk_transfer(dev, USB_IN_EP, buffer, sizeof buffer,
                                     &transferred, 100);
        if (r == LIBUSB_ERROR_TIMEOUT || (r == 0 && transferred <= 2))
            return;
        if (r != 0)
            errx(1, "libusb_bulk_transfer failed.\n");
    }
    errx(1, "failed to empty pipeline");
}


void usb_flush(libusb_device_handle * dev)
{
    // FTDI makes this hard.  Manually pulse siwa, then get two empty transfers.
    static const unsigned char push[] = {
        0xff, REG_XMIT, XMIT_PUSH|XMIT_FLASH, REG_XMIT, XMIT_FLASH };
    usb_send_bytes(dev, push, sizeof push);
    usb_flush1(dev);
    usb_flush1(dev);
}


unsigned char * usb_slurp_channel(libusb_device_handle * devo,
                                  size_t length, int source,
                                  int freq, int gain)
{
    libusb_device_handle * dev = devo;
    if (dev == NULL)
        dev = usb_open();

    // First turn off output & select channel...
    int channel = source & 3;
    freq = freq * 16777216ull / 250000;
    unsigned char conf[20];
    unsigned char * p = conf;
    *p++ = REG_ADDRESS;
    *p++ = REG_MAGIC;
    *p++ = MAGIC_MAGIC;
    *p++ = REG_XMIT;
    *p++ = XMIT_IDLE;

    bool radio = (source & 0x1c) == XMIT_PHASE || (source & 0x1c) == XMIT_IR;
    if (radio && freq >= 0) {
        *p++ = REG_RADIO_FREQ(channel) + 0;
        *p++ = freq;
        *p++ = REG_RADIO_FREQ(channel) + 1;
        *p++ = freq >> 8;
        *p++ = REG_RADIO_FREQ(channel) + 2;
        *p++ = freq >> 16;
    }
    if (radio && gain >= 0) {
        *p++ = REG_RADIO_GAIN(channel);
        *p++ = 0x80 | gain;
    }
    bool sample = (source & 0x1c) == XMIT_SAMPLE;
    if (sample && freq >= 0) {
        *p++ = REG_SAMPLE_RATE;
        *p++ = freq;
    }
    if (sample && gain >= 0) {
        *p++ = REG_SAMPLE_DECAY_LO;
        *p++ = gain;
        *p++ = REG_SAMPLE_DECAY_HI;
        *p++ = gain >> 8;
    }

    usb_send_bytes(dev, conf, p - conf);

    // Flush usb...
    usb_flush(dev);
    // Turn on the data channel.
    unsigned char on[] = { REG_ADDRESS, REG_XMIT, source };
    usb_send_bytes(dev, on, sizeof on);

    // Slurp a truckload of data.
    unsigned char * buffer = xmalloc(length);
    memset(buffer, 0xff, length);       // Try to get us in RAM.
    usb_slurp(dev, buffer, length);

    // Turn off data.
    usb_send_bytes(dev, conf, 5);
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
    unsigned char buffer[512];
    int len = 0;
    buffer[len++] = REG_ADDRESS;
    buffer[len++] = REG_ADC;
    buffer[len++] = clock | ADC_SEN | ADC_SCLK;
    buffer[len++] = REG_ADC;
    buffer[len++] = clock | ADC_SEN;
    while (1) {
        int w = va_arg(args, int);
        if (w < 0)
            break;
        if (len > sizeof(buffer) - 100)
            errx(1, "adc_config: too many args.\n");
        for (int i = 0; i < 16; ++i) {
            int b = (w << i) & 32768 ? ADC_SDATA : 0;
            buffer[len++] = REG_ADC;
            buffer[len++] = clock | b | ADC_SCLK;
            buffer[len++] = REG_ADC;
            buffer[len++] = clock | b;
        }
        buffer[len++] = REG_ADC;
        buffer[len++] = clock | ADC_SEN | ADC_SCLK;
        buffer[len++] = REG_ADC;
        buffer[len++] = clock | ADC_SEN;
    }
    va_end(args);
    usb_send_bytes(dev, buffer, len);
}
