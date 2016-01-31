#include "algo_random.h"
#include "algo.h"

//Systick
extern uint32_t ticks;

//Random
static uint32_t pages_in_ram[PAGES_PHYSICAL_NUM];
static uint64_t random_state = 0;

static uint32_t get_random_number();
extern int asm_printf(char *fmt, ...);

static uint32_t test[5];
/**
 * Initializes all data structures
 **/
void algo_random_init() {

    for(unsigned int i = 0; i < sizeof(pages_in_ram)/sizeof(pages_in_ram[0]); i++)
        pages_in_ram[i] = INVALID_ADDR;
        
    if(random_state == 0) {
        random_state = ((uint64_t)ticks << 32) | (ticks ^ 0x55555555);
    }
}

/**
 * Returns logical address of page to replace
 **/
uint32_t algo_random_get_address_of_page_to_replace() {
    uint32_t index = get_random_number() % PAGES_PHYSICAL_NUM;
    uint32_t addr_to_replace = pages_in_ram[index];
    pages_in_ram[index] = INVALID_ADDR;
    return addr_to_replace;
}

/**
 * Store new created page in fifo
 **/
void algo_random_new_page_in_ram(uint32_t addr) {
    for(unsigned int i = 0; i < sizeof(pages_in_ram)/sizeof(pages_in_ram[0]); i++) {
        if(pages_in_ram[i] == INVALID_ADDR) {
            pages_in_ram[i] = addr;
            return;
        }
    }
}

/**
 * Returns random 32 bit unsigned integer
 **/
uint32_t get_random_number() {
    random_state = (random_state << 1) | ((random_state ^ (random_state << 1)) >> 63);
    return (uint32_t)(random_state & 0xFFFFFFFF);
}
