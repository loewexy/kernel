#include "pgftdemo.h"
#include "stat.h"

//Include paging algorithms
#include "algo_fifo.h"

extern int asm_printf(char *fmt, ...);


//Create Page Tables for program and stack
uint32_t page_table_program[PTE_NUM]   __attribute__((aligned(PAGE_SIZE)));
uint32_t page_table_stack[PTE_NUM]     __attribute__((aligned(PAGE_SIZE)));

//Indices for pages in physical memory/storage
uint32_t physical_pages_index[PAGES_PHYSICAL_NUM];
uint32_t storage_pages_index[PAGES_SWAPPED_NUM];

//Structure for returning from pfhandler()
static pg_struct_t pg_struct;

//Memory functions
uint32_t get_page_frame(uint32_t virt_addr);
void free_all_pages();
void clear_all_accessed_bits();
void copy_page(uint32_t, uint32_t);
void clear_page(uint32_t);

//Index functions
uint32_t index_memory_add(uint32_t addr);
void index_memory_remove(uint32_t addr);
uint32_t index_memory_is_present(uint32_t addr);

uint32_t index_storage_add(uint32_t addr);
void index_storage_remove(uint32_t addr);
uint32_t index_storage_get_physical_address(uint32_t addr);

//Disk functions
uint32_t swap(uint32_t virtAddr);

//Functions of external paging algorithm
uint32_t (*algo_get_address_of_page_to_replace)();
void (*algo_new_page_in_ram)(uint32_t addr);


//Functions of paging algorithm
uint32_t get_address_of_page_to_replace();

//Init functions
void init_user_pages();

/**
 * pfhandler() is called by the kernel every time a page fault occurs.
 * It ist responsible to find a suitable page to replace, execute the
 * replacement and returning the new page and other information to the
 * kernel. 
 **/
pg_struct_t *
pfhandler(uint32_t ft_addr, uint32_t error_code)
{
    int pde = PDE(ft_addr);
    int pte = PTE(ft_addr);

    //TODO: fix me!
    if(error_code & 0x00000002) {
        stat_number_pgft_write++;
    } else {
        stat_number_pgft_read++;
    }

    pg_struct.pde = pde;
    pg_struct.pte = pte;
    pg_struct.off = ft_addr & PAGE_OFFSET_MASK;
    pg_struct.ft_addr = ft_addr;
    pg_struct.vic_addr = INVALID_ADDR;
    pg_struct.sec_addr = INVALID_ADDR;

    //Get address of page directory with kernel call
    uint32_t *page_directory = get_page_dir_addr();
    
    //If corresponding page table exists
    if ((page_directory[pde] & PAGE_IS_PRESENT) == PAGE_IS_PRESENT) {

        //Get address of page table out of page directory
        uint32_t *page_table;
        page_table = LOGADDR(page_directory[pde] & PAGE_ADDR_MASK);

        //If page is not present in page table
        if ((page_table[pte] & PAGE_IS_PRESENT) != PAGE_IS_PRESENT) {
            
            //Get address of an empty page to be used for the new page
            uint32_t memory_address = get_page_frame(ft_addr);
            memory_address &= PAGE_ADDR_MASK;

            //Set present,rw and user bit in preparation for usage as pte
            memory_address = memory_address | PAGE_IS_PRESENT | PAGE_IS_RW | PAGE_IS_USER;

            //If page was existing but swaped, set swaped bit again
            if ((page_table[pte] & PAGE_IS_SWAPPED) == PAGE_IS_SWAPPED) {
                memory_address |= PAGE_IS_SWAPPED;
            }

            //Store the new entry in page table
            page_table[pte] = memory_address;

            //If swapped bit is set, load page from swap to memory
            if ((page_table[pte] & PAGE_IS_SWAPPED) == PAGE_IS_SWAPPED) {
                stat_number_unswapped++;
                
                uint32_t storage_address = index_storage_get_physical_address(ft_addr & PAGE_ADDR_MASK);
                copy_page(storage_address, ft_addr & PAGE_ADDR_MASK);
                //Remove Dirty Bit, because this page wasn't changed
                page_table[pte] &= (~PAGE_IS_DIRTY);
                invalidate_addr(ft_addr & PAGE_ADDR_MASK);
            }
            
            //Add virtual address to fifo
            (*algo_new_page_in_ram)(ft_addr & PAGE_ADDR_MASK);

            pg_struct.ph_addr = memory_address & PAGE_ADDR_MASK;
            pg_struct.flags = memory_address & PAGE_FLAGS_MASK;

        } 
        //Page is present in page table
        //TODO: Determine if this is possible
        else {
            //There is no Page Fault
            pg_struct.flags = page_table[pte] & PAGE_FLAGS_MASK;
            pg_struct.ph_addr = page_table[pte] & PAGE_ADDR_MASK;
        }

    }
    //Page table is not existent.
    else {
        //Segmentation Fault. Page Table is not present.
        pg_struct.ph_addr = INVALID_ADDR;
        pg_struct.flags = INVALID_FLAGS;
    }
    
    return &pg_struct;
    
} //END OF PFHANDLER

/**
 * Selects which algorithm to use for page replacement.
 * 
 * 0 - FIFO
 */
void select_paging_algorithm(uint32_t algo) {
    switch(algo) {
        case 0: //FIFO
            algo_get_address_of_page_to_replace = &algo_fifo_get_address_of_page_to_replace;
            algo_new_page_in_ram = &algo_fifo_new_page_in_ram;
            break;
        default:
            asm_printf("Illegal algorithm!\r\n");
            break;
    }
    
    free_all_pages();
}


//==============================================================================
//START OF MEMORY FUNCTIONS
//==============================================================================

/**
 * Returns physical memory address of new page
 */
uint32_t
get_page_frame(uint32_t virt_addr) {
    uint32_t memory_address;
    
    //Try to get a free memory page in physical memory
    memory_address = index_memory_add(virt_addr);

    //If obtaining free page failed
    if (memory_address == INVALID_ADDR) {   
        //There is no page left
        //get virtual address of page to replace
        uint32_t virt_address = get_address_of_page_to_replace();
        
        //set victim as address of page to replace
        pg_struct.vic_addr = virt_address;
        
        //swap page, get physical address of page to use
        swap(virt_address);
        
        memory_address = index_memory_add(virt_addr);
        
        if(memory_address == INVALID_ADDR) {
            asm_printf("Swap should have made one page free, but failed to do so: get_page_frame()");
        }
    }
    
    //Clear new page to avoid old data in new page
    clear_page(memory_address);
    
    return memory_address;
} // end of get_page_frame

/**
 * Clears all present pages and invalidates all ptes for each non-kernel
 * pde. Also deletes all pages from swap.
 **/
void
free_all_pages() {
    
    uint32_t *page_directory = get_page_dir_addr();
    
    for(int i = FIRST_PDE_INDEX; i < PDE_NUM; i++) {
        
        if((page_directory[i] & PAGE_IS_PRESENT) == PAGE_IS_PRESENT) {
            uint32_t *page_table = LOGADDR(page_directory[i] & PAGE_ADDR_MASK);
            
            for(int j = FIRST_PTE_INDEX; j < PTE_NUM; j++) {
                
                if((page_table[j] & PAGE_IS_PRESENT) == PAGE_IS_PRESENT) {
                    invalidate_addr(JOIN_ADDR(i,j));
                }
                page_table[j] = 0x00000000;
            }
        }        
    }
    
    //set physical memory bitfield to blank
    for (uint32_t i = 0; i < PAGES_PHYSICAL_NUM; i++) {
        physical_pages_index[i] = INVALID_ADDR;
    }

    for (uint32_t i = 0; i < PAGES_SWAPPED_NUM; i++) {
        storage_pages_index[i] = INVALID_ADDR;
    }
    
    asm_printf("Freed all pages\r\n");
    
} // end of free_all_pages

/**
 * Resets accessed bits for all ptes in page_table_program and
 * page_table_stack
 **/
void
clear_all_accessed_bits()
{
    uint32_t *page_directory = get_page_dir_addr();
    
    for(int i = FIRST_PDE_INDEX; i < PDE_NUM; i++) {
        
        if((page_directory[i] & PAGE_IS_PRESENT) == PAGE_IS_PRESENT) {
            uint32_t *page_table = LOGADDR(page_directory[i] & PAGE_ADDR_MASK);
            
            for(int j = FIRST_PTE_INDEX; j < PTE_NUM; j++) {
                page_table[j] &= ~PAGE_IS_ACCESSED;
                
                if((page_table[j] & PAGE_IS_PRESENT) == PAGE_IS_PRESENT) {
                    invalidate_addr(JOIN_ADDR(i,j));
                }
            }
        }        
    }
} // end of clear_all_accessed_bits

/**
 * Copy a page from src to dst.
 **/
void
copy_page(uint32_t src_address, uint32_t dst_address) {
    uint32_t *src = LOGADDR(src_address & PAGE_ADDR_MASK);
    uint32_t *dst = LOGADDR(dst_address & PAGE_ADDR_MASK);
    for (int i = 0; i < (PAGE_SIZE / 4); i++) {
        *(dst++) = *(src++);
    }
} // end of copy_page

/**
 * Clear a page (set everything to zero)
 **/
void clear_page(uint32_t address) {
    uint32_t *addr = LOGADDR(address & PAGE_ADDR_MASK);
    for (int i = 0; i < (PAGE_SIZE / 4); i++) {
        *(addr++) = 0x00000000;
    }
} // end of clear_page

//==============================================================================
//START OF INDEX FUNCTIONS
//==============================================================================

/**
 * Add virtual address of page to first free index field, return physical
 * memory address.
 **/
uint32_t index_memory_add(uint32_t addr) {
    addr &= PAGE_ADDR_MASK;
    for(int i = 0; i < PAGES_PHYSICAL_NUM; i++) {
        if(physical_pages_index[i] == INVALID_ADDR) {
            physical_pages_index[i] = addr;
            return (PAGES_PHYSICAL_START + i * PAGE_SIZE);
        }
    }
    
    return INVALID_ADDR;
}

/**
 * Remove virtual address of page from index field.
 **/
void index_memory_remove(uint32_t addr) {
    addr &= PAGE_ADDR_MASK;
    for(int i = 0; i < PAGES_PHYSICAL_NUM; i++) {
        if(physical_pages_index[i] == addr) {
            physical_pages_index[i] = INVALID_ADDR;
            return;
        }
    }
}

/**
 * Test if virtual address is present in index.
 * Returns 1 if present, 0 otherwise
 **/
uint32_t index_memory_is_present(uint32_t addr) {
    addr &= PAGE_ADDR_MASK;
    for(int i = 0; i < PAGES_PHYSICAL_NUM; i++) {
        if(physical_pages_index[i] == addr) {
            return 1;
        }
    }
    
    return 0;
}


/**
 * Add virtual address of page to first free index field and return
 * physical address in swap.
 **/
uint32_t index_storage_add(uint32_t addr) {
    addr &= PAGE_ADDR_MASK;
    for(int i = 0; i < PAGES_SWAPPED_NUM; i++) {
        if(storage_pages_index[i] == INVALID_ADDR) {
            storage_pages_index[i] = addr;
            return (PAGES_SWAPPED_START + i * PAGE_SIZE);
        }
    }
    
    return INVALID_ADDR;
}

/**
 * Remove virtual address of page from index field.
 **/
void index_storage_remove(uint32_t addr) {
    addr &= PAGE_ADDR_MASK;
    for(int i = 0; i < PAGES_SWAPPED_NUM; i++) {
        if(storage_pages_index[i] == addr) {
            storage_pages_index[i] = INVALID_ADDR;
            return;
        }
    }
}

/**
 * Return physical address of page with virtual address addr
 * in storage.
 **/
uint32_t index_storage_get_physical_address(uint32_t addr)  {
    addr &= PAGE_ADDR_MASK;
    for(int i = 0; i < PAGES_SWAPPED_NUM; i++) {
        if(storage_pages_index[i] == addr) {
            return (PAGES_SWAPPED_START + i * PAGE_SIZE);
        }
    }
    
    return INVALID_ADDR;
}

//==============================================================================
//START OF DISK FUNCTIONS
//==============================================================================

uint32_t swap(uint32_t virt_address)
{
    //Compute pde and pte for virtAddr
    uint32_t pde = PDE(virt_address);
    uint32_t pte = PTE(virt_address);
    
    //Get address of page directory using kernel call
    uint32_t *page_directory = get_page_dir_addr();

    //Create variable for place in storage
    uint32_t storage_address;

    //Invalidate address in TLB because page is going to be relocated to disk
    invalidate_addr(virt_address);
    
    //Get page table coresponding to virtAddr
    uint32_t * page_table = LOGADDR(page_directory[pde] & PAGE_ADDR_MASK);

    //Get physical memory address and flags of the page to swap
    uint32_t memory_address = page_table[pte] & PAGE_ADDR_MASK;
    uint32_t flags = page_table[pte] & PAGE_FLAGS_MASK;

    // Check if page was modified, only save it then
    if ((flags & PAGE_IS_DIRTY) == PAGE_IS_DIRTY) {
        
        stat_number_swapped++;
        
        // Check if page to swap is on disk
        if ((flags & PAGE_IS_SWAPPED) == PAGE_IS_SWAPPED) {
        
            // Get address of page copy on disk
            storage_address = index_storage_get_physical_address(virt_address);
        
            // Overwrite copy on disk with modified page 
            copy_page(virt_address, storage_address);
            // TODO: THIS IS UGLY, should be fixed
            pg_struct.sec_addr = storage_address;
        }
        // Page is not on disk
        else {
            //Get free page on storage
            uint32_t storage_address = index_storage_add(virt_address);
            
            // Write page to disk
            copy_page(virt_address, storage_address);
            
            // TODO: THIS IS UGLY, should be fixed
            pg_struct.sec_addr = storage_address;
        }
        
        //set swapped bit
        page_table[pte] |= PAGE_IS_SWAPPED;
        //remove dirty bit
        page_table[pte] &= (~PAGE_IS_DIRTY);
    }
    
    // Reset present bit
    index_memory_remove(virt_address);

    page_table[pte] &= (~PAGE_IS_PRESENT);

    return memory_address;
} // end of swap


//==============================================================================
//START OF REPLACEMENT ALGORITHMS//
//==============================================================================

/**
 * Returns logical address of page to replace
 **/
uint32_t get_address_of_page_to_replace() {
    return (*algo_get_address_of_page_to_replace)();
} //end of get_address_of_page_to_replace


//==============================================================================
// START OF PAGING INITIALISATION
//==============================================================================

/**
 * Initialise the user pages. Also initialize the index of memory pages and disk pages.
 **/
void
init_user_pages()
{
    uint32_t *page_directory = get_page_dir_addr();
    asm_printf("Page Directory is at linear address 0x%08x\r\n", LINADDR(page_directory));

    //set physical memory bitfield to blank
    for (uint32_t i = 0; i < PAGES_PHYSICAL_NUM; i++) {
        physical_pages_index[i] = INVALID_ADDR;
    }

    for (uint32_t i = 0; i < PAGES_SWAPPED_NUM; i++) {
        storage_pages_index[i] = INVALID_ADDR;
    }

    page_directory[PDE_PROGRAMM_PT] = LINADDR(page_table_program) | PAGE_IS_PRESENT | PAGE_IS_RW | PAGE_IS_USER;
    page_directory[PDE_STACK_PT] = LINADDR(page_table_stack) | PAGE_IS_PRESENT | PAGE_IS_RW | PAGE_IS_USER;
    
    //Initialize with paging algorithm FIFO
    algo_get_address_of_page_to_replace = &algo_fifo_get_address_of_page_to_replace;
    algo_new_page_in_ram = &algo_fifo_new_page_in_ram;
} //end of init_user_pages

