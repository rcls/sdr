
SAMPBIN=dump spectrum spectrum-reduce mlt3-detect
UTILBIN=phasespect irspec burstspec spiflash ssi
BINARIES=$(SAMPBIN:%=sample/%) $(UTILBIN:%=util/%)
all: vhdl/sinrom.vhd phasedetectsim pllsim $(BINARIES) cpu

DEP=-MMD -MP -MF.$(subst /,:,$@).d

CFLAGS=-O3 -flto -ffast-math -msse2 -Wall -Werror -std=gnu99 -g -I. $(DEP) -fweb -fopenmp
LDFLAGS=$(CFLAGS) -fwhole-program

LDLIBS=-lfftw3f_threads -lfftw3f -lusb-1.0 -lm

$(BINARIES): lib/usb.o lib/util.o

vhdl/sinrom.vhd: sinrom
	./$< > $@

fir: fir.hs
	ghc -O2 -o $@ $<

.PHONY: clean all
clean:
	rm -f *.o */*.o  $(SAMPBIN:%=sample/%) $(UTILBIN:%=util/%)

.PHONY: cpu
cpu:
	$(MAKE) -C cpu all

# Cancel built-in
%: %.c

%.s: %.c
	$(COMPILE.c) -S -o $@ $<

.PRECIOUS: %.o

-include .*.d

phasedetectsim: LDLIBS=-lfftw3 -lpthread -lm
