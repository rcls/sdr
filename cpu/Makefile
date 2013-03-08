
.PHONY: all clean

TARGETS=count blink monitor
all: $(TARGETS)

.PHONY: $(TARGETS)
$(TARGETS): %: %.sram.bin %.flash.bin

.SECONDARY:

clean:
	-rm *.elf *.bin *.flasher *.boot *.o *.a *.s .deps/*.d

CC=arm-linux-gnu-gcc
LD=$(CC)
LDFLAGS=-nostdlib -Wl,--build-id=none
OBJCOPY=arm-linux-gnu-objcopy
CFLAGS=-Os -g -flto -fwhole-program -std=gnu11 -ffreestanding \
	-mcpu=cortex-m3 -mthumb -MMD -MP -MF.deps/$@.d \
	-fno-common -fdata-sections -Wall -Werror -fpie
UTILS=../utils

-include .deps/*.d

%.s: %.c
	$(CC) $(CFLAGS) -S -o $@ $<

monitor.o monitor.s: CFLAGS+=-fpic

# Kill this rule.
%: %.c

%.sram.elf: %.o
	$(LINK.c) -T sram.ld $^ $(LOADLIBES) $(LDLIBS) -o $@

%.sramhi.elf: %.o
	$(LINK.c) -T sram.ld $^ $(LOADLIBES) $(LDLIBS) -o $@

%.flash.elf: %.o
	$(LINK.c) -T flash.ld $^ $(LOADLIBES) $(LDLIBS) -o $@

%.bin: %.elf
	$(OBJCOPY) -O binary $< $@
