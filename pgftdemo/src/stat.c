
#include "stat.h"

uint32_t stat_number_pgft_read = 0;
uint32_t stat_number_pgft_write = 0;
uint32_t stat_number_swapped = 0;
uint32_t stat_number_unswapped = 0;

extern int asm_printf(char *fmt, ...);

extern void stat_print() {
    asm_printf("Statistics:\r\n");
    asm_printf("Read Page Faults:\t%d\r\n", stat_number_pgft_read);
    asm_printf("Write Page Faults:\t%d\r\n", stat_number_pgft_write);
    asm_printf("Pages Swapped:\t\t%d\r\n", stat_number_swapped);
    asm_printf("Pages Unswapped:\t%d\r\n", stat_number_unswapped);
}
