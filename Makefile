
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

RENAME=mv $3 $*-gerber/$*.$1.gbr $*-gerber/$*.$2.gbr
DELETE=rm $*-gerber/$*.$1.gbr

%-gerbers:
	rm $*-gerber/* || true
	rmdir $*-gerber/ || true
	mkdir sdr-gerber
	cp $*.pcb $*-gerber/
	cd $*-gerber && pcb -x gerber $*.pcb --outfile foo
	$(call RENAME,front,TopSide)
	$(call RENAME,frontmask,TopSolderMask)
	$(call DELETE,frontpaste)
	$(call RENAME,frontsilk,TopSilkscreen)
	$(call RENAME,back,BotSide)
	$(call RENAME,backmask,BackSolderMask)
	$(call DELETE,backpaste)
	$(call RENAME,backsilk,BackSilkscreen)
	$(call RENAME,group1,Innerlayer1,-f)
	$(call RENAME,group2,Innerlayer2,-f)
	$(call RENAME,outline,BoardOutline)
	$(call DELETE,fab)
	mv $*-gerber/$*.plated-drill.cnc $*-gerber/$*.Drill.cnc
	rm $*-gerber/$*.pcb


phasedetectsim: LDFLAGS=-lfftw3 -lpthread -lm
