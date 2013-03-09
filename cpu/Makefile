
.PHONY: all clean

TARGETS=count blink monitor
all: $(TARGETS)

.PHONY: $(TARGETS)
$(TARGETS): %: %.sram.bin %.flash.bin relmon.flash0.bin relmon.sram.bin

.SECONDARY:

clean:
	-rm *.elf *.bin *.flasher *.boot *.o *.a *.s .deps/*.d

CC=arm-linux-gnu-gcc
LD=$(CC)
LDFLAGS=-nostdlib -Wl,--build-id=none
OBJCOPY=arm-linux-gnu-objcopy
CFLAGS=-Os -g -flto -fwhole-program -std=gnu11 -ffreestanding \
	-mcpu=cortex-m3 -mthumb -MMD -MP -MF.deps/$@.d \
	-fno-common -fdata-sections -Wall -Werror
UTILS=../utils

-include .deps/*.d

%.s: %.c
	$(CC) $(subst -flto,,$(subst -g,,$(CFLAGS))) -S -o $@ $<

relmon.o relmon.s: CFLAGS+=-fpie

# Kill this rule.
%: %.c

%.sram.elf: %.o
	$(LINK.c) -T sram.ld $^ $(LOADLIBES) $(LDLIBS) -o $@

%.flash.elf: %.o
	$(LINK.c) -T flash.ld $^ $(LOADLIBES) $(LDLIBS) -o $@

%.flash0.elf: %.o
	$(LINK.c) -T flash0.ld $^ $(LOADLIBES) $(LDLIBS) -o $@

%.bin: %.elf
	$(OBJCOPY) -O binary $< $@
