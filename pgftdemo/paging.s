

#==================================================================
# C O N S T A N T S
#==================================================================
        .equ            PG_SIZE,    0x1000
        .equ            PG_PRESENT,      1
        .equ            PG_RW,           2
        .equ            PG_USR,          4


#==================================================================
# S E C T I O N   B S S
#==================================================================
        .section        .bss

        .align PG_SIZE
        .comm  page_dir, PG_SIZE
        .comm  page_table_kernel, PG_SIZE


#==================================================================
# S E C T I O N   T E X T
#==================================================================
        .section        .text
        .code32

        #-------------------------------------------------------------------
        # reference to constants defined in ldscript
        #-------------------------------------------------------------------
        .extern         LD_DATA_START
        .extern         LD_IMAGE_START
        .extern         _rodata        # start of .rodata segment
        .extern         _bss           # start of .bss segment


#-------------------------------------------------------------------
# FUNCTION:   enable_paging
#
# PURPOSE:    Enable paging support by the microprocessor
#
# C Call:     void enable_paging(void)
#
# PARAMETERS: none
#
# RETURN:     none
#
#-------------------------------------------------------------------
        .type           enable_paging, @function
        .globl          enable_paging

        #----------------------------------------------------------
        # bit 31: enable paging
        # bit 30: disable caching
        # bit 16: enable write protection
        #----------------------------------------------------------
        .equ    CR0_PG_FLAGS, (1<<31)+(1<<30)+(1<<16)

enable_paging:
        enter   $0, $0
        push    %eax
        push    %ebx
        push    %ecx
        push    %edx

        #----------------------------------------------------------
        # initialise page directory entries to zero
        #----------------------------------------------------------
        mov     $page_dir, %eax
        xor     %ecx, %ecx
.Lpgdirloop:
        movl    $0, (%eax,%ecx,4)
        inc     %ecx
        cmp     $PG_SIZE/4, %ecx
        jb      .Lpgdirloop

        #----------------------------------------------------------
        # initialise kernel page table entries to provide a 1:1
        # mapping between linear and physical addresses
        #
        # Read-only or read-write protection is assigned to pages
        # according to the following rules:
        # - text segment is read-only
        # - data segment is read-write
        # - rodata segment is read-only
        # - bss is read-write
        # - everything else is read-write
        #----------------------------------------------------------
        mov     $page_table_kernel, %ebx
        xor     %ecx, %ecx
        xor     %edx, %edx
.Lpgtableloop:
        # addresses below LD_IMAGE_START are always RW
        cmp     $LD_IMAGE_START, %edx
        jb      .Lpgrw
        # otherwise, the address is either within the
        # text segment (i.e. below the data segment) or
        # above
        cmp     $LD_DATA_START, %edx
        jb      .Lpgro
        # otherwise, the address is either in the data,
        # rodata or bss segment or above the image.
        # In any case, we need to convert the linear
        # address in regsiter EDX into a logical address
        # in order to be able to compare the address with
        # the linker symbols (which are logical addresses).
        # EDX: linear address
        # EAX: logical address
        mov     %edx, %eax
        sub     $LD_DATA_START, %eax
        # addresses in and above the bss segment are always RW
        cmp     $_bss, %eax
        jae     .Lpgrw
        # addresses in the data segment (i.e. below the rodata
        # segment) are always RW
        cmp     $_rodata, %eax
        jb      .Lpgrw
        # otherwise, the address is in the rodata segment
        # and always RO
.Lpgro:
        mov     $PG_PRESENT, %dl
        jmp     .Lpgmap
.Lpgrw:
        mov     $PG_PRESENT+PG_RW, %dl
.Lpgmap:
        movl    %edx, (%ebx,%ecx,4)
        xor     %dl, %dl
        inc     %ecx
        add     $PG_SIZE, %edx
        cmp     $PG_SIZE/4, %ecx
        jb      .Lpgtableloop

        #----------------------------------------------------------
        # convert logical kernel page table addess in EBX to a
        # linear address and write this address into PDE #0
        #----------------------------------------------------------
        mov     $page_dir, %eax
        add     $LD_DATA_START, %ebx    # add .data start address
        or      $PG_PRESENT+PG_RW, %ebx
        mov     %ebx, (%eax)            # eax: page dir address

        #----------------------------------------------------------
        # setup page-directory address in control register CR3
        #----------------------------------------------------------
        add     $LD_DATA_START, %eax    # add .data start address
        mov     %eax, %cr3              # goes into CR3 register

        #----------------------------------------------------------
        # turn on paging
        #----------------------------------------------------------
        mov     %cr0, %eax              # current machine status
        or      $CR0_PG_FLAGS, %eax     # set paging flags
        mov     %eax, %cr0
        jmp     .+2                     # flush prefetch queue

        pop     %edx
        pop     %ecx
        pop     %ebx
        pop     %eax
        leave
        ret


#-------------------------------------------------------------------
# FUNCTION:   disable_paging
#
# PURPOSE:    Disable paging support by the microprocessor
#
# C Call:     void disable_paging(void)
#
# PARAMETERS: none
#
# RETURN:     none
#
#-------------------------------------------------------------------
        .type           disable_paging, @function
        .globl          disable_paging
disable_paging:
        enter   $0, $0
        push    %eax

        #----------------------------------------------------------
        # turn off paging (by clearing bit #31 in register CR0)
        #----------------------------------------------------------
        mov     %cr0, %eax              # current machine status
        btc     $31, %eax               # turn on PG-bit's image
        mov     %eax, %cr0              # enable page-mappings
        jmp     .+2                     # flush prefetch queue

        #----------------------------------------------------------
        # invalidate the CPU's Translation Lookaside Buffer
        #----------------------------------------------------------
        xor     %eax, %eax              # setup "dummy" value
        mov     %eax, %cr3              # and write it to CR3

        pop     %eax
        leave
        ret


#-------------------------------------------------------------------
# FUNCTION:   get_page_dir_addr
#
# PURPOSE:    Return the page directory address by reading it from CR3
#
# C Call:     uint32_t get_page_dir_addr(void)
#
# PARAMETERS: none
#
# RETURN:     logical page directory address
#
#-------------------------------------------------------------------
        .type   get_page_dir_addr, @function
        .globl  get_page_dir_addr
get_page_dir_addr:
        enter   $0, $0
        # get page directory address
        mov     %cr3, %eax
        # convert to logical page directory address
        sub     $LD_DATA_START, %eax
        leave
        ret


#-------------------------------------------------------------------
# FUNCTION:   invalidate_addr
#
# PURPOSE:    Invalidates the TLB entry associated with the virtual
#             address provided as argument
#
# C Call:     void invalidate_addr(unsigned long addr)
#
# PARAMETERS: (via stack - C style)
#             addr - virtual address to invalidate
#
# RETURN:     none
#
#-------------------------------------------------------------------
        .type           invalidate_addr, @function
        .globl          invalidate_addr
invalidate_addr:
        enter   $0, $0
        push    %eax
        push    %gs

        #----------------------------------------------------------
        # setup GS segment register for linear addressing
        #----------------------------------------------------------
        mov     $linDS, %ax
        mov     %ax, %gs

        #----------------------------------------------------------
        # invalidate the TLB entry for the given linear address
        #----------------------------------------------------------
        mov     8(%ebp), %eax
        invlpg  %gs:(%eax)

        pop     %gs
        pop     %eax
        leave
        ret


#-------------------------------------------------------------------
# FUNCTION:   is_page_present
#
# PURPOSE:    Checks whether the given linear address is mapped to
#             a page frame or not
#
# C Call:     int is_page_present(unsigned long addr)
#
# PARAMETERS: (via stack - C style)
#             addr - linear address to check
#
# RETURN:     1: present, 0: not present
#
#-------------------------------------------------------------------
        .type   is_page_present, @function
        .globl  is_page_present
is_page_present:
        enter   $0, $0
        push    %edx
        push    %esi

        # get page directory address
        mov     %cr3, %esi
        # convert to logical page directory address
        sub     $LD_DATA_START, %esi

        # load linear address from stack
        mov     8(%ebp), %edx
        # initialise default return value
        xor     %eax, %eax
        # get page directory entry
        shr     $22, %edx
        mov     (%esi,%edx,4), %esi
        test    $1, %esi
        jz      .Lend

        # load linear address from stack
        mov     8(%ebp), %edx
        # mask paging flags
        and     $0xfffff000, %esi
        # get page table entry
        shr     $12, %edx
        and     $0x3ff, %edx
        lea     (%esi,%edx,4), %esi
        # segmented page table address
        sub     $LD_DATA_START, %esi
        mov     (%esi), %eax
        and     $1, %eax
.Lend:
        pop     %esi
        pop     %edx
        leave
        ret

