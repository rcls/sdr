
all: sinrom.vhd phasedetectsim pllsim dump readdump readdump14 readdump22

DEP=-MMD -MP -MF.$(subst /,:,$@).d

CFLAGS=-O3 -flto -ffast-math -Wall -Werror -std=gnu99 -g -I. $(DEP)
LDFLAGS=$(CFLAGS) -lm
dump: LDFLAGS=$(CFLAGS) -lusb-1.0
ftrans: LDFLAGS=$(CFLAGS) -lfftw3 -lm
mlt3-detect: LDFLAGS=$(CFLAGS) -lfftw3_threads -lfftw3 -lm
mlt3-detect: lib/legendre.o
readdump22: lib/util.o
dump: lib/usb.o lib/util.o

sinrom.vhd: sinrom
	./sinrom > sinrom.vhd

# Cancel built-in
%: %.c

-include .*.d

phasedetectsim: LDFLAGS=-lfftw3 -lpthread -lm

W=www
LS=Top,TopGND,TopPWR,Back,BackGND,BackPWR
sdr-png: LS=Component,CompPwr,GND,GNDsig,Power,PowerSig,Solder,SolderPwr,SolderGND

PCBPNG=pcb -x png --as-shown --layer-stack silk,$(LS)

PNGS=sdr-png ether-spy-png ether-spy-rv-png input-4509-third-png
.PHONY: pngs $(PNGS)
$(PNGS): %-png: $W/%.png $W/%-s.png $W/%b.png $W/%b-s.png

pngs: $(PNGS)

$W/%.png: %.pcb
	$(PCBPNG) --outfile $@ --dpi 300 $<
$W/%-s.png: %.pcb
	$(PCBPNG) --outfile $@ --dpi 100 $<
$W/%b.png: %.pcb
	$(PCBPNG),solderside --outfile $@ --dpi 300 $<
$W/%b-s.png: %.pcb
	$(PCBPNG),solderside --outfile $@ --dpi 100 $<

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
