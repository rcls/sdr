// Simulate the pll.

#include <assert.h>
#include <math.h>
#include <stdio.h>

typedef long word_t;

static inline word_t sext36(word_t x)
{
    return (x << 28) >> 28;
}


static inline int sext18(int x)
{
    return (x << 14) >> 14;
}


typedef struct state_t {
    word_t offset;
    word_t offst2;
    word_t ampltd;
    word_t amplt2;
    word_t freq;
    word_t phase;
} state_t;


static void update(state_t * __restrict__ s, int sample)
{
    // Reduce the phase to 14 bits.
    int phase = (s->phase >> 22) & 0x3fff;
    int cosine = (16384 / M_PI) * cos((phase * 2 + 1) * (M_PI / 16384));
    int sine = (16384 / M_PI) * sin((phase * 2 + 1) * (M_PI / 16384));
    int product = cosine * sample;
    int produss = sine * sample;

    word_t new_offset = sext36(((s->offset << 5) + product - (s->offset >> 5)) >> 5);
    word_t new_ampltd = sext36(((s->ampltd << 5) + produss - (s->ampltd >> 5)) >> 5);
    word_t new_amplt2 = s->amplt2 + ((new_ampltd - s->amplt2) >> 10);
    word_t new_offst2 = s->offst2 + ((new_offset - s->offst2) >> 10);

    // FIXME - clamp and possibly scale new_freq.
    word_t new_freq = sext36(s->freq + ((new_offset + 524288) >> 20));

    word_t new_phase = sext36(s->phase + new_freq + (new_offset >> 7));

    s->offset = new_offset;
    s->offst2 = new_offst2;
    s->ampltd = new_ampltd;
    s->amplt2 = new_amplt2;
    s->freq = new_freq;
    s->phase = new_phase;
}


#define DELTA_E (2 * M_PI * 18000 / 312500)
//#define DELTA_19 = (2 * M_PI * 19000 / 312500)
#define DELTA_19 (2 * M_PI * 19050 / 312500)

int main(void)
{
    state_t s = { .offset = 0, .offst2 = 0,
                  .ampltd = 0, .amplt2 = 0, .phase = 0,
                  .freq = (1l << 36) * 190 / 3125 };

    for (int i = 1; i <= 312500; ++i) {
        int sample = 0.1 * (1<<18) * 75 / 312.5 * sin(-i * DELTA_19)
            +        0.9 * (1<<18) * 75 / 312.5 * cos(i * DELTA_E);
        assert(sample == sext18(sample));
        if (i % 100 == 0) {
            double pll_phase = s.phase * (1.0 / (1l << 36));
            double diff = pll_phase - (DELTA_19 / (2 * M_PI) * i + 0.5);
            printf("%6i %f %9f %10f %f\n",
                   i,
                   s.freq * (312500.0 / (1l << 36)),
                   diff - round(diff),
                   s.offst2 / 1048576.0,
                   s.amplt2 / 1048576.0);
        }
        update(&s, sample);
    }
    return 0;
}
