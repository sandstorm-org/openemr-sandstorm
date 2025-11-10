// geteuid/getegid utility
//
// Written 2021 by Troy J. Farrell <troy@entheossoft.com>
//
// To the extent possible under law, the author(s) have dedicated all copyright
// and related and neighboring rights to this software to the public domain
// worldwide. This software is distributed without any warranty.
//
// You should have received a copy of the CC0 Public Domain Dedication along
// with this software. If not, see
// <http://creativecommons.org/publicdomain/zero/1.0/>.

#include <libgen.h>
#include <unistd.h>
#include <stdio.h>
#include <string.h>
#include <sys/types.h>

int main(int argc, char *argv[]) {
    uint id;
    char *myname = basename(argv[0]);

    if (strncmp("geteuid", myname, 7) == 0) {
        id = (uint)geteuid();
    }
    else if (strncmp("getegid", myname, 7) == 0) {
        id = (uint)getegid();
    }
    else {
        fputs("This program expects to be named \"getegid\" or \"geteuid\".\n", stderr);
        return 1;
    }
    printf("%d\n", id);
    return 0;
}
