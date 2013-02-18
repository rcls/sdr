
SAMPBIN=dump spectrum spectrum-reduce commands mlt3-detect
UTILBIN=phasespect irspec burstspec spiflash

all: vhdl/sinrom.vhd phasedetectsim pllsim $(SAMPBIN:%=sample/%) \
	$(UTILBIN:%=util/%)

DEP=-MMD -MP -MF.$(subst /,:,$@).d

CFLAGS=-O3 -flto -ffast-math -msse2 -Wall -Werror -std=gnu99 -g -I. $(DEP) -fweb -fopenmp
LDFLAGS=$(CFLAGS) -fwhole-program

LDLIBS=-lfftw3_threads -lfftw3 -lfftw3f_threads -lfftw3f -lusb-1.0 -lm

util/phasespect: lib/usb.o lib/util.o
util/irspec: lib/util.o lib/usb.o
util/spiflash: lib/util.o lib/usb.o
util/burstspec: lib/usb.o lib/util.o

sample/commands: lib/usb.o lib/util.o
sample/dump: lib/usb.o lib/util.o
sample/mlt3-detect: lib/util.o lib/usb.o
sample/spectrum-reduce: lib/util.o
sample/spectrum: lib/util.o lib/usb.o

vhdl/sinrom.vhd: sinrom
	./$< > $@

fir: fir.hs
	ghc -O2 -o $@ $<

.PHONY: clean all
clean:
	rm -f *.o */*.o  $(SAMPBIN:%=sample/%) $(UTILBIN:%=util/%)

# Cancel built-in
%: %.c

.PRECIOUS: %.o

-include .*.d

phasedetectsim: LDLIBS=-lfftw3 -lpthread -lm
