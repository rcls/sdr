
.PHONY: all clean

TARGETS=blink rad
all: $(TARGETS)	monitor.flashreloc.bin monitor.sramreloc.bin \
	bootsel.sram.bin bootsel.flash0.bin extra.sram.bin

.PHONY: $(TARGETS)
$(TARGETS): %: %.sram.bin %.flash.bin

.SECONDARY:

clean:
	-rm *.elf *.bin *.flasher *.boot *.o *.a *.s .deps/*.d

CC=arm-linux-gnu-gcc
LD=$(CC)
LDFLAGS=-nostdlib -Wl,--build-id=none -fuse-linker-plugin
OBJCOPY=arm-linux-gnu-objcopy
CFLAGS=-Os -g -flto -std=gnu11 -ffreestanding \
	-mcpu=cortex-m3 -mthumb -MMD -MP -MF.deps/$@.d \
	-fno-common -fdata-sections -Wall -Werror

rad.flash.elf rad.sram.elf extra.sram.elf: printf.o command.o

-include .deps/*.d

%.s: %.c
	$(CC) $(subst -flto,,$(subst -g,,$(CFLAGS))) -fstack-usage -S -o $@ $<

# Kill this rule.
%: %.c

%.sram.elf: %.o
	$(LINK.c) -T sram.ld $^ $(LOADLIBES) $(LDLIBS) -o $@

%.sramreloc.elf: %.o
	$(LINK.c) -T sramreloc.ld $^ $(LOADLIBES) $(LDLIBS) -o $@

%.flash.elf: %.o
	$(LINK.c) -T flash.ld $^ $(LOADLIBES) $(LDLIBS) -o $@

%.flash0.elf: %.o
	$(LINK.c) -T flash0.ld $^ $(LOADLIBES) $(LDLIBS) -o $@

%.flashreloc.elf: %.o
	$(LINK.c) -T flashreloc.ld $^ $(LOADLIBES) $(LDLIBS) -o $@

%.bin: %.elf
	$(OBJCOPY) -O binary $< $@
