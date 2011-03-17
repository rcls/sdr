v 20100214 2
C 44700 40300 1 0 0 lm3s828-analog-debug.sym
{
T 45100 40500 5 10 1 1 0 0 1
device=LM3S828 Analog & Debug
T 46000 41200 5 10 1 1 0 0 1
footprint=QFN48
T 46200 42000 5 10 1 1 0 0 1
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
C 48000 40400 1 90 0 capacitor.sym
{
T 47300 40600 5 10 0 0 90 0 1
device=CAPACITOR
T 48300 40900 5 10 1 1 180 0 1
refdes=C604
T 47100 40600 5 10 0 0 90 0 1
symversion=0.1
T 47900 40300 5 10 1 1 0 0 1
value=1uF
T 48000 40600 5 10 0 1 0 0 1
footprint=0603
}
N 47600 40900 47800 40900 4
C 47700 40100 1 0 0 gnd-1.sym
T 46700 49500 6 20 1 0 0 0 1
Sheet 6 - Misc IO
C 44700 40000 1 90 0 capacitor.sym
{
T 44000 40200 5 10 0 0 90 0 1
device=CAPACITOR
T 44300 40200 5 10 1 1 180 0 1
refdes=C602
T 43800 40200 5 10 0 0 90 0 1
symversion=0.1
T 44700 40000 5 10 0 1 0 0 1
footprint=0603
}
C 44400 39700 1 0 0 gnd-1.sym
N 44500 40900 44800 40900 4
C 43600 41200 1 0 0 resistor-1.sym
{
T 43900 41600 5 10 0 0 0 0 1
device=RESISTOR
T 43800 41500 5 10 1 1 0 0 1
refdes=R610
T 43500 41000 5 10 1 1 0 0 1
value=100k
T 43600 41200 5 10 0 1 0 0 1
footprint=0603
}
C 43400 41300 1 0 0 3.3v-digital-1.sym
T 43700 44100 8 10 1 0 0 0 1
FIXME - add voltage monitors?
C 50500 49400 1 90 0 resistor-1.sym
{
T 50100 49700 5 10 0 0 90 0 1
device=RESISTOR
T 50200 49600 5 10 1 1 90 0 1
refdes=R608
T 50500 49400 5 10 0 1 90 0 1
footprint=0603
}
C 50400 49300 1 0 1 resistor-1.sym
{
T 50100 49700 5 10 0 0 0 6 1
device=RESISTOR
T 50200 49100 5 10 1 1 0 6 1
refdes=R699
T 50400 49300 5 10 0 1 0 6 1
footprint=0603
}
C 49600 49100 1 0 1 gnd-1.sym
N 50400 48700 50400 49400 4
C 50200 50300 1 0 0 3.3v-digital-1.sym
C 53800 44800 1 0 1 txo-1.sym
{
T 53600 45700 5 10 1 1 0 6 1
refdes=U61
T 53600 46800 5 10 0 0 0 6 1
device=VTXO
T 52900 45800 5 10 0 1 0 0 1
footprint=smt-osc-3mm.fp
}
N 53800 44400 53800 45500 4
C 52400 44300 1 0 0 resistor-1.sym
{
T 52700 44700 5 10 0 0 0 0 1
device=RESISTOR
T 52600 44600 5 10 1 1 0 0 1
refdes=R698
T 52400 44300 5 10 0 1 0 0 1
footprint=0603
}
N 46600 48400 47000 48400 4
N 46200 48100 47000 48100 4
N 45800 47800 47000 47800 4
N 45400 47500 47000 47500 4
N 45000 47200 47000 47200 4
N 44600 46900 47000 46900 4
C 54200 45800 1 90 0 capacitor.sym
{
T 53500 46000 5 10 0 0 90 0 1
device=CAPACITOR
T 54000 46500 5 10 1 1 180 0 1
refdes=C605
T 53300 46000 5 10 0 0 90 0 1
symversion=0.1
T 54200 45800 5 10 0 1 0 0 1
footprint=0603
}
N 53000 46300 54000 46300 4
N 54000 45800 54000 44800 4
N 53000 44800 55100 44800 4
C 53400 44500 1 0 0 gnd-1.sym
T 43700 44700 8 10 1 0 0 0 1
FIXME - check pinout.
N 47600 43600 53900 43600 4
N 47600 42700 53000 42700 4
N 47600 43000 53600 43000 4
N 47600 42400 53300 42400 4
N 47600 43300 54200 43300 4
C 52800 50500 1 0 1 74aup1g04.sym
{
T 52500 50600 5 10 1 1 0 6 1
device=74 1G04
T 51700 50600 5 10 1 1 0 6 1
footprint=SC70_5
T 52000 51100 5 10 1 1 0 6 1
refdes=U62
}
C 53400 50700 1 90 0 capacitor.sym
{
T 52700 50900 5 10 0 0 90 0 1
device=CAPACITOR
T 53400 50600 5 10 1 1 180 0 1
refdes=C603
T 52500 50900 5 10 0 0 90 0 1
symversion=0.1
T 53400 50700 5 10 0 1 0 0 1
footprint=0603
}
C 53300 51200 1 90 0 resistor-1.sym
{
T 52900 51500 5 10 0 0 90 0 1
device=RESISTOR
T 53100 51300 5 10 1 1 90 0 1
refdes=R612
T 53300 51200 5 10 0 1 0 0 1
footprint=0603
}
C 50300 51300 1 0 0 capacitor.sym
{
T 50500 52000 5 10 0 0 0 0 1
device=CAPACITOR
T 50400 51100 5 10 1 1 0 0 1
refdes=C601
T 50500 52200 5 10 0 0 0 0 1
symversion=0.1
T 50300 51300 5 10 0 1 0 0 1
footprint=0603
}
N 52800 50900 52800 50700 4
N 52800 50700 53200 50700 4
C 52700 50400 1 0 0 gnd-1.sym
C 50200 51200 1 0 0 gnd-1.sym
C 51500 52000 1 0 0 input-2.sym
{
T 51500 52200 5 10 0 0 0 0 1
net=OVR:1
T 52100 52700 5 10 0 0 0 0 1
device=none
T 52600 52100 5 10 1 1 0 7 1
value=OVR
}
N 50400 46000 51700 46000 4
N 51700 46000 51700 47800 4
N 51700 47800 55600 47800 4
N 50400 46900 52000 46900 4
N 50400 47500 51400 47500 4
N 50400 47800 51100 47800 4
N 50400 48100 55600 48100 4
N 50400 48400 55600 48400 4
C 54600 46300 1 0 0 gnd-1.sym
N 55600 49300 55600 49600 4
N 55600 49600 55100 49600 4
C 54900 49600 1 0 0 3.3V-plus-1.sym
C 54900 46000 1 0 0 1.2V-plus-1.sym
N 55100 46000 55600 46000 4
N 55600 45700 55100 45700 4
N 55100 45700 55100 46000 4
N 52900 52100 53200 52100 4
N 52800 51200 52900 51200 4
N 52900 51200 52900 52100 4
C 55500 45500 1 0 0 conn7by2.sym
{
T 55900 49800 5 10 1 1 0 0 1
refdes=CONN62
T 56400 47800 5 10 0 1 0 0 1
footprint=ra-0.1inch-female
}
T 43700 44400 8 10 1 0 0 0 1
FIXME - add switches.
C 43200 48800 1 270 0 resistor-1.sym
{
T 43600 48500 5 10 0 0 270 0 1
device=RESISTOR
T 43450 48550 5 10 1 1 270 0 1
refdes=R609
T 43200 48800 5 10 0 1 270 0 1
footprint=0603
}
C 43600 49600 1 270 0 resistor-1.sym
{
T 44000 49300 5 10 0 0 270 0 1
device=RESISTOR
T 43850 49400 5 10 1 1 270 0 1
refdes=R607
T 43600 49600 5 10 0 1 270 0 1
footprint=0603
}
C 44000 48900 1 270 0 resistor-1.sym
{
T 44400 48600 5 10 0 0 270 0 1
device=RESISTOR
T 44250 48650 5 10 1 1 270 0 1
refdes=R606
T 44000 48900 5 10 0 1 270 0 1
footprint=0603
}
C 44400 49600 1 270 0 resistor-1.sym
{
T 44800 49300 5 10 0 0 270 0 1
device=RESISTOR
T 44650 49400 5 10 1 1 270 0 1
refdes=R605
T 44400 49600 5 10 0 1 270 0 1
footprint=0603
}
C 44800 48900 1 270 0 resistor-1.sym
{
T 45200 48600 5 10 0 0 270 0 1
device=RESISTOR
T 45050 48650 5 10 1 1 270 0 1
refdes=R604
T 44800 48900 5 10 0 1 270 0 1
footprint=0603
}
C 45200 49600 1 270 0 resistor-1.sym
{
T 45600 49300 5 10 0 0 270 0 1
device=RESISTOR
T 45050 49400 5 10 1 1 270 0 1
refdes=R603
T 45200 49600 5 10 0 1 270 0 1
footprint=0603
}
C 45600 49300 1 270 0 resistor-1.sym
{
T 46000 49000 5 10 0 0 270 0 1
device=RESISTOR
T 45450 49050 5 10 1 1 270 0 1
refdes=R602
T 45600 49300 5 10 0 1 270 0 1
footprint=0603
}
C 46000 49600 1 270 0 resistor-1.sym
{
T 46400 49300 5 10 0 0 270 0 1
device=RESISTOR
T 46200 49500 5 10 1 1 270 0 1
refdes=R601
T 46000 49600 5 10 0 1 270 0 1
footprint=0603
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
N 50400 45400 52200 45400 4
N 51900 44400 51900 45700 4
N 51900 45700 50400 45700 4
N 53300 44400 53800 44400 4
N 51900 44400 52400 44400 4
N 52200 45400 52200 45500 4
N 50800 50900 50800 46600 4
N 50800 46600 50400 46600 4
C 51900 46300 1 0 0 3.3V-plus-1.sym
C 52100 46200 1 0 0 fuse-2.sym
{
T 52300 46750 5 10 0 0 0 0 1
device=FUSE
T 52500 46500 5 10 1 1 0 0 1
refdes=FB61
T 52300 46950 5 10 0 0 0 0 1
symversion=0.1
T 52400 46400 5 10 0 1 0 0 1
footprint=s0805
}
N 53900 43600 53900 41200 4
N 54200 43300 54200 41200 4
N 53300 42400 53300 41200 4
N 53600 43000 53600 41200 4
N 53000 42700 53000 41200 4
C 55200 41400 1 0 0 3.3v-digital-1.sym
N 55100 41200 55100 44800 4
N 55400 41200 55400 41400 4
C 50700 41800 1 0 0 input-2.sym
{
T 50300 41800 5 10 1 0 0 0 1
net=U0Rx:1
T 51300 42500 5 10 0 0 0 0 1
device=none
T 51800 41900 5 10 1 1 0 7 1
value=U0Rx
}
C 51000 42100 1 0 0 input-2.sym
{
T 50600 42100 5 10 1 0 0 0 1
net=U0Tx:1
T 51600 42800 5 10 0 0 0 0 1
device=none
T 52100 42200 5 10 1 1 0 7 1
value=U0Tx
}
C 50100 41200 1 0 0 input-2.sym
{
T 49800 41200 5 10 1 0 0 0 1
net=SCL:1
T 50700 41900 5 10 0 0 0 0 1
device=none
T 51100 41300 5 10 1 1 0 7 1
value=SCL
}
C 50400 41500 1 0 0 input-2.sym
{
T 50100 41500 5 10 1 0 0 0 1
net=SDA:1
T 51000 42200 5 10 0 0 0 0 1
device=none
T 51400 41600 5 10 1 1 0 7 1
value=SDA
}
C 54700 42600 1 270 0 input-2.sym
{
T 54700 42900 5 10 1 0 270 0 1
net=PB6:1
T 55400 42000 5 10 0 0 270 0 1
device=none
T 54800 41600 5 10 1 1 270 7 1
value=PB6
}
C 54400 42600 1 270 0 input-2.sym
{
T 54400 42900 5 10 1 0 270 0 1
net=PB5:1
T 55100 42000 5 10 0 0 270 0 1
device=none
T 54500 41600 5 10 1 1 270 7 1
value=PB5
}
N 52400 42200 52400 41200 4
N 52100 41900 52100 41200 4
C 43500 40500 1 0 0 switch-pushbutton-no-1.sym
{
T 43800 40300 5 10 1 1 0 0 1
refdes=S61
T 43900 41100 5 10 0 0 0 0 1
device=SWITCH_PUSHBUTTON_NO
T 43500 40500 5 10 0 0 0 0 1
footprint=mini-push-button
}
N 44500 40500 44500 41300 4
N 43500 40500 43500 40000 4
N 43500 40000 44500 40000 4
N 51500 41300 51500 41200 4
N 51800 41600 51800 41200 4
N 54700 46600 55600 46600 4
N 55600 46600 55600 46300 4
N 51100 47800 51100 49000 4
N 51100 49000 55600 49000 4
N 51400 47500 51400 48700 4
N 51400 48700 55600 48700 4
N 52000 46900 52000 47500 4
N 52000 47500 55600 47500 4
C 57400 41300 1 90 1 conn10by2.sym
{
T 51300 40900 5 10 1 1 270 2 1
refdes=CONN61
T 52000 40800 5 10 1 1 0 0 1
footprint=ra-0.1inch-female-10by2
}
C 55900 42600 1 270 0 input-2.sym
{
T 55900 42900 5 10 1 0 270 0 1
net=P47:1
T 56600 42000 5 10 0 0 270 0 1
device=none
T 56000 41600 5 10 1 1 270 7 1
value=P47
}
C 55600 42600 1 270 0 input-2.sym
{
T 55600 42900 5 10 1 0 270 0 1
net=P48:1
T 56300 42000 5 10 0 0 270 0 1
device=none
T 55700 41600 5 10 1 1 270 7 1
value=P48
}
C 56500 42600 1 270 0 input-2.sym
{
T 56500 42900 5 10 1 0 270 0 1
net=P50:1
T 57200 42000 5 10 0 0 270 0 1
device=none
T 56600 41600 5 10 1 1 270 7 1
value=P50
}
C 56200 42600 1 270 0 input-2.sym
{
T 56200 42900 5 10 1 0 270 0 1
net=P51:1
T 56900 42000 5 10 0 0 270 0 1
device=none
T 56300 41600 5 10 1 1 270 7 1
value=P51
}
C 57100 42600 1 270 0 input-2.sym
{
T 57100 42900 5 10 1 0 270 0 1
net=P55:1
T 57800 42000 5 10 0 0 270 0 1
device=none
T 57200 41600 5 10 1 1 270 7 1
value=P55
}
C 56800 42600 1 270 0 input-2.sym
{
T 56800 42900 5 10 1 0 270 0 1
net=P56:1
T 57500 42000 5 10 0 0 270 0 1
device=none
T 56900 41600 5 10 1 1 270 7 1
value=P56
}
