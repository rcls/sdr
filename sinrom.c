// The sinrom has sines and derivatives from one quadrant on 0..1023.
// We store the sine and an approximation to the derivative; this enables
// us to get 2048 samples per quadrant, i.e., 0..2047.
// The index is the middle of the angle range.  So 0 is pi/8192 radians.
// 1 is 3pi/8192 radians, 2047 is 4095pi/8192 radians.
// We store the event numbered samples, and the differences to give the even
// numbered values.

// We don't want too much precision.  We choose the scale so that the first few
// items go 1,3,5,7 etc.

#include <assert.h>
#include <math.h>
#include <stdio.h>

int main() {
    double mult = 8192 / M_PI;
    for (int i = 0; i != 1024; ++i) {
        if (i & 3)
            printf (", ");
        else if (i)
            printf (",\n    ");
        else
            printf ("    ");

        double c = sin ((i * 4 + 1) * (M_PI / 8192)) * mult;
        double d = sin ((i * 4 + 3) * (M_PI / 8192)) * mult;
        int u = c + 0.5;
        int v = d + 0.5;
        assert (c - u < 0.5 && u - c < 0.5);
        assert (d - v < 0.5 && v - d < 0.5);
        assert (u <= v);
        assert (v <= u + 2);
        assert (0 <= u);
        assert (v < 4096);
        printf ("\"%i%i\"&x\"%x%03x\"",
                0, 0,
                v - u,
                u & 65535);
    }
    printf ("\n");
}
