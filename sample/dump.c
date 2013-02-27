#include <getopt.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/mman.h>
#include <fcntl.h>
#include <unistd.h>

#include "lib/usb.h"
#include "lib/util.h"
#include "lib/registers.h"

static const char * outpath;

static int freq = -1;
static int gain = 0;
static int source = XMIT_SAMPLE|XMIT_TURBO;

static void parse_opts(int argc, char * argv[])
{
    while (1)
        switch (getopt(argc, argv, "o:f:g:s:")) {
        case 'o':
            outpath = optarg;
            break;
        case 'f':
            freq = strtol(optarg, NULL, 0);
            break;
        case 'g':
            gain = strtol(optarg, NULL, 0);
            break;
        case 's':
            source = strtol(optarg, NULL, 0);
            break;
        case -1:
            return;
        default:
            errx(1, "Bad option.\n");
        }
}


int main(int argc, char * argv[])
{
    parse_opts(argc, argv);

    size_t bufsize = 1;
    for (int i = optind; i < argc; ++i)
        bufsize *= strtoul(argv[i], NULL, 0);
    if (optind >= argc)
        bufsize = 1 << 24;

    bufsize += USB_SLOP;

    mlockall(MCL_CURRENT | MCL_FUTURE);

    unsigned char * buffer = usb_slurp_channel(
        NULL, bufsize, source, freq, gain);

    dump_path(outpath, buffer, bufsize);

    exit(EXIT_SUCCESS);
}
