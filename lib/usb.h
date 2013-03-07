#ifndef USB_H_
#define USB_H_

#include <stddef.h>

#define USB_IN_EP 0x81
#define USB_OUT_EP 2
#define USB_SLOP 262144

typedef struct libusb_device_handle libusb_device_handle;

libusb_device_handle * usb_open(void);

void usb_close(libusb_device_handle * dev);

void usb_slurp(libusb_device_handle * dev, void * buffer, size_t len);

void usb_send_bytes(libusb_device_handle * dev, const void * data, size_t len);

// Read until len bytes or two empty reads.  Buffer may be NULL to just flush.
size_t usb_read(libusb_device_handle * dev, void * buffer, size_t len);

// Read until idle.
void usb_flush(libusb_device_handle * dev);

// If dev is NULL auto open/close.
unsigned char * usb_slurp_channel(libusb_device_handle * dev,
                                  size_t length, int source,
                                  int freq, int gain);

void adc_config(libusb_device_handle * dev, int clock, ...);

#endif
