v 20100214 2
C 42800 46100 1 0 0 ads41b49-analog.sym
{
T 43200 46300 5 10 1 1 0 0 1
device=ADS41B49 Analog
T 43800 47300 5 10 1 1 0 0 1
footprint=QFN48
T 44000 47800 5 10 1 1 0 0 1
refdes=U1
}
C 42000 47300 1 0 0 resistor-1.sym
{
T 42300 47700 5 10 0 0 0 0 1
device=RESISTOR
T 42200 47600 5 10 1 1 0 0 1
refdes=R103
T 42000 47300 5 10 0 1 0 0 1
footprint=0603
}
C 42000 47000 1 0 0 resistor-1.sym
{
T 42300 47400 5 10 0 0 0 0 1
device=RESISTOR
T 42200 46800 5 10 1 1 0 0 1
refdes=R104
T 42000 47000 5 10 0 1 0 0 1
footprint=0603
}
C 39500 46500 1 0 0 transformer.sym
{
T 39700 46300 5 10 1 1 0 0 1
refdes=T11
T 39200 48100 5 10 0 0 0 0 1
device=TRANSFORMER
}
C 41500 47200 1 90 0 resistor-1.sym
{
T 41100 47500 5 10 0 0 90 0 1
device=RESISTOR
T 41200 47400 5 10 1 1 90 0 1
refdes=R101
T 41500 47200 5 10 0 1 0 0 1
footprint=0603
}
C 41500 46300 1 90 0 resistor-1.sym
{
T 41100 46600 5 10 0 0 90 0 1
device=RESISTOR
T 41200 46500 5 10 1 1 90 0 1
refdes=R102
T 41500 46300 5 10 0 1 0 0 1
footprint=0603
}
C 41000 46700 1 90 0 capacitor.sym
{
T 40300 46900 5 10 0 0 90 0 1
device=CAPACITOR
T 41000 47400 5 10 1 1 180 0 1
refdes=C101
T 40100 46900 5 10 0 0 90 0 1
symversion=0.1
T 41000 46700 5 10 0 1 0 0 1
footprint=0603
}
N 40400 47200 41400 47200 4
C 40700 46400 1 0 0 gnd-1.sym
N 40400 47800 40400 48100 4
N 40400 48100 42000 48100 4
N 42000 48100 42000 47400 4
N 40400 46600 40400 46300 4
N 40400 46300 42000 46300 4
N 42000 46300 42000 47100 4
N 45000 47000 45900 47000 4
C 38600 47400 1 0 0 coax-conn.sym
{
T 38600 48100 5 10 1 1 0 0 1
refdes=CONN11
T 38900 47400 5 10 1 1 0 0 1
footprint=SMA
}
N 39100 47800 39500 47800 4
N 38800 47400 38800 46600 4
N 38800 46600 39500 46600 4
C 40700 48900 1 0 0 ads41b49-power.sym
{
T 41100 50100 5 10 1 1 0 0 1
device=ADS41B49 Power
T 42700 50100 5 10 1 1 0 0 1
footprint=QFN48
T 42700 50500 5 10 1 1 0 0 1
refdes=U1
}
N 41300 49000 41300 48800 4
N 41300 48800 44200 48800 4
N 44200 48800 44200 49000 4
N 43900 49000 43900 48800 4
N 43600 49000 43600 48800 4
N 43300 49000 43300 48800 4
N 43000 49000 43000 48800 4
N 42700 49000 42700 48800 4
N 42100 49000 42100 48800 4
N 41600 49000 41600 48800 4
N 40800 51000 40600 51000 4
N 40600 51300 40600 48400 4
C 38500 50600 1 0 0 3.3V-plus-1.sym
C 38700 50500 1 0 0 fuse-2.sym
{
T 38900 51050 5 10 0 0 0 0 1
device=FUSE
T 38900 50300 5 10 1 1 0 0 1
refdes=FB11
T 38900 51250 5 10 0 0 0 0 1
symversion=0.1
}
N 39600 50600 40800 50600 4
C 39900 50100 1 90 0 capacitor.sym
{
T 39200 50300 5 10 0 0 90 0 1
device=CAPACITOR
T 40000 50800 5 10 1 1 180 0 1
refdes=C105
T 39000 50300 5 10 0 0 90 0 1
symversion=0.1
}
C 40400 50100 1 90 0 capacitor.sym
{
T 39700 50300 5 10 0 0 90 0 1
device=CAPACITOR
T 40500 50800 5 10 1 1 180 0 1
refdes=C106
T 39500 50300 5 10 0 0 90 0 1
symversion=0.1
}
N 39700 50100 40200 50100 4
C 39800 49800 1 0 0 gnd-1.sym
C 42000 48500 1 0 0 gnd-1.sym
N 40600 51300 40800 51300 4
C 46200 50600 1 0 0 1.8V-plus-1.sym
C 46500 49700 1 90 0 fuse-2.sym
{
T 45950 49900 5 10 0 0 90 0 1
device=FUSE
T 46700 49900 5 10 1 1 90 0 1
refdes=FB13
T 45750 49900 5 10 0 0 90 0 1
symversion=0.1
}
C 45600 49200 1 90 0 capacitor.sym
{
T 44900 49400 5 10 0 0 90 0 1
device=CAPACITOR
T 45600 49900 5 10 1 1 180 0 1
refdes=C108
T 44700 49400 5 10 0 0 90 0 1
symversion=0.1
}
N 44900 49200 47900 49200 4
C 46300 48900 1 0 0 gnd-1.sym
C 45100 49200 1 90 0 capacitor.sym
{
T 44400 49400 5 10 0 0 90 0 1
device=CAPACITOR
T 45100 49100 5 10 1 1 180 0 1
refdes=C107
T 44200 49400 5 10 0 0 90 0 1
symversion=0.1
}
C 46100 49200 1 90 0 capacitor.sym
{
T 45400 49400 5 10 0 0 90 0 1
device=CAPACITOR
T 46100 49100 5 10 1 1 180 0 1
refdes=C109
T 45200 49400 5 10 0 0 90 0 1
symversion=0.1
}
C 46600 49200 1 90 0 capacitor.sym
{
T 45900 49400 5 10 0 0 90 0 1
device=CAPACITOR
T 46300 49900 5 10 1 1 180 0 1
refdes=C110
T 45700 49400 5 10 0 0 90 0 1
symversion=0.1
}
C 47100 49200 1 90 0 capacitor.sym
{
T 46400 49400 5 10 0 0 90 0 1
device=CAPACITOR
T 47100 49100 5 10 1 1 180 0 1
refdes=C111
T 46200 49400 5 10 0 0 90 0 1
symversion=0.1
}
C 47600 49200 1 90 0 capacitor.sym
{
T 46900 49400 5 10 0 0 90 0 1
device=CAPACITOR
T 47600 49900 5 10 1 1 180 0 1
refdes=C112
T 46700 49400 5 10 0 0 90 0 1
symversion=0.1
}
C 48100 49200 1 90 0 capacitor.sym
{
T 47400 49400 5 10 0 0 90 0 1
device=CAPACITOR
T 48000 49100 5 10 1 1 180 0 1
refdes=C113
T 47200 49400 5 10 0 0 90 0 1
symversion=0.1
}
N 44700 50000 44900 50000 4
N 44900 49700 44900 51500 4
N 44900 51500 44700 51500 4
N 44700 51200 44900 51200 4
N 44700 50900 44900 50900 4
N 44700 50600 44900 50600 4
N 44700 50300 44900 50300 4
N 44900 49700 47900 49700 4
C 38400 49100 1 0 0 fuse-2.sym
{
T 38600 49650 5 10 0 0 0 0 1
device=FUSE
T 38700 49400 5 10 1 1 0 0 1
refdes=FB12
T 38600 49850 5 10 0 0 0 0 1
symversion=0.1
}
C 40000 48700 1 90 0 capacitor.sym
{
T 39300 48900 5 10 0 0 90 0 1
device=CAPACITOR
T 40000 49400 5 10 1 1 180 0 1
refdes=C103
T 39100 48900 5 10 0 0 90 0 1
symversion=0.1
}
N 39300 48700 40300 48700 4
C 39700 48400 1 0 0 gnd-1.sym
C 39500 48700 1 90 0 capacitor.sym
{
T 38800 48900 5 10 0 0 90 0 1
device=CAPACITOR
T 39200 48800 5 10 1 1 180 0 1
refdes=C102
T 38600 48900 5 10 0 0 90 0 1
symversion=0.1
}
C 40500 48700 1 90 0 capacitor.sym
{
T 39800 48900 5 10 0 0 90 0 1
device=CAPACITOR
T 40500 48600 5 10 1 1 180 0 1
refdes=C104
T 39600 48900 5 10 0 0 90 0 1
symversion=0.1
}
N 39300 49200 40600 49200 4
C 38200 49200 1 0 0 1.8v-digital-1.sym
N 40600 48400 45300 48400 4
N 45300 48400 45300 47000 4
T 45400 48100 6 20 1 0 0 0 2
Sheet 1 - Analog
Input to DAC
C 45000 46600 1 0 0 resistor-1.sym
{
T 45300 47000 5 10 0 0 0 0 1
device=RESISTOR
T 45200 46400 5 10 1 1 0 0 1
refdes=R199
}
N 45900 47000 45900 46700 4
