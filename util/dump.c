#include <getopt.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <fcntl.h>
#include <unistd.h>

#include "lib/usb.h"
#include "lib/util.h"
#include "lib/registers.h"

int main(int argc, char * argv[])
{
    size_t num_samples = 22;
    size_t bytes;
    const unsigned char * buffer = slurp_getopt(
        argc, argv, SLURP_OPTS "s:", NULL,
        XMIT_SAMPLE|XMIT_TURBO, &num_samples, &bytes);

    dump_path(optind < argc ? argv[optind] : NULL, buffer, bytes);

    exit(EXIT_SUCCESS);
}
