
UTILBIN=dump spectrum spectrum-reduce mlt3-detect \
	phasespect irspec burstspec spiflash command monwrite xyspect
BINARIES=$(UTILBIN:%=util/%)
all: vhdl/sinrom.vhd phasedetectsim pllsim $(BINARIES) cpu

DEP=-MMD -MP -MF.deps/$(subst /,:,$@).d

CFLAGS=-O3 -flto -ffast-math -msse2 -Wall -Werror -std=gnu99 -g -I. $(DEP) -fweb -fopenmp -fuse-linker-plugin
LDFLAGS=$(CFLAGS)

LDLIBS=-lfftw3f_threads -lfftw3f -lusb-1.0 -lm

$(BINARIES): lib/usb.o lib/util.o

vhdl/sinrom.vhd: sinrom
	./$< > $@

fir: fir.hs
	ghc -O2 -o $@ $<

.PHONY: clean all
clean:
	rm -f *.o */*.o $(UTILBIN:%=util/%)

.PHONY: cpu
cpu:
	$(MAKE) -C cpu all

.PHONY: FORCE
cpu/%: FORCE
	$(MAKE) -C cpu $*

# Cancel built-in
%: %.c

%.s: %.c
	$(COMPILE.c) -S -o $@ $<

.PRECIOUS: %.o

-include .deps/*.d

phasedetectsim: LDLIBS=-lfftw3 -lpthread -lm
