
#ifndef PFHANDLER_H
#define PFHANDLER_H        1

#include "types.h"

#define PAGE_SIZE                 0x1000

#define PAGE_IS_PRESENT            0x001
#define PAGE_IS_RW                 0x002
#define PAGE_IS_USER               0x004
#define PAGE_IS_ACCESSED           0x020
#define PAGE_IS_DIRTY              0x040
#define PAGE_IS_SWAPPED            0x400

#define PAGES_PHYSICAL_NUM             4
#define PAGES_PHYSICAL_START    0x200000
#define PAGES_PHYSICAL_END    (PAGES_PHYSICAL_START+PAGES_PHYSICAL_NUM*PAGE_SIZE-1)
#define PAGES_SWAPPED_NUM            256
#define PAGES_SWAPPED_START     0x300000
#define PAGES_SWAPPED_END     (PAGES_SWAPPED_START+PAGES_SWAPPED_NUM*PAGE_SIZE-1)

#define SWAPPED_START_ADDR      0x100000

#define PDE_NUM                     1024
#define PDE_MAX_INDEX         (PDE_NUM-1)
#define PDE_SHIFT                     22
#define PDE_MASK              (PDE_MAX_INDEX << PDE_SHIFT)
#define PTE_NUM                     1024
#define PTE_MAX_INDEX         (PTE_NUM-1)
#define PTE_SHIFT                     12
#define PTE_MASK              (PTE_MAX_INDEX << PTE_SHIFT)

#define PDE(addr)             (((addr) & PDE_MASK) >> PDE_SHIFT)
#define PTE(addr)             (((addr) & PTE_MASK) >> PTE_SHIFT)

#define PAGE_ADDR_MASK        (PDE_MASK | PTE_MASK)
#define PAGE_OFFSET_MASK      ~PAGE_ADDR_MASK

#define KERNEL_START_ADDR     0x00000000
#define PROGRAM_START_ADDR    0x08048000
#define STACK_START_ADDR      0xfff00000

#define INVALID_ADDR          0xffffffff
#define INVALID_INDEX         0xffffffff
#define INVALID_FLAGS         0x0

#define PDE_KERNEL_PT         PDE(KERNEL_START_ADDR)
#define PDE_PROGRAMM_PT       PDE(PROGRAM_START_ADDR)
#define PDE_STACK_PT          PDE(STACK_START_ADDR)



typedef struct pg_struct {
    uint32_t ft_addr;     // faulting linear memory address
    uint32_t pde;         // Page Directory Entry
    uint32_t pte;         // Page Table Entry
    uint32_t off;         // Page Offset
    uint32_t ph_addr;     // Physical Address
    uint32_t flags;       // Flags = TBD
    uint32_t vic_addr;    // victim page address
    uint32_t sec_addr;    // secondary storage address
} pg_struct_t;


extern uint32_t *init_paging();
extern void freeAllPages(void);
extern pg_struct_t *pfhandler(uint32_t ft_addr);

#endif  /* pfhandler.h */

