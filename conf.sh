#!/bin/sh

# Frequency, kHz
F="${1:-89400}"

# Gain
#V="${2:-01}"

# Control byte
#C="${3:-00}"
# bits 0..3 are ADC
# bit 0 = sen = 1
# bit 1 = sdata/standby = 0
# bit 2 = sclk = 0
# bit 3 = reset = 1
# bit 4 = 1 for usb on.
# bit 5 = 1 for ir data.
# bit 6 = led off = 1
# bit 7 = led off = 1

# 89.3 : National - Wellington
# 92.5 (Concert - Wellington)

# 92.6, Concert Akl
# 101.4, National Akl
# 89.4 - some Akl station

let N='(F << 24) / 250000'

let B0='N % 256'
let B1='N / 256 % 256'
let B2='N / 65536 % 256'

BYTES="$(printf 'ff 1e b5 00 %02x 01 %02x 02 %02x' $B0 $B1 $B2)"

echo "$N $BYTES"

# Send using echo...
echo $BYTES|xxd -r -p > /dev/ttyRadio0

# Send using libusb...
#./sample/commands direct raw $BYTES
