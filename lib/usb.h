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

void usb_flush(libusb_device_handle * dev);

#endif
