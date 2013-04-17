#ifndef COMMAND_H_
#define COMMAND_H_

typedef struct command_t {
    const char * name;
    void (* function)(char *);
} command_t;

void command_G(char * params);
void command_R(char * params);
void command_W(char * params);
void command_adc(char * params);
void command_bandpass(char * params);
void command_echo(char * params);
void command_flash(char * params);
void command_gain(char * params);
void command_nop(char * params);
void command_pll_report(char * params);
void command_read(char * params);
void command_reboot(char * params);
void command_tune(char * params);
void command_write(char * params);

void command(const command_t * c1, const command_t * c2);
__attribute__((noreturn)) void rerun(const char * m);

// The main program must provide this.
void run(void) __attribute__ ((noreturn));

#endif
