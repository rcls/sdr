
CFLAGS=-O2 -Wall -Werror -std=gnu99 -g
LDFLAGS=-lm

all: sinrom.vhd phasedetectsim pllsim

sinrom.vhd: sinrom
	./sinrom > sinrom.vhd

.PHONY: png live
png:
	pcb -x png --outfile sdr.png --dpi 300 --as-shown --layer-stack silk,Component,CompPwr,GND,GNDsig,Power,PowerSig,Solder,SolderPwr,SolderGND sdr.pcb
	pcb -x png --outfile sdrb.png --dpi 300 --as-shown --layer-stack silk,solderside,Component,CompPwr,GND,GNDsig,Power,PowerSig,Solder,SolderPwr,SolderGND sdr.pcb
	pcb -x png --outfile sdr-s.png --dpi 100 --as-shown --layer-stack silk,Component,CompPwr,GND,GNDsig,Power,PowerSig,Solder,SolderPwr,SolderGND sdr.pcb
	pcb -x png --outfile sdrb-s.png --dpi 100 --as-shown --layer-stack silk,solderside,Component,CompPwr,GND,GNDsig,Power,PowerSig,Solder,SolderPwr,SolderGND sdr.pcb
www: png
	cp sdr.png sdrb.png sdr-s.png sdrb-s.png ~/public_html/sdr


phasedetectsim: LDFLAGS=-lfftw3 -lpthread -lm
