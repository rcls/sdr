v 20100214 2
C 41800 40200 1 0 0 lm3671.sym
{
T 42200 41400 5 10 1 1 0 0 1
device=LM3671
T 42300 41700 5 10 1 1 0 0 1
refdes=U41
T 42300 40800 5 10 1 1 0 0 1
footprint=LLP6
}
C 43200 47200 1 0 0 lmz12002.sym
{
T 43300 48100 5 10 1 1 0 0 1
device=LMZ12002
T 44600 48100 5 10 1 1 0 0 1
refdes=U42
T 45300 48100 5 10 1 1 0 0 1
footprint=TO-PMOD
}
C 43200 42800 1 0 0 pth08080w.sym
{
T 43600 43900 5 10 1 1 0 0 1
device=PTH08080W
T 44900 43900 5 10 1 1 0 0 1
refdes=U43
T 44100 43600 5 10 1 1 0 0 1
footprint=PTH-TH5E
}
N 45600 43200 45800 43200 4
C 46400 43200 1 0 0 3.3V-plus-1.sym
C 41200 41700 1 0 0 3.3V-plus-1.sym
N 46100 47100 47600 47100 4
N 41400 41700 41800 41700 4
C 46000 42700 1 90 0 capacitor.sym
{
T 45300 42900 5 10 0 0 90 0 1
device=CAPACITOR
T 46000 42600 5 10 1 1 180 0 1
refdes=C407
T 45100 42900 5 10 0 0 90 0 1
symversion=0.1
}
C 46300 46600 1 90 0 capacitor.sym
{
T 45600 46800 5 10 0 0 90 0 1
device=CAPACITOR
T 46000 46300 5 10 1 1 90 0 1
refdes=C404
T 45400 46800 5 10 0 0 90 0 1
symversion=0.1
T 46300 46300 5 10 1 1 90 0 1
value=10u
T 46300 46600 5 10 0 1 0 0 1
footprint=0805
}
C 47300 46600 1 90 0 capacitor.sym
{
T 46600 46800 5 10 0 0 90 0 1
device=CAPACITOR
T 47300 46300 5 10 1 1 90 0 1
refdes=C406
T 46400 46800 5 10 0 0 90 0 1
symversion=0.1
T 47300 46600 5 10 0 0 0 0 1
footprint=0603
}
C 42400 42700 1 90 0 capacitor.sym
{
T 41700 42900 5 10 0 0 90 0 1
device=CAPACITOR
T 42100 43200 5 10 1 1 180 0 1
refdes=C403
T 41500 42900 5 10 0 0 90 0 1
symversion=0.1
T 41700 42700 5 10 1 1 0 0 1
value=100u
T 42400 42900 5 10 0 1 0 0 1
footprint=smt-can-6.3mm
}
C 43100 42700 1 90 0 capacitor.sym
{
T 42400 42900 5 10 0 0 90 0 1
device=CAPACITOR
T 43200 42600 5 10 1 1 180 0 1
refdes=C405
T 42200 42900 5 10 0 0 90 0 1
symversion=0.1
T 42900 42900 5 10 0 1 0 0 1
footprint=0603
}
C 46600 43100 1 0 0 fuse-2.sym
{
T 46800 43650 5 10 0 0 0 0 1
device=FUSE
T 46900 42900 5 10 1 1 0 0 1
refdes=FB42
T 46800 43850 5 10 0 0 0 0 1
symversion=0.1
}
C 47300 43200 1 0 0 3.3v-digital-1.sym
C 42300 43200 1 90 0 fuse-2.sym
{
T 41750 43400 5 10 0 0 90 0 1
device=FUSE
T 42500 43400 5 10 1 1 90 0 1
refdes=FB45
T 41550 43400 5 10 0 0 90 0 1
symversion=0.1
}
N 42200 42700 45800 42700 4
N 44400 42700 44400 42800 4
N 43300 46200 47100 46200 4
N 44700 46200 44700 47200 4
N 42200 47100 43600 47100 4
N 43600 47100 43600 47200 4
N 43200 43200 42200 43200 4
C 44300 42400 1 0 0 gnd-1.sym
C 44600 45900 1 0 0 gnd-1.sym
C 43700 41600 1 0 0 inductor-1.sym
{
T 43900 42100 5 10 0 0 0 0 1
device=INDUCTOR
T 43900 41900 5 10 1 1 0 0 1
refdes=L41
T 43900 42300 5 10 0 0 0 0 1
symversion=0.1
}
C 41600 41200 1 90 0 capacitor.sym
{
T 40900 41400 5 10 0 0 90 0 1
device=CAPACITOR
T 41100 41200 5 10 1 1 90 0 1
refdes=C408
T 40700 41400 5 10 0 0 90 0 1
symversion=0.1
T 41600 41200 5 10 0 1 0 0 1
footprint=0603
}
C 45200 41200 1 90 0 capacitor.sym
{
T 44500 41400 5 10 0 0 90 0 1
device=CAPACITOR
T 45200 41100 5 10 1 1 180 0 1
refdes=C410
T 44300 41400 5 10 0 0 90 0 1
symversion=0.1
T 45200 41200 5 10 0 1 0 0 1
footprint=0805
T 44600 41200 5 10 1 1 0 0 1
value=10u
}
C 45700 41200 1 90 0 capacitor.sym
{
T 45000 41400 5 10 0 0 90 0 1
device=CAPACITOR
T 46000 41300 5 10 1 1 180 0 1
refdes=C411
T 44800 41400 5 10 0 0 90 0 1
symversion=0.1
T 45700 41200 5 10 0 1 0 0 1
footprint=0603
}
N 41400 41200 41400 41100 4
N 41400 41100 41800 41100 4
N 44600 41700 45500 41700 4
N 44600 41700 44600 40500 4
N 44600 40500 43700 40500 4
N 45000 41200 45500 41200 4
C 41300 40800 1 0 0 gnd-1.sym
C 45400 40900 1 0 0 gnd-1.sym
C 46300 41600 1 0 0 fuse-2.sym
{
T 46500 42150 5 10 0 0 0 0 1
device=FUSE
T 46500 41400 5 10 1 1 0 0 1
refdes=FB43
T 46500 42350 5 10 0 0 0 0 1
symversion=0.1
}
N 46100 47100 46100 47200 4
C 41700 46000 1 180 0 header3-1.sym
{
T 40700 45350 5 10 0 0 180 0 1
device=HEADER3
T 41300 46200 5 10 1 1 180 0 1
refdes=J41
T 41300 45400 5 10 0 1 0 0 1
footprint=JUMPER3
}
N 41700 45400 42200 45400 4
N 43300 46600 43300 46200 4
N 46100 46600 46100 46200 4
N 47100 46200 47100 46600 4
C 45600 44200 1 0 0 resistor-1.sym
{
T 45900 44600 5 10 0 0 0 0 1
device=RESISTOR
T 45800 44500 5 10 1 1 0 0 1
refdes=R405
}
C 44900 45400 1 0 0 resistor-1.sym
{
T 45200 45800 5 10 0 0 0 0 1
device=RESISTOR
T 45100 45700 5 10 1 1 0 0 1
refdes=R404
T 44900 45400 5 10 0 1 0 0 1
footprint=0603
}
C 46700 45400 1 0 0 resistor-1.sym
{
T 47000 45800 5 10 0 0 0 0 1
device=RESISTOR
T 46900 45200 5 10 1 1 0 0 1
refdes=R406
T 46700 45400 5 10 0 1 0 0 1
footprint=0603
}
C 46400 44000 1 0 0 gnd-1.sym
C 45700 46600 1 90 0 capacitor.sym
{
T 45000 46800 5 10 0 0 90 0 1
device=CAPACITOR
T 45400 46700 5 10 1 1 180 0 1
refdes=C412
T 44800 46800 5 10 0 0 90 0 1
symversion=0.1
T 45500 46700 5 10 0 1 0 0 1
footprint=0603
}
N 45500 46600 45500 46200 4
C 44000 46300 1 90 0 resistor-1.sym
{
T 43600 46600 5 10 0 0 90 0 1
device=RESISTOR
T 44200 46500 5 10 1 1 90 0 1
refdes=R402
T 44000 46300 5 10 0 1 0 0 1
footprint=0603
}
N 44700 47200 45000 47200 4
C 47100 45800 1 0 0 capacitor.sym
{
T 47300 46500 5 10 0 0 0 0 1
device=CAPACITOR
T 46800 45800 5 10 1 1 0 0 1
refdes=C413
T 47300 46700 5 10 0 0 0 0 1
symversion=0.1
T 47100 45800 5 10 0 1 0 0 1
footprint=0603
}
N 47600 47100 47600 45500 4
C 44800 45200 1 0 0 gnd-1.sym
N 45800 47200 45800 45500 4
N 46700 45500 45800 45500 4
N 47100 46000 46700 46000 4
N 46700 46000 46700 45500 4
C 44000 45400 1 0 0 resistor-1.sym
{
T 44300 45800 5 10 0 0 0 0 1
device=RESISTOR
T 44200 45700 5 10 1 1 0 0 1
refdes=R498
T 44000 45400 5 10 0 1 0 0 1
footprint=0603
}
C 43100 45400 1 0 0 resistor-1.sym
{
T 43400 45800 5 10 0 0 0 0 1
device=RESISTOR
T 43200 45700 5 10 1 1 0 0 1
refdes=R499
T 43100 45400 5 10 0 1 0 0 1
footprint=0603
}
N 44000 46000 44200 46000 4
N 44200 46000 44200 47200 4
C 40900 44200 1 180 1 pwrjack-1.sym
{
T 41000 43700 5 10 0 0 180 6 1
device=PWRJACK
T 40900 43700 5 10 1 1 180 6 1
refdes=CONN41
T 40900 44200 5 10 0 0 0 0 1
footprint=power-jack-2mm
}
C 42000 44100 1 90 0 diode-1.sym
{
T 41400 44500 5 10 0 0 90 0 1
device=DIODE
T 41600 44300 5 10 1 1 90 0 1
refdes=D41
T 41700 44200 5 10 0 1 0 0 1
footprint=DO214
}
C 43000 44100 1 90 0 zener-1.sym
{
T 42400 44500 5 10 0 0 90 0 1
device=ZENER_DIODE
T 42600 44500 5 10 1 1 90 0 1
refdes=D42
T 42600 44200 5 10 0 1 0 0 1
footprint=DO214
}
C 42700 43800 1 0 0 gnd-1.sym
C 41500 45800 1 0 0 5V-plus-1.sym
C 41700 43600 1 0 0 gnd-1.sym
N 41800 45000 41700 45000 4
N 41800 40500 41700 40500 4
N 41700 40500 41700 41700 4
C 46100 41700 1 0 0 1.8V-plus-1.sym
C 47000 41700 1 0 0 1.8v-digital-1.sym
T 41100 47300 6 20 1 0 0 0 2
Sheet 4
Power
C 47500 47300 1 90 0 fuse-2.sym
{
T 46950 47500 5 10 0 0 90 0 1
device=FUSE
T 47200 47900 5 10 1 1 180 0 1
refdes=FB41
T 46750 47500 5 10 0 0 90 0 1
symversion=0.1
}
C 47200 48200 1 0 0 1.2V-plus-1.sym
N 45500 47100 45500 47200 4
C 43600 40800 1 0 0 gnd-1.sym
C 43500 46600 1 90 0 capacitor.sym
{
T 42800 46800 5 10 0 0 90 0 1
device=CAPACITOR
T 43200 46700 5 10 1 1 180 0 1
refdes=C402
T 42600 46800 5 10 0 0 90 0 1
symversion=0.1
T 43500 46600 5 10 0 0 0 0 1
footprint=1206
T 42700 46800 5 10 1 1 0 0 1
value=10u
}
C 42300 45400 1 90 0 fuse-2.sym
{
T 41750 45600 5 10 0 0 90 0 1
device=FUSE
T 42500 45600 5 10 1 1 90 0 1
refdes=FB44
T 41550 45600 5 10 0 0 90 0 1
symversion=0.1
}
N 42200 45400 42200 44100 4
N 42200 46300 42200 47100 4
N 42200 46300 43900 46300 4
N 42700 46300 42700 45500 4
N 42700 45500 43100 45500 4
N 42800 45000 42200 45000 4
C 46800 46600 1 90 0 capacitor.sym
{
T 46100 46800 5 10 0 0 90 0 1
device=CAPACITOR
T 46500 46300 5 10 1 1 90 0 1
refdes=C401
T 45900 46800 5 10 0 0 90 0 1
symversion=0.1
T 46200 46800 5 10 0 1 0 0 1
footprint=0805
T 46800 46400 5 10 1 1 90 0 1
value=10u
}
N 46600 46600 46600 46200 4
N 44000 46000 44000 45500 4
C 45800 43100 1 0 0 jumper.sym
{
T 46000 43400 5 10 1 1 0 0 1
refdes=J43
T 46100 43200 5 10 0 1 0 0 1
footprint=JUMPER2
}
C 45500 41600 1 0 0 jumper.sym
{
T 45700 41900 5 10 1 1 0 0 1
refdes=J44
T 45800 41700 5 10 0 1 0 0 1
footprint=JUMPER2
}
C 46600 47200 1 0 0 jumper.sym
{
T 46800 47500 5 10 1 1 0 0 1
refdes=J42
T 47000 47300 5 10 0 1 0 0 1
footprint=JUMPER2
}
N 46600 47100 46600 47300 4
