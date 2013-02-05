#!/bin/sh

# Frequency, kHz
F="${1:-89400}"

# Gain
V="${2:-01}"

# Control byte
C="${3:-00}"
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

# Control + freq, 32 bit int.
let N='(V << 24) + (F << 24) / 250000'


# Endian reversal
let R='((N & 0xff000000) >> 24) | ((N & 0xff0000) >> 8) | ((N & 0xff00) * 256)
      | ((N & 255) * 16777216)'

# Hex formatting.
H=`printf "%08x" $N`
RH=`printf "%08x" $R`

echo "$N $H $R $RH"

# Send using echo...
#echo "$RH" "00000000" "00000000" "00000000" "$C"|xxd -r -p > /dev/ttyRadio0

# Send using libusb...
./sample/commands raw "$H" 00000000 00000000 00000000 "$C"
