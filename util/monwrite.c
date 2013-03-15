// Format a file for the monitor.
#include "lib/util.h"

#include <err.h>
#include <stdio.h>
#include <stdlib.h>

static size_t write_block(const unsigned char * data,
                          size_t length, unsigned address)
{
    if (length > 16)
        length = 16;
    printf("W %08x", address);
    for (unsigned i = 0; i < length; ++i)
        printf(" %02x", data[i]);
    printf("\n");
    return length;
}


static void write_blocks(const unsigned char * data,
                         unsigned length, unsigned address)
{
    for (unsigned offset = 0; offset < length;
         offset += write_block(
             data + offset, length - offset, address + offset));
}


int main(int argc, char * argv[])
{
    if (argc != 3)
        errx(1, "Usage: <file> <base>\n");

    char * tail;
    unsigned address = strtoul(argv[2], &tail, 16);
    if (*tail)
        errx(1, "Usage: <file> <base>\n");

    size_t offset = 0;
    size_t size = 0;
    unsigned char * data = NULL;
    slurp_path(argv[1], &data, &offset, &size);
    if (offset > 16) {
        write_blocks(data + 16, offset - 16, address + 16);
        write_blocks(data, 16, address);
    }
    else
        write_blocks(data, offset, address);

    return 0;
}
