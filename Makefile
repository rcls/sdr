
SAMPBIN=dump readdump readdump14 readdump22 spectrum spectrum-reduce commands \
	mlt3-detect ftrans

all: sinrom.vhd phasedetectsim pllsim $(SAMPBIN:%=sample/%)

DEP=-MMD -MP -MF.$(subst /,:,$@).d

CFLAGS=-O3 -flto -ffast-math -Wall -Werror -std=gnu99 -g -I. $(DEP)
LDFLAGS=$(CFLAGS) -lm

util/phasespect: LDLIBS=-lfftw3_threads -lfftw3
util/phasespect: lib/util.o
util/irspec: LDLIBS=-lfftw3_threads -lfftw3
util/irspec: lib/util.o

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

sinrom.vhd: sinrom
	./sinrom > sinrom.vhd

# Cancel built-in
%: %.c

.PRECIOUS: %.o

-include .*.d

phasedetectsim: LDLIBS=-lfftw3 -lpthread -lm
