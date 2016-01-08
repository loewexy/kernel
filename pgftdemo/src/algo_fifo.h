#ifndef _ALGO_FIFO_H
#define _ALGO_FIFO_H  

#include "types.h"

extern uint32_t algo_fifo_get_address_of_page_to_replace();

extern void algo_fifo_new_page_in_ram(uint32_t addr);

#endif
