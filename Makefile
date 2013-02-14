
SAMPBIN=dump readdump readdump14 readdump22 spectrum spectrum-reduce commands \
	mlt3-detect ftrans
UTILBIN=phasespect irspec burstspec spiflash

all: vhdl/sinrom.vhd phasedetectsim pllsim $(SAMPBIN:%=sample/%) \
	$(UTILBIN:%=util/%)

DEP=-MMD -MP -MF.$(subst /,:,$@).d

CFLAGS=-O3 -flto -ffast-math -Wall -Werror -std=gnu99 -g -I. $(DEP)
LDFLAGS=$(CFLAGS) -lm

util/phasespect: LDLIBS=-lfftw3_threads -lfftw3 -lusb-1.0
util/phasespect: lib/usb.o lib/util.o
util/irspec: LDLIBS=-lfftw3_threads -lfftw3 -lusb-1.0
util/irspec: lib/util.o lib/usb.o
util/spiflash: lib/util.o lib/usb.o -lusb-1.0
util/burstspec: lib/usb.o lib/util.o -lfftw3_threads -lfftw3 -lusb-1.0

sample/commands: LDLIBS=-lusb-1.0
sample/commands: lib/usb.o lib/util.o
sample/dump: LDLIBS=-lusb-1.0
sample/dump: lib/usb.o lib/util.o
sample/ftrans: LDLIBS=-lfftw3 -lm
sample/mlt3-detect: LDLIBS=-lfftw3_threads -lfftw3 -lm
sample/mlt3-detect: lib/legendre.o
sample/readdump14: lib/util.o
sample/readdump22: lib/util.o
sample/spectrum-reduce: lib/util.o
sample/spectrum: LDLIBS=-lusb-1.0 -lfftw3_threads -lfftw3
sample/spectrum: lib/util.o lib/usb.o

vhdl/sinrom.vhd: sinrom
	./$< > $@

fir: fir.hs
	ghc -O2 -o $@ $<

# Cancel built-in
%: %.c

.PRECIOUS: %.o

-include .*.d

phasedetectsim: LDLIBS=-lfftw3 -lpthread -lm
