
#include "command.h"
#include "printf.h"
#include "registers.h"
#include "../lib/registers.h"

const void * const vtable[] __attribute__((section (".start"),
                                           externally_visible));


void command_poop(char * line)
{
    printf("pooped ya pants\n");
}

static const command_t commands[] = {
    { "poop", command_poop },
    { "wr", command_write },
    { NULL, NULL }
};

#define flash_vtable ((const void * const *) 0x800)


void run(void)
{
    while (1)
        command(commands, flash_vtable[38]);
}


static __attribute__((noreturn)) void start(void)
{
    printf("Welcome, extra\n");
    run();
}

static void dummy_int(void)
{
}


const void * const vtable[] = {
    (void*) 0x20002000, start,
    [2 ... 37] = dummy_int
};
