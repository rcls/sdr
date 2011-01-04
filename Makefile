
CFLAGS=-O2 -Wall -Werror -std=gnu99
LDFLAGS=-lm

sinrom.vhd: sinrom
	./sinrom > sinrom.vhd
