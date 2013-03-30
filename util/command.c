#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "lib/usb.h"
#include "lib/util.h"

// Buffer overruns?  What buffer overruns.  :-)
unsigned char raw[4096];

static void basic(const char * comm)
{
    usb_printf("%s\n", comm);

    unsigned got;
    unsigned lastnz;
    do {
        lastnz = 0;
        got = usb_read(raw, sizeof raw);
        for (unsigned i = 0; i != got; ++i)
            if (raw[i]) {
                lastnz = raw[i];
                putchar(raw[i]);
            }
    }
    while (got != 0 && lastnz != 10);
}


static bool havechar(int argc, char * argv[], char c)
{
    for (int i = 1; i != argc; ++i)
        if (strchr(argv[i], c) != NULL)
            return true;
    return false;
}


static void slashed(const char * p)
{
    for (; *p; p++)
        if (*p == '/')
            basic("\n");
        else
            usb_printf("%c", *p);
}


int main(int argc, char * argv[])
{
    usb_open();
    usb_flush();

    if (argc > 1) {
        if (havechar(argc, argv, '/') || !havechar(argc, argv, ' ')) {
            for (int i = 1; i < argc; ++i) {
                if (i != 1)
                    usb_printf(" ");
                slashed(argv[i]);
            }
            const char * last = argv[argc - 1];
            if (*last && last[strlen(last) - 1] != '/')
                basic("\n");
        }
        else {
            for (int i = 1; i < argc; ++i)
                basic(argv[i]);
        }
        return 0;
    }

    char * line = NULL;
    size_t max = 0;

    while (1) {
        ssize_t len = getline(&line, &max, stdin);
        if (len <= 0)
            return 0;
        if (line[len - 1] == '\n')
            line[len - 1] = 0;
        basic(line);
    }
}
