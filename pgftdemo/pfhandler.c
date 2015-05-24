

typedef struct pg_struct {
    unsigned long ft_addr;  // faulting linear memory address
    unsigned long     pde;  // Page Directory Entry
    unsigned long     pte;  // Page Table Entry
    unsigned long     off;  // Page Offset
    unsigned long ph_addr;  // Physical Address
    unsigned long   flags;  // Flags = TBD
} pg_struct_t;


static pg_struct_t pg_struct;


pg_struct_t *
pfhandler(unsigned long ft_addr)
{
    pg_struct.ft_addr = ft_addr;
    pg_struct.pde     = 0x123;
    pg_struct.pte     = 0xabc;
    pg_struct.off     = ft_addr & 0xfff;
    pg_struct.ph_addr = 0x10000000 + ft_addr;
    pg_struct.flags   = 0xbeef;

    return &pg_struct;
} /* end of pfhandler */

