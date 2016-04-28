#ifndef _ALGO_CLOCK_H
#define _ALGO_CLOCK_H  

#include "types.h"

extern void algo_clock_init();

extern uint32_t algo_clock_get_address_of_page_to_replace();

extern void algo_clock_new_page_in_ram(uint32_t addr);

#endif
