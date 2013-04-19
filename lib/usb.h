#ifndef USB_H_
#define USB_H_

#include <stddef.h>

#define USB_IN_EP 0x81
#define USB_OUT_EP 2
#define USB_SLOP 262144

struct libusb_device_handle;

extern struct libusb_device_handle * usb_device;

void usb_open(void);

void usb_close(void);

void usb_slurp(void * buffer, size_t len);

void usb_send_bytes(const void * data, size_t len);

void usb_printf(const char * format, ...) __attribute__((format(printf,1,2)));

void usb_write_reg(unsigned reg, unsigned val);
void usb_write_mask(unsigned reg, unsigned val, unsigned mask);

// Set to idle (actually, the cpu ssi stream).
void usb_xmit_idle(void);

// Read until len bytes or two empty reads.  Buffer may be NULL to just flush.
size_t usb_read(void * buffer, size_t len);

// Flush out usb data to stderr.
void usb_echo(void);

// Read until idle.
void usb_flush(void);

#define SLURP_OPTS "c:f:g:p:d:n:i:"

unsigned char * slurp_getopt(
    int argc, char * const argv[], const char * optstring, int (*cb)(int),
    int source, size_t * restrict num_samples, size_t * restrict bytes);

#endif
