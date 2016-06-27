#include "algo_random.h"
#include "algo.h"

//Systick
extern uint32_t ticks;

//Random
static uint32_t pages_in_ram[PAGES_PHYSICAL_NUM];
static uint32_t random_index = 0;

#define RANDOM_ARRAY_SIZE 128

static const uint32_t random_array[RANDOM_ARRAY_SIZE] = {
    1, 0, 1, 3, 0, 0, 0, 0, 0, 2, 3, 1, 2, 0, 2, 0, 1, 0, 0, 0, 1, 3, 3, 0, 3, 0, 3, 1, 1, 2, 0, 2,
    1, 1, 3, 2, 3, 0, 2, 0, 2, 0, 1, 2, 0, 1, 2, 2, 0, 0, 2, 3, 1, 0, 0, 3, 0, 3, 0, 2, 2, 1, 0, 2,
    3, 0, 2, 2, 1, 3, 3, 1, 3, 0, 2, 3, 0, 3, 2, 0, 1, 2, 1, 2, 0, 3, 0, 0, 1, 0, 0, 2, 0, 0, 1, 1,
    1, 1, 0, 3, 3, 0, 3, 0, 1, 0, 3, 2, 1, 2, 2, 2, 0, 1, 2, 0, 3, 3, 1, 2, 0, 2, 0, 0, 1, 3, 3, 3
};

static uint32_t get_random_number();
extern int asm_printf(char *fmt, ...);

/**
 * Initializes all data structures
 **/
void algo_random_init() {

    for(unsigned int i = 0; i < sizeof(pages_in_ram)/sizeof(pages_in_ram[0]); i++)
        pages_in_ram[i] = INVALID_ADDR;

    if(random_index != 0) {
        random_index = 0;
    }
}

/**
 * Returns logical address of page to replace
 **/
uint32_t algo_random_get_address_of_page_to_replace() {
    uint32_t index = get_random_number();
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
    uint32_t random_number = random_array[random_index % RANDOM_ARRAY_SIZE];

    random_index++;
    return random_number;
}
