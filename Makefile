
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

RENAME=mv $*-gerber/$*.$1 $*-gerber/$*.$($1_ext)
DELETE=rm $*-gerber/$*.$1

sdr-gerbers: front.gbr_ext=TopSide.gbr
sdr-gerbers: frontmask.gbr_ext=TopSolderMask.gbr
sdr-gerbers: frontsilk.gbr_ext=TopSilkscreen.gbr
sdr-gerbers: back.gbr_ext=BotSide.gbr
sdr-gerbers: backmask.gbr_ext=BotSoldermask.gbr
sdr-gerbers: backsilk.gbr_ext=BotSilkscreen.gbr
sdr-gerbers: outline.gbr_ext=BoardOutline.gbr
sdr-gerbers: plated-drill.cnc_ext=Drill.cnc
sdr-gerbers: group1.gbr_ext=Innerlayer1.gbr
sdr-gerbers: group2.gbr_ext=Innerlayer2.gbr

BATCH=ether-spy-gerbers ether-spy-rv-gerbers input-4509-third-gerbers

$(BATCH): front.gbr_ext=top
$(BATCH): frontmask.gbr_ext=stoptop
$(BATCH): frontsilk.gbr_ext=positop
$(BATCH): back.gbr_ext=bot
$(BATCH): backmask.gbr_ext=stopbot
$(BATCH): backsilk.gbr_ext=posibot
$(BATCH): outline.gbr_ext=outline
$(BATCH): plated-drill.cnc_ext=drill
$(BATCH): group1.gbr_ext=g1
$(BATCH): group2.gbr_ext=g2

.PHONY: %-gerbers
%-gerbers:
	-rm $*-gerber/*
	-rmdir $*-gerber/
	mkdir $*-gerber
	cp $*.pcb $*-gerber/
	cd $*-gerber && pcb -x gerber $*.pcb --outfile foo
	$(call RENAME,front.gbr)
	$(call RENAME,frontmask.gbr)
	$(call DELETE,frontpaste.gbr)
	$(call RENAME,frontsilk.gbr)
	$(call RENAME,back.gbr)
	$(call RENAME,backmask.gbr)
	$(call DELETE,backpaste.gbr)
	-$(call RENAME,backsilk.gbr)
	-$(call RENAME,group1.gbr)
	-$(call RENAME,group2.gbr)
	$(call RENAME,outline.gbr)
	$(call DELETE,fab.gbr)
	$(call RENAME,plated-drill.cnc)
	rm $*-gerber/$*.pcb

%.zip: %-gerbers
	-rm $*.zip
	cd $*-gerber && zip ../$*.zip *.*

.PHONY: zips
zips: sdr.zip input-4509-third.zip ether-spy.zip ether-spy-rv.zip

phasedetectsim: LDFLAGS=-lfftw3 -lpthread -lm
