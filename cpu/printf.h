#ifndef PRINTF_H_
#define PRINTF_H_

void txword(unsigned val);
void putchar(int byte);
void puts(const char * s);
void printf(const char * __restrict__ format, ...)
    __attribute__ ((format (printf, 1, 2)));

#define debugf !debug_flag ? (void)0 : printf
#define verbose !verbose_flag ? (void)0 : printf

#endif
