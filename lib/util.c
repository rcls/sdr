#include "lib/util.h"

#include <stdarg.h>
#include <stdio.h>
#include <stdlib.h>

void exprintf(const char * f, ...)
{
    va_list args;
    va_start(args, f);
    vfprintf(stderr, f, args);
    va_end(args);
    exit(EXIT_FAILURE);
}

void experror(const char * m)
{
    perror(m);
    exit(EXIT_FAILURE);
}

void * xmalloc(size_t size)
{
    void * res = malloc(size);
    if (!res)
        experror("malloc");
    return res;
}

void * xrealloc(void * ptr, size_t size)
{
    void * res = realloc(ptr, size);
    if (!res)
        experror("realloc");
    return res;
}