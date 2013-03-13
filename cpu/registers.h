#ifndef REGISTERS_H_
#define REGISTERS_H_

#include <stddef.h>

#define __memory_barrier() asm volatile ("" : : : "memory")
#define __interrupt_disable() asm volatile ("cpsid i\n" ::: "memory");
#define __interrupt_enable() asm volatile ("cpsie i\n" ::: "memory");
#define __interrupt_wait() asm volatile ("wfi\n");

#define __section(s) __attribute__ ((section (s)))
#define __aligned(s) __attribute__ ((aligned (s)))


typedef struct gpio_t {
    unsigned data[256];
    unsigned dir;
    unsigned is;
    unsigned ibe;
    unsigned iev;
    unsigned im;
    unsigned ris;
    unsigned mis;
    unsigned icr;
    unsigned afsel;

    unsigned dummy4[55];

    unsigned dr2r;
    unsigned dr4r;
    unsigned dr8r;
    unsigned odr;
    unsigned pur;
    unsigned pdr;
    unsigned slr;
    unsigned den;
} gpio_t;

_Static_assert(offsetof(gpio_t, dir) == 0x400, "dir offset");
_Static_assert(offsetof(gpio_t, dr2r) == 0x500, "dr2r offset");

#define PA ((volatile gpio_t *) 0x40004000)
#define PB ((volatile gpio_t *) 0x40005000)
#define PC ((volatile gpio_t *) 0x40006000)
#define PD ((volatile gpio_t *) 0x40007000)
#define PE ((volatile gpio_t *) 0x40024000)

typedef struct sc_t {
    unsigned did[2];
    unsigned dc[5];
    unsigned dummy20[5];
    unsigned pborctl;
    unsigned ldopctl;
    unsigned dummy38[2];
    unsigned srcr[3];
    unsigned dummy4c;
    unsigned ris;
    unsigned imc;
    unsigned misc;
    unsigned resc;
    unsigned rcc;
    unsigned pllcfg;
    unsigned dummy68[38];
    unsigned rcgc[4];
    unsigned scgc[4];
    unsigned dcgc[4];
    unsigned fmpre;
    unsigned fmppe;
    unsigned dummy138[2];
    unsigned usecrl;
    unsigned dslpclkcfg;
    unsigned dummy148[2];
    unsigned clkvclr;
    unsigned dummy154[3];
    unsigned ldoarst;
} sc_t;

_Static_assert(offsetof(sc_t, pborctl) == 0x30, "sc pborctl");
_Static_assert(offsetof(sc_t, ris) == 0x50, "sc ris");
_Static_assert(offsetof(sc_t, rcgc) == 0x100, "sc rcgc");
_Static_assert(sizeof(sc_t) == 0x164, "sc size");

#define SC ((volatile sc_t *) 0x400fe000)

typedef struct scb_t {
    unsigned cpuid;
    unsigned intctrl;
    unsigned vtable;
    unsigned apint;
    unsigned sysctrl;
    unsigned cfgctrl;
    unsigned sysprio[3];
    unsigned syshndctrl;
    unsigned faultstat;
    unsigned hfaultstat;
    unsigned dummy;
    unsigned mmaddr;
    unsigned faultaddr;
} scb_t;

#define SCB ((volatile scb_t *) 0xe000ed00)

typedef struct ssi_t {
    unsigned cr[2];
    unsigned dr;
    unsigned sr;
    unsigned cpsr;
    unsigned im;
    unsigned ris;
    unsigned mis;
    unsigned icr;
} ssi_t;

#define SSI ((volatile ssi_t *) 0x40008000)

typedef struct flashctrl_t {
    unsigned fma;
    unsigned fmd;
    unsigned fmc;
    unsigned fcris;
    unsigned fcim;
    unsigned fcmisc;
} flashctrl_t;

#define FLASHCTRL ((volatile flashctrl_t *) 0x400fd000)

#endif
