
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

extern int asm_printf(const char *fmt, ...);
extern size_t asm_strlen(const char *s);

int
main(int argc, char *argv[])
{
    int val;

    for (int i = 1; i < argc; i++) {
        val = atoi(argv[i]);
        asm_printf("%3d: '%s', len = %d, val = %d(d) 0x%04x(h)  0%o(o)\n",
            i, argv[i],
            asm_strlen(argv[i]),
            val, val, val);
    } /* end for */

    exit(EXIT_SUCCESS);
} /* end of main */

