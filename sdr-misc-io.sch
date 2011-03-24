v 20100214 2
C 45500 40100 1 0 0 lm3s828-analog-debug.sym
{
T 45900 40300 5 10 1 1 0 0 1
device=LM3S828 Analog & Debug
T 46800 41000 5 10 1 1 0 0 1
footprint=QFN48
T 47000 41800 5 10 1 1 0 0 1
refdes=U5
}
C 46800 44400 1 0 0 spartan6-qfp144-bank0.sym
{
T 47600 44500 5 10 1 1 0 0 1
device=Spartan6 Bank 0
T 49100 44500 5 10 1 1 0 0 1
footprint=QFP144
T 48900 47700 5 10 1 1 0 0 1
refdes=U2
}
C 48800 40200 1 90 0 capacitor.sym
{
T 48100 40400 5 10 0 0 90 0 1
device=CAPACITOR
T 49100 40700 5 10 1 1 180 0 1
refdes=C604
T 47900 40400 5 10 0 0 90 0 1
symversion=0.1
T 48700 40100 5 10 1 1 0 0 1
value=1uF
T 48800 40400 5 10 0 1 0 0 1
footprint=0603
}
N 48400 40700 48600 40700 4
C 48500 39900 1 0 0 gnd-1.sym
T 46500 49400 6 20 1 0 0 0 1
Sheet 6 - Misc IO
C 45700 39800 1 90 0 capacitor.sym
{
T 45000 40000 5 10 0 0 90 0 1
device=CAPACITOR
T 45300 40000 5 10 1 1 180 0 1
refdes=C602
T 44800 40000 5 10 0 0 90 0 1
symversion=0.1
T 45700 39800 5 10 0 1 0 0 1
footprint=0603
T 45400 40000 5 10 0 1 0 0 1
value=100n
}
C 45400 39500 1 0 0 gnd-1.sym
N 45500 40700 45600 40700 4
C 43700 41600 1 0 0 resistor-1.sym
{
T 44000 42000 5 10 0 0 0 0 1
device=RESISTOR
T 43900 41900 5 10 1 1 0 0 1
refdes=R610
T 43600 41400 5 10 1 1 0 0 1
value=100k
T 43700 41600 5 10 0 1 0 0 1
footprint=0603
}
C 43500 41700 1 0 0 3.3v-digital-1.sym
C 50400 49800 1 180 0 resistor-1.sym
{
T 50100 49400 5 10 0 0 180 0 1
device=RESISTOR
T 50200 50000 5 10 1 1 180 0 1
refdes=R608
T 50400 49800 5 10 0 1 180 0 1
footprint=0603
T 50400 49800 5 10 0 1 0 0 1
value=DNP
}
C 50400 49300 1 0 1 resistor-1.sym
{
T 50100 49700 5 10 0 0 0 6 1
device=RESISTOR
T 50200 49100 5 10 1 1 0 6 1
refdes=R699
T 50400 49300 5 10 0 1 0 6 1
footprint=0603
T 50400 49300 5 10 0 1 0 0 1
value=DNP
}
C 49600 49100 1 0 1 gnd-1.sym
N 50400 48700 50400 49700 4
C 49300 49700 1 0 0 3.3v-digital-1.sym
C 53000 44800 1 0 1 txo-1.sym
{
T 52800 45700 5 10 1 1 0 6 1
refdes=U61
T 52800 46800 5 10 0 0 0 6 1
device=VTXO
T 52100 45800 5 10 0 1 0 0 1
footprint=smt-osc-3mm.fp
}
N 53000 44400 53000 45500 4
N 46600 48400 47000 48400 4
N 46200 48100 47000 48100 4
N 45800 47800 47000 47800 4
N 45400 47500 47000 47500 4
N 45000 47200 47000 47200 4
N 44600 46900 47000 46900 4
C 53400 45800 1 90 0 capacitor.sym
{
T 52700 46000 5 10 0 0 90 0 1
device=CAPACITOR
T 53400 46500 5 10 1 1 180 0 1
refdes=C605
T 52500 46000 5 10 0 0 90 0 1
symversion=0.1
T 53400 45800 5 10 0 1 0 0 1
footprint=0603
T 53300 46000 5 10 0 1 0 0 1
value=100n
}
N 52200 46300 53200 46300 4
N 52200 44800 53200 44800 4
C 52600 44500 1 0 0 gnd-1.sym
N 48400 43400 52700 43400 4
N 48400 42500 51800 42500 4
N 48400 42800 52400 42800 4
N 48400 42200 52100 42200 4
N 48400 43100 53000 43100 4
C 52700 49400 1 0 1 74aup1g04.sym
{
T 52400 49500 5 10 1 1 0 6 1
device=74 1G04
T 51600 49500 5 10 1 1 0 6 1
footprint=SC70_5
T 51900 50000 5 10 1 1 0 6 1
refdes=U62
}
C 53300 49600 1 90 0 capacitor.sym
{
T 52600 49800 5 10 0 0 90 0 1
device=CAPACITOR
T 53300 49500 5 10 1 1 180 0 1
refdes=C603
T 52400 49800 5 10 0 0 90 0 1
symversion=0.1
T 53300 49600 5 10 0 1 0 0 1
footprint=0603
T 53100 49900 5 10 0 1 0 0 1
value=10n
}
C 53200 50100 1 90 0 resistor-1.sym
{
T 52800 50400 5 10 0 0 90 0 1
device=RESISTOR
T 53000 50200 5 10 1 1 90 0 1
refdes=R612
T 53200 50100 5 10 0 1 0 0 1
footprint=0603
T 53100 50400 5 10 0 1 0 0 1
value=TERM
}
C 50200 50200 1 0 0 capacitor.sym
{
T 50400 50900 5 10 0 0 0 0 1
device=CAPACITOR
T 50300 50000 5 10 1 1 0 0 1
refdes=C601
T 50400 51100 5 10 0 0 0 0 1
symversion=0.1
T 50200 50200 5 10 0 1 0 0 1
footprint=0603
T 50500 50100 5 10 0 1 0 0 1
value=100n
}
N 52700 49800 52700 49600 4
N 52700 49600 53100 49600 4
C 52600 49300 1 0 0 gnd-1.sym
C 50100 50100 1 0 0 gnd-1.sym
C 51400 50900 1 0 0 input-2.sym
{
T 51400 51100 5 10 0 0 0 0 1
net=OVR:1
T 52000 51600 5 10 0 0 0 0 1
device=none
T 52400 51000 5 10 1 1 0 7 1
value=OVR
}
N 50400 46000 51300 46000 4
N 51300 46000 51300 47800 4
N 51300 47800 54900 47800 4
N 50400 46900 51500 46900 4
N 50400 47500 51100 47500 4
N 50400 47800 50900 47800 4
N 50400 48100 54900 48100 4
N 50400 48400 54900 48400 4
C 53900 46300 1 0 0 gnd-1.sym
N 54900 49300 54900 49600 4
N 54900 49600 54400 49600 4
C 54200 49600 1 0 0 3.3V-plus-1.sym
C 54200 46000 1 0 0 1.2V-plus-1.sym
N 54400 46000 54900 46000 4
N 54900 45700 54400 45700 4
N 54400 45700 54400 46000 4
N 52800 51000 53100 51000 4
N 52700 50100 52800 50100 4
N 52800 50100 52800 51000 4
C 54800 45500 1 0 0 conn7by2.sym
{
T 55200 49800 5 10 1 1 0 0 1
refdes=CONN62
T 55700 47800 5 10 0 1 0 0 1
footprint=ra-0.1inch-female
}
C 43200 48800 1 270 0 resistor-1.sym
{
T 43600 48500 5 10 0 0 270 0 1
device=RESISTOR
T 43450 48550 5 10 1 1 270 0 1
refdes=R609
T 43200 48800 5 10 0 1 270 0 1
footprint=0603
T 43200 48800 5 10 0 1 0 0 1
value=1k
}
C 43600 49600 1 270 0 resistor-1.sym
{
T 44000 49300 5 10 0 0 270 0 1
device=RESISTOR
T 43850 49400 5 10 1 1 270 0 1
refdes=R607
T 43600 49600 5 10 0 1 270 0 1
footprint=0603
T 43600 49600 5 10 0 1 0 0 1
value=1k
}
C 44000 48900 1 270 0 resistor-1.sym
{
T 44400 48600 5 10 0 0 270 0 1
device=RESISTOR
T 44250 48650 5 10 1 1 270 0 1
refdes=R606
T 44000 48900 5 10 0 1 270 0 1
footprint=0603
T 44000 48900 5 10 0 1 0 0 1
value=1k
}
C 44400 49600 1 270 0 resistor-1.sym
{
T 44800 49300 5 10 0 0 270 0 1
device=RESISTOR
T 44650 49400 5 10 1 1 270 0 1
refdes=R605
T 44400 49600 5 10 0 1 270 0 1
footprint=0603
T 44400 49600 5 10 0 1 0 0 1
value=1k
}
C 44800 48900 1 270 0 resistor-1.sym
{
T 45200 48600 5 10 0 0 270 0 1
device=RESISTOR
T 45050 48650 5 10 1 1 270 0 1
refdes=R604
T 44800 48900 5 10 0 1 270 0 1
footprint=0603
T 44800 48900 5 10 0 1 0 0 1
value=1k
}
C 45200 49600 1 270 0 resistor-1.sym
{
T 45600 49300 5 10 0 0 270 0 1
device=RESISTOR
T 45050 49400 5 10 1 1 270 0 1
refdes=R603
T 45200 49600 5 10 0 1 270 0 1
footprint=0603
T 45200 49600 5 10 0 1 0 0 1
value=1k
}
C 45600 49300 1 270 0 resistor-1.sym
{
T 46000 49000 5 10 0 0 270 0 1
device=RESISTOR
T 45450 49050 5 10 1 1 270 0 1
refdes=R602
T 45600 49300 5 10 0 1 270 0 1
footprint=0603
T 45600 49300 5 10 0 1 0 0 1
value=1k
}
C 46000 49600 1 270 0 resistor-1.sym
{
T 46400 49300 5 10 0 0 270 0 1
device=RESISTOR
T 46200 49500 5 10 1 1 270 0 1
refdes=R601
T 46000 49600 5 10 0 1 270 0 1
footprint=0603
T 46000 49600 5 10 0 1 0 0 1
value=1k
}
C 44200 46800 1 180 0 led-3.sym
{
T 43250 46150 5 10 0 0 180 0 1
device=LED
T 43950 46450 5 10 1 1 0 0 1
refdes=D601
T 44200 46400 5 10 0 1 90 0 1
footprint=s0805
}
C 44600 47100 1 180 0 led-3.sym
{
T 43650 46450 5 10 0 0 180 0 1
device=LED
T 44350 46650 5 10 1 1 0 0 1
refdes=D602
T 44600 46700 5 10 0 1 90 0 1
footprint=s0805
}
C 45400 47700 1 180 0 led-3.sym
{
T 44450 47050 5 10 0 0 180 0 1
device=LED
T 45650 47450 5 10 1 1 180 0 1
refdes=D604
T 45400 47300 5 10 0 1 90 0 1
footprint=s0805
}
C 45000 47400 1 180 0 led-3.sym
{
T 44050 46750 5 10 0 0 180 0 1
device=LED
T 44750 47050 5 10 1 1 0 0 1
refdes=D603
T 45000 47000 5 10 0 1 90 0 1
footprint=s0805
}
C 45800 48000 1 180 0 led-3.sym
{
T 44850 47350 5 10 0 0 180 0 1
device=LED
T 45550 47650 5 10 1 1 0 0 1
refdes=D605
T 45800 47600 5 10 0 1 90 0 1
footprint=s0805
}
C 46200 48300 1 180 0 led-3.sym
{
T 45250 47650 5 10 0 0 180 0 1
device=LED
T 46450 48050 5 10 1 1 180 0 1
refdes=D606
T 46200 47900 5 10 0 1 90 0 1
footprint=s0805
}
C 47000 48900 1 180 0 led-3.sym
{
T 46050 48250 5 10 0 0 180 0 1
device=LED
T 46350 48950 5 10 1 1 0 0 1
refdes=D608
T 47000 48500 5 10 0 1 90 0 1
footprint=s0805
}
C 46600 48600 1 180 0 led-3.sym
{
T 45650 47950 5 10 0 0 180 0 1
device=LED
T 46350 48150 5 10 1 1 0 0 1
refdes=D607
T 46600 48200 5 10 0 1 90 0 1
footprint=s0805
}
N 43700 46900 43700 48700 4
N 44500 47500 44500 48700 4
N 45300 48100 45300 48700 4
N 44900 47800 44900 48000 4
N 44100 47200 44100 48000 4
N 43300 46600 43300 47900 4
N 43300 49600 46100 49600 4
N 45700 49300 45700 49600 4
N 43300 48800 43300 49600 4
N 44100 48900 44100 49600 4
N 44900 48900 44900 49600 4
N 44200 46600 47000 46600 4
C 44500 49600 1 0 0 3.3V-plus-1.sym
N 50400 45400 51400 45400 4
N 51100 44400 51100 45700 4
N 51100 45700 50400 45700 4
N 51100 44400 53000 44400 4
N 51400 45400 51400 45500 4
N 50700 49800 50700 46600 4
N 50700 46600 50400 46600 4
N 52700 43400 52700 41000 4
N 53000 43100 53000 41000 4
N 52100 42200 52100 41000 4
N 52400 42800 52400 41000 4
N 51800 42500 51800 41000 4
C 54000 41200 1 0 0 3.3v-digital-1.sym
N 54200 41000 54200 41200 4
C 49500 41600 1 0 0 input-2.sym
{
T 49100 41600 5 10 1 0 0 0 1
net=U0Tx:1
T 50100 42300 5 10 0 0 0 0 1
device=none
T 50600 41700 5 10 1 1 0 7 1
value=U0Tx
}
C 49800 41900 1 0 0 input-2.sym
{
T 49400 41900 5 10 1 0 0 0 1
net=U0Rx:1
T 50400 42600 5 10 0 0 0 0 1
device=none
T 50900 42000 5 10 1 1 0 7 1
value=U0Rx
}
C 48900 41000 1 0 0 input-2.sym
{
T 48600 41000 5 10 1 0 0 0 1
net=SCL:1
T 49500 41700 5 10 0 0 0 0 1
device=none
T 49900 41100 5 10 1 1 0 7 1
value=SCL
}
C 49200 41300 1 0 0 input-2.sym
{
T 48900 41300 5 10 1 0 0 0 1
net=SDA:1
T 49800 42000 5 10 0 0 0 0 1
device=none
T 50200 41400 5 10 1 1 0 7 1
value=SDA
}
C 53500 42400 1 270 0 input-2.sym
{
T 53500 42700 5 10 1 0 270 0 1
net=PB6:1
T 54200 41800 5 10 0 0 270 0 1
device=none
T 53600 41400 5 10 1 1 270 7 1
value=PB6
}
C 53200 42400 1 270 0 input-2.sym
{
T 53200 42700 5 10 1 0 270 0 1
net=PB5:1
T 53900 41800 5 10 0 0 270 0 1
device=none
T 53300 41400 5 10 1 1 270 7 1
value=PB5
}
N 51200 42000 51200 41000 4
N 50900 41700 50900 41000 4
C 43600 40700 1 0 0 switch-pushbutton-no-1.sym
{
T 43900 40500 5 10 1 1 0 0 1
refdes=S61
T 44000 41300 5 10 0 0 0 0 1
device=SWITCH_PUSHBUTTON_NO
T 43600 40700 5 10 0 0 0 0 1
footprint=mini-push-button
}
N 43600 39800 45500 39800 4
N 50300 41100 50300 41000 4
N 50600 41400 50600 41000 4
N 54000 46600 54900 46600 4
N 54900 46600 54900 46300 4
N 50900 47800 50900 49000 4
N 50900 49000 53400 49000 4
N 51100 47500 51100 48700 4
N 51100 48700 52800 48700 4
N 51500 46900 51500 47500 4
N 51500 47500 54900 47500 4
C 56200 41100 1 90 1 conn10by2.sym
{
T 50100 40700 5 10 1 1 270 2 1
refdes=CONN61
T 50800 40600 5 10 1 1 0 0 1
footprint=ra-0.1inch-female-10by2
}
C 54700 42400 1 270 0 input-2.sym
{
T 54700 42700 5 10 1 0 270 0 1
net=P47:1
T 55400 41800 5 10 0 0 270 0 1
device=none
T 54800 41400 5 10 1 1 270 7 1
value=P47
}
C 54400 42400 1 270 0 input-2.sym
{
T 54400 42700 5 10 1 0 270 0 1
net=P48:1
T 55100 41800 5 10 0 0 270 0 1
device=none
T 54500 41400 5 10 1 1 270 7 1
value=P48
}
C 55300 42400 1 270 0 input-2.sym
{
T 55300 42700 5 10 1 0 270 0 1
net=P50:1
T 56000 41800 5 10 0 0 270 0 1
device=none
T 55400 41400 5 10 1 1 270 7 1
value=P50
}
C 55000 42400 1 270 0 input-2.sym
{
T 55000 42700 5 10 1 0 270 0 1
net=P51:1
T 55700 41800 5 10 0 0 270 0 1
device=none
T 55100 41400 5 10 1 1 270 7 1
value=P51
}
C 55900 42400 1 270 0 input-2.sym
{
T 55900 42700 5 10 1 0 270 0 1
net=P55:1
T 56600 41800 5 10 0 0 270 0 1
device=none
T 56000 41400 5 10 1 1 270 7 1
value=P55
}
C 55600 42400 1 270 0 input-2.sym
{
T 55600 42700 5 10 1 0 270 0 1
net=P56:1
T 56300 41800 5 10 0 0 270 0 1
device=none
T 55700 41400 5 10 1 1 270 7 1
value=P56
}
N 47000 45400 46600 45400 4
N 46600 45400 46600 43900 4
N 46600 43900 53800 43900 4
N 53800 43900 53800 46900 4
N 53800 46900 54900 46900 4
N 47000 44800 47000 44100 4
N 47000 44100 53600 44100 4
N 53600 44100 53600 47200 4
N 53600 47200 54900 47200 4
C 50500 50500 1 0 0 3.3v-digital-1.sym
N 50700 50400 50700 50500 4
C 52400 46300 1 0 0 3.3v-digital-1.sym
C 53400 48900 1 0 0 resistor-1.sym
{
T 53700 49300 5 10 0 0 0 0 1
device=RESISTOR
T 53600 49200 5 10 1 1 0 0 1
refdes=R613
T 53400 48900 5 10 0 1 0 0 1
footprint=0603
T 53400 48900 5 10 0 1 0 0 1
value=STERM
}
C 52800 48600 1 0 0 resistor-1.sym
{
T 53100 49000 5 10 0 0 0 0 1
device=RESISTOR
T 52700 48800 5 10 1 1 0 0 1
refdes=R611
T 52800 48600 5 10 0 1 0 0 1
footprint=0603
T 52800 48600 5 10 0 1 0 0 1
value=STERM
}
N 54300 49000 54900 49000 4
N 53700 48700 54900 48700 4
N 45500 40300 45500 40700 4
C 44600 40600 1 0 0 resistor-1.sym
{
T 44900 41000 5 10 0 0 0 0 1
device=RESISTOR
T 44800 40900 5 10 1 1 0 0 1
refdes=R614
T 45100 40800 5 10 0 1 0 0 1
footprint=0603
T 45100 40800 5 10 0 1 0 0 1
value=PULL
}
N 43600 39800 43600 40700 4
N 44600 41700 44600 40700 4
N 53200 43500 53200 45800 4
N 53200 43500 53900 43500 4
N 53900 43500 53900 41000 4
