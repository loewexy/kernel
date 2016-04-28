#include "algo_clock.h"
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
void algo_clock_init() {
    for(unsigned int i = 0; i < sizeof(fifo_buffer)/sizeof(fifo_buffer[0]); i++)
        fifo_buffer[i] = 0;
        
    fifo_write_position = 0;
    fifo_read_position = 0;
    fifo_number_elements = 0;
}

/**
 * Returns logical address of page to replace
 **/
uint32_t algo_clock_get_address_of_page_to_replace() {
    uint32_t *page_directory = get_page_dir_addr();
    
    uint32_t addr_to_replace = INVALID_ADDR;
    
    do {
        uint32_t virtual_address = fifo_dequeue();
        uint32_t* page_table_base = (uint32_t*)(LOGADDR(page_directory[PDE(virtual_address)] & PAGE_ADDR_MASK));
        uint32_t page_table_entry = page_table_base[PTE(virtual_address)];
        
        if((page_table_entry >> 5) & 0x00000001) {
            page_table_entry &= ~0x00000020;
            page_table_base[(virtual_address >> 12) & 0x000003ff] = page_table_entry;
            fifo_enqueue(virtual_address);
            invalidate_addr(virtual_address);
        } else {
            addr_to_replace = virtual_address;
        }
        
    } while(addr_to_replace == INVALID_ADDR);
    
    return addr_to_replace;
}

/**
 * Store new created page in fifo
 **/
void algo_clock_new_page_in_ram(uint32_t addr) {
    fifo_enqueue(addr & PAGE_ADDR_MASK);
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
