// The sinrom has sines and derivatives from one quadrant stored in a 1024
// entry table.  Each entry stores 4 consecutive entires:
// The base entry (14 bits precision).
// The incremental deltas to each of the next 3 entries, this can be packed
// into 4 bits.

// We don't want too much precision.  We choose the scale so that the first few
// items go 1,3,5,7 etc.

#include <assert.h>
#include <math.h>
#include <stdio.h>
#include <stdlib.h>

static int dddeltas[16] = {
    0000, // 0 0 0
    0001, // 1 1 1
    0010, // 1 1 0
    0011, // 2 2 1
    0012, // 3 3 2, doesn't actually happen.
    0100, // 1 0 0
    0101, // 2 0 1
    0110, // 2 1 0
    0111, // 3 2 1
    0112, // 4 3 2
    0121, // 4 3 1
    0122, // 5 4 2
    //0210, // 3 1 0 Not possible...
    0211, // 4 2 1
    0212, // 5 3 2
    0221, // 5 3 1
    0222  // 6 4 2
};


static int ddd(int deltas)
{
    for (int i = 0; i != 16; ++i)
        if (deltas == dddeltas[i])
            return i;
    abort();
}


int main(void)
{
    double scale = 16384 / M_PI;
    double omega = M_PI / 16384;

    int used = 0;

    printf ("library IEEE;\n"
            "use IEEE.NUMERIC_STD.ALL;\n"
            "\n"
            "library work;\n"
            "use work.defs.all;\n"
            "\n"
            "package sincos is\n"
            "function sinoffset(sinent : unsigned18; lowbits : unsigned2) return unsigned3;\n"
            "constant sinrom : sinrom_t := (\n");

    for (int i = 0; i != 1024; ++i) {
        if (i & 3)
            printf (", ");
        else if (i)
            printf (",\n    ");
        else
            printf ("    ");

        double c0 = sin ((i * 8 + 1) * omega) * scale;
        double c1 = sin ((i * 8 + 3) * omega) * scale;
        double c2 = sin ((i * 8 + 5) * omega) * scale;
        double c3 = sin ((i * 8 + 7) * omega) * scale;
        int v0 = c0 + 0.5;
        int v1 = c1 + 0.5;
        int v2 = c2 + 0.5;
        int v3 = c3 + 0.5;

        assert (c0 - v0 <= 0.5);
        assert (c1 - v1 <= 0.5);
        assert (c2 - v2 <= 0.5);
        assert (c3 - v3 <= 0.5);
        assert (v0 - c0 <= 0.5);
        assert (v1 - c1 <= 0.5);
        assert (v2 - c2 <= 0.5);
        assert (v3 - c3 <= 0.5);
        assert (v0 >= 0);
        assert (v3 < 16384);

        int delta1 = v1 - v0;
        int delta2 = v2 - v1;
        int delta3 = v3 - v2;

        assert (delta1 >= 0);
        assert (delta2 >= 0);
        assert (delta3 >= 0);
        assert (delta1 <= 2);
        assert (delta2 <= 2);
        assert (delta3 <= 2);

        int index = ddd(delta3 * 0100 + delta2 * 0010 + delta1);
        used |= 1 << index;
        printf ("\"%i%i\"&x\"%04x\"",
                (index & 8) != 0, (index & 4) != 0, (index & 3) * 16384 + v0);
    }
    printf (");\n\n");
    printf ("-- Used bitmask: %0x\n", used);
    printf ("end sincos;\n"
            "\n"
            "package body sincos is\n"
            "function sinoffset(sinent : unsigned18; lowbits : unsigned2) return unsigned3 is\n"
           "begin\n"
           "    case lowbits & sinent(17 downto 14) is\n");

    for (int lowbits = 0; lowbits < 4; ++lowbits)
        for (int index = 0; index != 16; ++index) {
            int ddd = dddeltas[index];
            if (lowbits == 0 && ddd == 0)
                continue;
            int ccc = (ddd << 9) + (ddd << 6) + (ddd << 3);
            ccc &= 07770;
            int c = ccc >> (3 * lowbits);
            printf (
                "    when \"%i%i\" & x\"%x\" => return \"%i%i%i\"; -- %03o %04o\n",
                lowbits >> 1, lowbits & 1, index,
                (c & 4) != 0, (c & 2) != 0, c & 1, ddd, ccc);
        }

    printf ("    when others => return \"000\";\n"
            "    end case;\n"
            "end sinoffset;\n"
            "end sincos;\n");

    return 0;
}
