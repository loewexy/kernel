#ifndef _ALGO_RANDOM_H
#define _ALGO_RANDOM_H  

#include "types.h"

extern void algo_random_init();

extern uint32_t algo_random_get_address_of_page_to_replace();

extern void algo_random_new_page_in_ram(uint32_t addr);

#endif
