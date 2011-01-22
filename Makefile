
CFLAGS=-O2 -Wall -Werror -std=gnu99 -g
LDFLAGS=-lm

all: sinrom.vhd phasedetectsim

sinrom.vhd: sinrom
	./sinrom > sinrom.vhd

phasedetectsim: LDFLAGS=-lrfftw -lfftw -lpthread -lm
