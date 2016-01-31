#include "algo_fifo.h"
#include "algo.h"

//FIFO
static uint32_t fifo_buffer[PAGES_PHYSICAL_NUM];
static uint32_t fifo_write_position = 0;
static uint32_t fifo_read_position = 0;
static uint32_t fifo_number_elements = 0;

static void fifo_enqueue(uint32_t addr);
static uint32_t fifo_dequeue();

/**
 * Initializes all data structures
 **/
void algo_fifo_init() {
    for(unsigned int i = 0; i < sizeof(fifo_buffer)/sizeof(fifo_buffer[0]); i++)
        fifo_buffer[i] = 0;
        
    fifo_write_position = 0;
    fifo_read_position = 0;
    fifo_number_elements = 0;
}

/**
 * Returns logical address of page to replace
 **/
uint32_t algo_fifo_get_address_of_page_to_replace() {
    return fifo_dequeue();
}

/**
 * Store new created page in fifo
 **/
void algo_fifo_new_page_in_ram(uint32_t addr) {
    fifo_enqueue(addr);
}

/**
 * Add logical address of page to fifo
 **/
static void fifo_enqueue(uint32_t addr) {
    //If fifo is full return, this should never happen
    if(fifo_number_elements >= PAGES_PHYSICAL_NUM) return;
    
    //Remove flags
    addr &= PAGE_ADDR_MASK;
    
    fifo_buffer[fifo_write_position] = addr;
    fifo_write_position++;
    fifo_write_position %= PAGES_PHYSICAL_NUM;
    fifo_number_elements++;
}

/**
 * Get address of page from fifo
 **/
static uint32_t fifo_dequeue() {
    //If fifo is empty return invalid address, this should never happen
    if(fifo_number_elements == 0) return INVALID_ADDR;
    
    uint32_t return_value = fifo_buffer[fifo_read_position];
    fifo_read_position++;
    fifo_read_position %= PAGES_PHYSICAL_NUM;
    fifo_number_elements--;
    
    return return_value;
}
