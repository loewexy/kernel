#include "pfhandler.h"


#ifdef __DHBW_KERNEL__
#include<stdarg.h>
#include "kprintf.h"
// Linear address of data segment, defined in ldscript
// use only in Kernel context with x86 segmentation
// being enabled
extern uint32_t LD_DATA_START;
extern uint32_t LD_IMAGE_START;
#else
#include<stdarg.h>
#include <stdio.h>
int kprintf(const char*, ...);
#endif
/*
 * Declaration of Page Directory and Page tables
 */
uint32_t page_directory[1024] __attribute__((aligned(0x1000)));
//Create Page Tables
uint32_t kernel_page_table[1024] __attribute__((aligned(0x1000)));
uint32_t programm_page_table[1024] __attribute__((aligned(0x1000)));
uint32_t stack_page_table[1024] __attribute__((aligned(0x1000)));

//Can be set down, but not higher than die maximum number of pages
uint32_t memoryPageCounter = PAGES_PHYSICAL_NUM;

//Page replace parameters
uint32_t replace_pde_offset = 0;
uint32_t replace_pte_offset = 512;


uint32_t dbg_ft_addr;

struct pageEntry {
    uint32_t pde;
    uint32_t pte;
    uint32_t memAddr;
};

struct pageEntry storageBitfield[PAGES_SWAPPED_NUM];
struct pageEntry physicalMemoryBitfield[PAGES_PHYSICAL_NUM];

static pg_struct_t pg_struct;


uint32_t setPresentBit(uint32_t, uint32_t, uint32_t);
uint32_t removePresentBit(uint32_t, uint32_t);
uint32_t isPresentBit(uint32_t, uint32_t);
uint32_t getClassOfPage(uint32_t);
uint32_t getAddressOfPageToReplace();
uint32_t isPresentBit(uint32_t, uint32_t);
uint32_t getPageFrame();
uint32_t swap(uint32_t virtAddr);
uint32_t getFreeMemoryAddress();
uint32_t getVirtAddrOfFrameOnDisk(uint32_t, uint32_t);
uint32_t getIndexInStorageBitfield(uint32_t, uint32_t);
void copyPage(uint32_t, uint32_t);
void clearPage(uint32_t);
void invalidate_addr(uint32_t);
void freeAllPages();

pg_struct_t *
pfhandler(uint32_t ft_addr) {

    int pde = PDE(ft_addr);
    int pte = PTE(ft_addr);

    dbg_ft_addr = ft_addr;

    pg_struct.pde = pde;
    pg_struct.pte = pte;
    pg_struct.off = ft_addr & PAGE_OFFSET_MASK;
    pg_struct.ft_addr = ft_addr;
    pg_struct.vic_addr = INVALID_ADDR;
    pg_struct.sec_addr = INVALID_ADDR;

    //If page table exists in page directory
    if ((page_directory[pde] & PAGE_IS_PRESENT) == PAGE_IS_PRESENT) {

        uint32_t *page_table;
#ifdef __DHBW_KERNEL__
        page_table = (uint32_t *) ((page_directory[pde] & PAGE_ADDR_MASK) - (uint32_t) & LD_DATA_START);
#else
        page_table = (uint32_t *) (page_directory[pde] & PAGE_ADDR_MASK);
#endif

        //If page is not present in page table
        if ((*(page_table + pte) & PAGE_IS_PRESENT) != PAGE_IS_PRESENT) {
            /* Left 20 bits are memory address
             * 
             */
            uint32_t memoryAddress = getPageFrame();
            memoryAddress &= PAGE_ADDR_MASK;


            //TODO: Save swap bit
            memoryAddress = memoryAddress | PAGE_IS_PRESENT | PAGE_IS_RW | PAGE_IS_USER;

            if ((*(page_table + pte) & PAGE_IS_SWAPPED) == PAGE_IS_SWAPPED) {
                memoryAddress |= PAGE_IS_SWAPPED;
            }

            *(page_table + pte) = memoryAddress;
            setPresentBit(pde, pte, (memoryAddress & PAGE_ADDR_MASK));

            //If present on storage bit is set, load page from storage in memory
            if ((*(page_table + pte) & PAGE_IS_SWAPPED) == PAGE_IS_SWAPPED) {
                uint32_t strVirtAddr = getVirtAddrOfFrameOnDisk(pde, pte);

                copyPage(strVirtAddr, ft_addr & PAGE_ADDR_MASK);
                //Remove Dirty Bit, because this page wasn't changed
                *(page_table + pte) &= (~PAGE_IS_DIRTY);
#ifdef __DHBW_KERNEL__
                invalidate_addr(ft_addr & PAGE_ADDR_MASK);
#endif
            }
            //Set flags on memory address

            pg_struct.ph_addr = memoryAddress & PAGE_ADDR_MASK;
            pg_struct.flags = *(page_table + pte) & PAGE_OFFSET_MASK;

        } else {
            //There is no Page Fault
            pg_struct.flags = *(page_table + pte) & PAGE_OFFSET_MASK;
            pg_struct.ph_addr = *(page_table + pte) & PAGE_ADDR_MASK;
        }

    } else {
        //Segmentation Fault. Page Table is not present.
        pg_struct.ph_addr = INVALID_ADDR;
        pg_struct.flags = INVALID_FLAGS;
    }
    return &pg_struct;
} //END OF PFHANDLER

//==============================================================================
//START OF MEMORY FUNCTIONS//
//==============================================================================

uint32_t
getPageFrame() {
    /*
     * Returns a memory address
     * left 20 bits contains memory address
     */

    //Maximum allowed pages in memory at actual time.
    uint32_t memoryAddress;
    memoryAddress = getFreeMemoryAddress();
    if (memoryAddress != INVALID_ADDR) {
        return memoryAddress;
    }
    //There is no page left
    //get virtual address of page to replace
    uint32_t virtAddr = getAddressOfPageToReplace();
    pg_struct.vic_addr = virtAddr;
    memoryAddress = swap(virtAddr);
    return memoryAddress;
} // end of getPageFrame

uint32_t
setPresentBit(uint32_t pde_offset, uint32_t pte_offset, uint32_t memAddr) {
    for (uint32_t i = 0; i < memoryPageCounter; i++) {
        if (physicalMemoryBitfield[i].pde == 0 && physicalMemoryBitfield[i].pte == 0) {
            physicalMemoryBitfield[i].pde = pde_offset;
            physicalMemoryBitfield[i].pte = pte_offset;
            physicalMemoryBitfield[i].memAddr = memAddr;
            return 1;
        }
    }
    return 0;
} // end of setPresentBit

uint32_t
removePresentBit(uint32_t pde_offset, uint32_t pte_offset) {
    for (uint32_t i = 0; i < PAGES_PHYSICAL_NUM; i++) {
        if (physicalMemoryBitfield[i].pde == pde_offset && physicalMemoryBitfield[i].pte == pte_offset) {
            physicalMemoryBitfield[i].pde = 0;
            physicalMemoryBitfield[i].pte = 0;
            physicalMemoryBitfield[i].memAddr = 0;
            return 1;
        }
    }
    return 0;
} // end of removePresentBit

uint32_t
isPresentBit(uint32_t pde_offset, uint32_t pte_offset) {
    for (uint32_t i = 0; i < memoryPageCounter; i++) {
        if (physicalMemoryBitfield[i].pde == pde_offset && physicalMemoryBitfield[i].pte == pte_offset) {
            return 1;
        }
    }
    return 0;
} // end of isPresentBit

uint32_t
getFreeMemoryAddress() {
    for (uint32_t i = 0; i < PAGES_PHYSICAL_NUM; i++) {
        if (physicalMemoryBitfield[i].pde == 0 && physicalMemoryBitfield[i].pte == 0) {
            return ((uint32_t) (PAGES_PHYSICAL_START + i * PAGE_SIZE));
        }
    }
    return INVALID_ADDR;
} // end of getFreeMemoryAddress

void
freeAllPages() {
    uint32_t pde;
    uint32_t pte;
    uint32_t virtAddr = 0;
    uint32_t *page_table;

    //For all present bits, do free page in Memory
    for (uint32_t i = 0; i < PAGES_PHYSICAL_NUM; i++) {
        pde = physicalMemoryBitfield[i].pde;
        pte = physicalMemoryBitfield[i].pte;
        if (isPresentBit(pde, pte)) {
            virtAddr = 0;
            virtAddr |= pde << PDE_SHIFT;
            virtAddr |= pte << PTE_SHIFT;

            if (virtAddr != 0x0) {
                clearPage(virtAddr);
#ifdef __DHBW_KERNEL__
                page_table = (uint32_t *) ((page_directory[pde] & PAGE_ADDR_MASK) - (uint32_t) & LD_DATA_START);
#else
                page_table = (uint32_t *) (page_directory[pde] & PAGE_ADDR_MASK);
#endif
                //Remove all flags
                page_table[pte] &= PAGE_ADDR_MASK;
#ifdef __DHBW_KERNEL__
                invalidate_addr(virtAddr);
#endif
                removePresentBit(pde, pte);
            }

        }
    }

    for (uint32_t i = 0; i < PAGES_SWAPPED_NUM; i++) {
        if (!(storageBitfield[i].pde == 0 && storageBitfield[i].pte == 0)) {
            uint32_t pde = storageBitfield[i].pde;
            uint32_t pte = storageBitfield[i].pte;
            uint32_t storageAddr = 0;
            storageAddr = getVirtAddrOfFrameOnDisk(pde, pte);
            clearPage(storageAddr);
        }
    }


} // end of freeAllPages

//==============================================================================
//END OF MEMORY FUNCTIONS//
//==============================================================================

uint32_t dbg_copy_src_addr;
uint32_t dbg_copy_dst_addr;

void copyPage(uint32_t src_address, uint32_t dst_address) {
    //unsusedPar = src_address + dst_address;
#ifdef __DHBW_KERNEL__
    uint32_t *src = (uint32_t *) ((src_address & PAGE_ADDR_MASK) - (uint32_t) & LD_DATA_START);
    uint32_t *dst = (uint32_t *) ((dst_address & PAGE_ADDR_MASK) - (uint32_t) & LD_DATA_START);
    for (int i = 0; i < (PAGE_SIZE / 4); i++) {
        *(dst++) = *(src++);
    }

#else
    src_address &= 1;
    dst_address &= 1;
#endif

} // end of copyPage

void clearPage(uint32_t address) {
#ifdef __DHBW_KERNEL__
    uint32_t *addr = (uint32_t *) ((address & PAGE_ADDR_MASK) - (uint32_t) & LD_DATA_START);
    for (int i = 0; i < (PAGE_SIZE / 4); i++) {
        *(addr++) = 0x00000000;
    }
#else
    address &= 1;
#endif
} // end of clearPage



//==============================================================================
//START OF DISK FUNCTIONS//
//==============================================================================

uint32_t getVirtAddrOfFrameOnDisk(uint32_t pde, uint32_t pte) {
    for (uint32_t i = 0; i < PAGES_SWAPPED_NUM; i++) {
        if (storageBitfield[i].pde == pde && storageBitfield[i].pte == pte) {
            //PDE is zero
            return (PAGES_SWAPPED_START + (i * PAGE_SIZE));
        }
    }
    return INVALID_ADDR;
} // end of getVirtAddrOfFrameOnDisk

uint32_t getIndexInStorageBitfield(uint32_t pde, uint32_t pte) {
    for (uint32_t i = 0; i < PAGES_SWAPPED_NUM; i++) {
        if (storageBitfield[i].pde == pde && storageBitfield[i].pte == pte) {
            //PDE is zero
            return i;
        }
    }
    return INVALID_INDEX;
} // end of getIndexInStorageBitfield

uint32_t dbg_swap_addr;
uint32_t dbg_swap_result;

uint32_t swap(uint32_t virtAddr) {
    // Compute Parameters
    int pde = PDE(virtAddr);
    int pte = PTE(virtAddr);

    //printf("Swap:\nPDE: %x PTE: %x\n",pde,pte);
    uint32_t storageAddr;
    dbg_swap_addr = virtAddr;

#ifdef __DHBW_KERNEL__
    invalidate_addr(virtAddr);
    uint32_t * page_table = (uint32_t *) ((page_directory[pde] & PAGE_ADDR_MASK) - (uint32_t) & LD_DATA_START);
#else
    uint32_t * page_table = (uint32_t *) (page_directory[pde] & PAGE_ADDR_MASK);
#endif

    uint32_t memoryAddr = page_table[pte] & PAGE_ADDR_MASK;
    int flags = page_table[pte] & PAGE_OFFSET_MASK;


    // Check if page was modified, only save it then
    if ((flags & PAGE_IS_DIRTY) == PAGE_IS_DIRTY) {
        // Check if page to swap is on disk
        if ((flags & PAGE_IS_SWAPPED) == PAGE_IS_SWAPPED) {
            // Get address of page copy on disk
            storageAddr = getVirtAddrOfFrameOnDisk(pde, pte);
            if (storageAddr != INVALID_ADDR) {
                // Overwrite copy on disk with modified page 
                copyPage(virtAddr, storageAddr);
                pg_struct.sec_addr = storageAddr;
            }
        } else {
            //Get free page on Storage
            uint32_t index = getIndexInStorageBitfield(0, 0);
            storageBitfield[index].pde = pde;
            storageBitfield[index].pte = pte;
            storageAddr = getVirtAddrOfFrameOnDisk(pde, pte);
            pg_struct.sec_addr = storageAddr;
            copyPage(virtAddr, storageAddr);
            clearPage(virtAddr);


        }
        //set swapped bit
        page_table[pte] |= PAGE_IS_SWAPPED;
        //remove dirty bit
        page_table[pte] &= (~PAGE_IS_DIRTY);
    }
    // Reset present bit
    removePresentBit(pde, pte);

    page_table[pte] &= (~PAGE_IS_PRESENT);

    dbg_swap_result = memoryAddr;

    return memoryAddr;

} //END OF SWAP

uint32_t
getAddressOfPageToReplace() {
    /* Implementation of NRU
     * 
    A=0, M=0 (nicht gelesen, nicht verändert)
    A=0, M=1 (nicht gelesen, aber verändert)
    A=1, M=0 (gelesen, aber nicht verändert)
    A=1, M=1 (gelesen und verändert)
     */
    uint32_t *temp_page_table;
    uint32_t start_pde;
    uint32_t start_pte;
    uint32_t counter_pde;
    uint32_t counter_pte;
    uint32_t class;
    uint32_t flags;
    uint32_t tmp_class;
    uint32_t virtAddr;

    //Save pde and pte of last replace
    start_pde = replace_pde_offset;
    start_pte = replace_pte_offset;
    //Inititialize counter on offsets from last replace
    counter_pde = replace_pde_offset;
    counter_pte = replace_pte_offset;
    //Start at highest class + 1 to fetch the first page with class 3 if all pages have class 3
    class = 4;
    //Start to search in bitfield for present pages until one cycle is through or a page with class 0 is found
    do {

        counter_pte++;
        if (counter_pte > PDE_MAX_INDEX) {
            if (counter_pde == PDE_MAX_INDEX) {
                counter_pde = 0;
                counter_pte = 256; //Do not remove Kernel Pages
            } else {
                counter_pte = 0;
                counter_pde++;
            }

        }
        if (isPresentBit(counter_pde, counter_pte)) {
            //Found present page
            //First invalidate TLB to have actual flags in page entry
            virtAddr = 0;
            virtAddr |= counter_pde << PDE_SHIFT;
            virtAddr |= counter_pte << PTE_SHIFT;
#ifdef __DHBW_KERNEL__
            invalidate_addr(virtAddr);
            temp_page_table = (uint32_t *) ((page_directory[counter_pde] & PAGE_ADDR_MASK) - (uint32_t) & LD_DATA_START);
#else
            temp_page_table = (uint32_t *) (page_directory[counter_pde] & PAGE_ADDR_MASK);
#endif
            flags = *(temp_page_table + counter_pte) & PAGE_OFFSET_MASK;
            tmp_class = getClassOfPage(flags);
            //Remove access bit
            *(temp_page_table + counter_pte) &= (~PAGE_IS_ACCESSED);

            //If class of page is lower than actual class, save pde and pte
            if (class > tmp_class) {
                class = tmp_class;
                replace_pde_offset = counter_pde;
                replace_pte_offset = counter_pte;
            }
        }
        //printf("Bool of While %d\n",counter_pde != start_pde && counter_pte != start_pte);
    } while ((counter_pde != start_pde || counter_pte != start_pte) && (class != 0)); //Until walk through bitfield is complete



    //Create a virtual address with the indices of the page which is to replace
    virtAddr = 0;
    virtAddr |= replace_pde_offset << PDE_SHIFT;
    virtAddr |= replace_pte_offset << PTE_SHIFT;
    return virtAddr;
} //END OF NRU

uint32_t getClassOfPage(uint32_t flags) {
    //Bit 5: accesed
    //Bit 6: dirty
    if ((flags & PAGE_IS_ACCESSED) == PAGE_IS_ACCESSED) {
        if ((flags & PAGE_IS_DIRTY) == PAGE_IS_DIRTY) {
            return 3;
        } else {
            return 2;
        }
    } else {
        if ((flags & PAGE_IS_DIRTY) == PAGE_IS_DIRTY) {
            return 1;
        } else {
            return 0;
        }
    }
} // end of getClassOfPage

//==============================================================================
//END OF DISK FUNCTIONS//
//==============================================================================




#ifndef __DHBW_KERNEL__
//for local use

int kprintf(const char * format, ...) {
    int rtn = 0;
    va_list args;
    va_start(args, format);
    rtn = vprintf(format, args);
    va_end(args);
    return rtn;

} // end of kprintf
#endif

//==============================================================================
//Initialize paging//
//==============================================================================

uint32_t*
init_paging() {

    // Initialize Page Directory

    //Set Directory to blank
    for (uint32_t i = 0; i < PDE_NUM; i++) {
        *(page_directory + i) = *(page_directory + i) & 0x00000000;
    }

    //set physical memory bitfield to blank
    for (uint32_t i = 0; i < PAGES_PHYSICAL_NUM; i++) {
        physicalMemoryBitfield[i].pde = 0;
        physicalMemoryBitfield[i].pte = 0;
        physicalMemoryBitfield[i].memAddr = 0;
    }

    for (uint32_t i = 0; i < PAGES_SWAPPED_NUM; i++) {
        storageBitfield[i].pde = 0;
        storageBitfield[i].pte = 0;
        storageBitfield[i].memAddr = 0;
    }

    //Copy Kernel to First Page Table
    //for the first MB
    for (uint32_t i = 0; i < 256; i++) {
#ifdef __DHBW_KERNEL__
        if (i >= (LD_IMAGE_START >> 12) && i < (LD_DATA_START >> 12)) {
            kernel_page_table[i] = (uint32_t) (i * 0x1000 + PAGE_IS_PRESENT);
        } else if (i > (LD_DATA_START >> 12)) {
            kernel_page_table[i] = (uint32_t) (i * 0x1000 + PAGE_IS_PRESENT + PAGE_IS_RW);
        } else {
            kernel_page_table[i] = (uint32_t) (i * 0x1000 + PAGE_IS_PRESENT + PAGE_IS_RW + PAGE_IS_USER);
        }
#else
        if (i >= (0x10000 >> PTE_SHIFT) && i < (0x20000 >> PTE_SHIFT)) {
            kernel_page_table[i] = (uint32_t) (i * PAGE_SIZE + PAGE_IS_PRESENT);
        } else if (i > (0x20000 >> 12)) {
            kernel_page_table[i] = (uint32_t) (i * PAGE_SIZE + PAGE_IS_PRESENT + PAGE_IS_RW);
        } else {
            kernel_page_table[i] = (uint32_t) (i * PAGE_SIZE + PAGE_IS_PRESENT + PAGE_IS_RW + PAGE_IS_USER);
        }
#endif
    }

    //Map memory Adresses 1:1
    if (PDE(PAGES_PHYSICAL_START) == 0) { //Kernel Page Table
        for (uint32_t i = 0; i < PAGES_PHYSICAL_NUM; i++) {
            uint32_t flags = PAGE_IS_PRESENT + PAGE_IS_RW + PAGE_IS_USER;
            uint32_t address = PAGES_PHYSICAL_START + (i * PAGE_SIZE);
            uint32_t index = PTE(PAGES_PHYSICAL_START) + i;
            kernel_page_table[index] = (uint32_t) (address + flags);
        }
    }

    //Map swap Adresses 1:1
    if (PDE(PAGES_SWAPPED_START) == 0) { //Kernel Page Table
        for (uint32_t i = 0; i < PAGES_SWAPPED_NUM; i++) {
            uint32_t flags = PAGE_IS_PRESENT + PAGE_IS_RW + PAGE_IS_USER;
            uint32_t address = PAGES_SWAPPED_START + (i * PAGE_SIZE);
            uint32_t index = PTE(PAGES_SWAPPED_START) + i;
            kernel_page_table[index] = (uint32_t) (address + flags);
        }
    }

    *(page_directory + PDE_KERNEL_PT) = (uint32_t) kernel_page_table | PAGE_IS_PRESENT | PAGE_IS_RW | PAGE_IS_USER;
    *(page_directory + PDE_PROGRAMM_PT) = (uint32_t) programm_page_table | PAGE_IS_PRESENT | PAGE_IS_RW | PAGE_IS_USER;
    *(page_directory + PDE_STACK_PT) = (uint32_t) stack_page_table | PAGE_IS_PRESENT | PAGE_IS_RW | PAGE_IS_USER;

#ifdef __DHBW_KERNEL__
    *(page_directory + PDE_KERNEL_PT) += (uint32_t) & LD_DATA_START;
    *(page_directory + PDE_PROGRAMM_PT) += (uint32_t) & LD_DATA_START;
    *(page_directory + PDE_STACK_PT) += (uint32_t) & LD_DATA_START;
#endif
    return page_directory;
} //END OF INIT PAGING



