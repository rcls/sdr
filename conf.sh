#!/bin/sh

# Frequency, kHz
F="${1:-89400}"

let N='(F << 24) / 250000'

let B0='N % 256'
let B1='N / 256 % 256'
let B2='N / 65536 % 256'

BYTES="$(printf 'ff fe b5 00 %02x 01 %02x 02 %02x' $B0 $B1 $B2)"

echo "$N $BYTES"

# Send using echo...
echo $BYTES|xxd -r -p > /dev/ttyRadio0

# Send using libusb...
#./sample/commands direct raw $BYTES
