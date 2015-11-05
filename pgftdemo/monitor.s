
#==================================================================
# S E C T I O N   D A T A
#==================================================================
        .section        .data

        .align  4
errmsg: .ascii  "Syntax Error\r\n"
        .equ    errmsg_len, (.-errmsg)

        .align  4
hlpmsg: .ascii  "Monitor Commands:\r\n"
        .ascii  "  H           - Help (this text)\r\n"
        .ascii  "  Q           - Quit monitor\r\n"
        .ascii  "  M           - Show non-kernel page table entries\r\n"
        .ascii  "  C           - Release allocated pages (except kernel)\r\n"
        .ascii  "  A           - Reset all accessed bits in page table\r\n"
        .ascii  "  D ADDR NUM  - Dump NUM words beginning at address ADDR\r\n"
        .ascii  "  X ADDR NUM  - Calculate CRC32 for NUM words starting at address ADDR\r\n"
        .ascii  "  P ADDR      - Invalidate TLB entry for virtual address ADDR\r\n"
        .ascii  "  R ADDR      - Read from address ADDR\r\n"
        .ascii  "  F ADDR WORD - Fill page belonging to ADDR with 32-bit word WORD,\r\n"
        .ascii  "                incremented by one for each address step\r\n"
        .ascii  "  W ADDR WORD - Write 32-bit word WORD into ADDR\r\n\r\n"
        .ascii  "All addresses/words are in hexadecimal, e.g. 00123ABC\r\n"
        .ascii  "Leading zeros can be omitted\r\n"
        .ascii  "\r\n"
        .equ    hlpmsg_len, (.-hlpmsg)

        .align  4
dumpmsg:.ascii  "________ ________ ________ ________\r\n"
        .equ    dumpmsg_len, (.-dumpmsg)

        .align  4
addrmsg:.ascii  "________: ________\r\n"
        .equ    addrmsg_len, (.-addrmsg)

        .align  4
pagemsg:.ascii  "________: ________ ____\r\n"
        .equ    pagemsg_len, (.-pagemsg)

        .align  4
mon_addr:
        .long 0


#==================================================================
# S E C T I O N   T E X T
#==================================================================
        .section        .text


        .type   run_monitor, @function
        .global run_monitor
        .extern check_cpuid
        .extern kgets
        .extern freeAllPages
        .extern clearAllAccessedBits
run_monitor:
        enter   $260, $0
        pushal
        pushl   %gs

        #----------------------------------------------------------
        # check cpuid for available features (crc32 instruction)
        #----------------------------------------------------------
        call    check_cpuid

        #----------------------------------------------------------
        # setup GS segment register for linear addressing
        #----------------------------------------------------------
        movw    $linDS, %ax
        movw    %ax, %gs

        xorl    %ecx, %ecx
.Lloop:
        leal    -256(%ebp), %esi    # get local buffer address on stack
        movl    %esi, mon_addr
        call    kgets
        testl   %eax, %eax
        movl    %eax, %ecx          # buffer index
        jz      .Lmonitor_exit
        movb    (%esi), %al
        cmpb    $10, %al
        je      .Lloop
        cmpb    $13, %al
        je      .Lloop
        #----------------------------------------------------------
        # commands without parameters
        #----------------------------------------------------------
        cmpb    $'Q', %al
        je      .Lmonitor_exit
        cmpb    $'H', %al
        je      .Lhelp
        cmpb    $'M', %al
        je      .Lmappedpages
        cmpb    $'C', %al
        je      .Lreleasepages
        cmpb    $'A', %al
        je      .Lclearaccessedbits
        cmpb    $'#', %al
        je      .Lloop
        #----------------------------------------------------------
        # commands that require parameters
        #----------------------------------------------------------
        cmpb    $3, %cl
        jb      .Lerror
        cmpb    $'W', %al
        je      .Lwriteaddr
        cmpb    $'R', %al
        je      .Lreadaddr
        cmpb    $'X', %al
        je      .Lcrcaddr
        cmpb    $'D', %al
        je      .Ldumpaddr
        cmpb    $'F', %al
        je      .Lfilladdr
        cmpb    $'P', %al
        je      .Lpginvaddr

        #----------------------------------------------------------
        # print error message
        #----------------------------------------------------------
.Lerror:
        leal    errmsg, %esi
        movl    $errmsg_len, %ecx
        call    screen_write
        jmp     .Lloop

        #----------------------------------------------------------
        # print help message
        #----------------------------------------------------------
.Lhelp:
        leal    hlpmsg, %esi
        movl    $hlpmsg_len, %ecx
        call    screen_write
        jmp     .Lloop

        #----------------------------------------------------------
        # write to address
        #----------------------------------------------------------
.Lwriteaddr:
        incl    %esi
        # read linear address
        call    hex2int
        movl    %eax, %edi

        # read value to write into address
        call    hex2int

        #----------------------------------------------------------
        # memory write access
        #----------------------------------------------------------
mon_inst_wr_addr:
        movl    %eax, %gs:(%edi)
        jmp     .Lloop

        #----------------------------------------------------------
        # read from address
        #----------------------------------------------------------
.Lreadaddr:
        incl    %esi
        # read linear address
        call    hex2int
        movl    %eax, -260(%ebp)        # store address on stack

        leal    addrmsg, %edi           # pointer to output string
        movl    $8, %ecx                # number of output digits
        call    int_to_hex

        movl    -260(%ebp), %edi        # restore address

        #----------------------------------------------------------
        # memory read access
        #----------------------------------------------------------
mon_inst_rd_addr:
        movl    %gs:(%edi), %eax

        leal    addrmsg+10, %edi        # pointer to output string
        movl    $8, %ecx                # number of output digits
        call    int_to_hex

        leal    addrmsg, %esi           # message-offset
        movl    $addrmsg_len, %ecx      # message-length
        call    screen_write
        jmp     .Lloop

        #----------------------------------------------------------
        # calculate CRC32
        #----------------------------------------------------------
.Lcrcaddr:
        cmpb    $1, cpuid_sse42_avail
        jne     .Lloop

        incl    %esi
        # read linear address
        call    hex2int
        movl    %eax, %edi

        # read number of words
        call    hex2int

        xorl    %ecx, %ecx
        xorl    %edx, %edx
        decl    %edx
.Lcrcloop:
        crc32l  %gs:(%edi,%ecx,4), %edx
        incl    %ecx
        cmpl    %eax, %ecx
        jb      .Lcrcloop
        xorl    $0xffffffff, %edx

        movl    %edx, %eax
        leal    addrmsg+10, %edi        # pointer to output string
        movl    $8, %ecx                # number of output digits
        call    int_to_hex

        leal    addrmsg+10, %esi        # message-offset
        movl    $addrmsg_len-10, %ecx   # message-length
        call    screen_write
        jmp     .Lloop

        #----------------------------------------------------------
        # dump memory contents
        #----------------------------------------------------------
.Ldumpaddr:
        incl    %esi
        subl    $8, %esp
        # read linear address
        call    hex2int
        # put linear address onto stack
        movl    %eax, (%esp)

        # read number of words
        call    hex2int
        # put number of words onto stack
        movl    %eax, 4(%esp)
        call    dump_memory
        addl    $8, %esp
        jmp     .Lloop

        #----------------------------------------------------------
        # fill memory contents
        #----------------------------------------------------------
.Lfilladdr:
        incl    %esi
        # read linear address
        call    hex2int
        call    get_page_addr
        testl   %eax, %eax
        jz      .Lloop

        movl    %eax, %edi

        # read fill word
        call    hex2int

        xorl    %ecx, %ecx
        xorl    %edx, %edx
        decl    %edx
.Lfillloop:
        movl    %eax, %gs:(%edi,%ecx,4)
        crc32l  %gs:(%edi,%ecx,4), %edx
        incl    %eax
        incl    %ecx
        cmpl    $1024, %ecx
        jb      .Lfillloop
        xorl    $0xffffffff, %edx

        movl    %edx, %eax
        leal    addrmsg+10, %edi        # pointer to output string
        movl    $8, %ecx                # number of output digits
        call    int_to_hex

        leal    addrmsg+10, %esi        # message-offset
        movl    $addrmsg_len-10, %ecx   # message-length
        call    screen_write
        jmp     .Lloop
.Lmappedpages:
        call    print_mapped_pages
        jmp     .Lloop
.Lreleasepages:
        call    free_all_pages
        jmp     .Lloop
.Lclearaccessedbits:
        call    clear_all_accessed_bits
        jmp     .Lloop
.Lpginvaddr:
        incl    %esi
        call    hex2int
        invlpg  %gs:(%eax)
        jmp     .Lloop
.Lmonitor_exit:
        popl    %gs
        popa
        leave
        ret


        .type   dump_memory, @function
        .global dump_memory
dump_memory:
        enter   $4, $0
        pushal
        pushl   %gs

        #----------------------------------------------------------
        # setup GS segment register for linear addressing
        #----------------------------------------------------------
        movw    $linDS, %ax
        movw    %ax, %gs

        movl    8(%ebp), %ebx    # linear address
        movl    12(%ebp), %edx   # number of words
        # cut number to 12-bit
        andl    $0x1fff, %edx
        movl    %edx, -4(%ebp)   # store number of words
        xorl    %edx, %edx       # counter
        leal    dumpmsg, %esi    # message pointer
        movl    %esi, %edi
.Ldumploop:
        movl    %gs:(%ebx,%edx,4), %eax
        movl    $8, %ecx              # number of output digits
        call    int_to_hex
        addl    $9, %edi
        incl    %edx
        testl   $3, %edx              # multiple of 4?
        jnz     .Lnonewline
        movl    %esi, %edi
        movl    $dumpmsg_len, %ecx    # message-length
        call    screen_write
.Lnonewline:
        cmpl    %edx, -4(%ebp)
        jne     .Ldumploop
        andl    $3, %edx
        jz      .Ldumpfinished
        movl    %esi, %edi
        leal    (%edx,%edx,8), %ecx   # message length
        movb    $'\n', -1(%esi,%ecx,1)
        call    screen_write
        movb    $' ', -1(%esi,%ecx,1)
.Ldumpfinished:
        popl    %gs
        popal
        leave
        ret


        .type   print_mapped_pages, @function
print_mapped_pages:
        enter   $4, $0
        pushal

        # get page directory address
        movl    %cr3, %esi
        # segmented page directory address
        subl    $LD_DATA_START, %esi
        # ignore first table table, which contains kernel pages
        movl    $1, %ecx
.Lpdeloop:
        # read page directory entry (PDE)
        movl    (%esi,%ecx,4), %ebx
        # check present bit
        testl   $1, %ebx
        jz      .Lskippde
        # save PDE index
        movl    %ecx, -4(%ebp)
        xorl    %ecx, %ecx
        # mask page table address
        andl    $0xfffff000, %ebx
        # segmented page table address
        subl    $LD_DATA_START, %ebx
.Lpteloop:
        # read page table entry (PTE)
        movl    (%ebx,%ecx,4), %edx
        # check whether entry is zero
        testl   %edx, %edx
        jz      .Lskippte
        # read PDE index and shift it
        movl    -4(%ebp), %eax
        shll    $10, %eax
        # add PTE index and shift it
        addl    %ecx, %eax
        shll    $12, %eax
        call    print_mapped_addr
.Lskippte:
        incl    %ecx
        cmpl    $1024, %ecx
        jb      .Lpteloop
        # restore PDE index
        movl    -4(%ebp), %ecx
.Lskippde:
        incl    %ecx
        cmpl    $1024, %ecx
        jb      .Lpdeloop

        popal
        leave
        ret


#-------------------------------------------------------------------
# FUNCTION:   print_mapped_addr
#
# PURPOSE:    Print the page table entry and mapped physical address
#
# PARAMETERS: (via register)
#             EAX - virtual address
#             EDX - mapped physical address
#
# RETURN:     none
#
#-------------------------------------------------------------------
        .type   print_mapped_addr, @function
        .extern int_to_hex
        .extern screen_write
print_mapped_addr:
        enter   $0, $0
        pushal

        leal    pagemsg, %edi           # pointer to output string
        movl    $8, %ecx                # number of output digits
        call    int_to_hex

        movl    %edx, %eax
        leal    pagemsg+10, %edi        # pointer to output string
        movl    $8, %ecx                # number of output digits
        call    int_to_hex

        call    get_pg_flags
        movl    %eax, pagemsg+19

        leal    pagemsg, %esi           # message-offset
        movl    $pagemsg_len, %ecx      # message-length
        call    screen_write

        popal
        leave
        ret


#------------------------------------------------------------------
# read the paging flags for the given linear address
#       %eax (in): linear address
#
# return: flags in %eax encoded in ASCII
#------------------------------------------------------------------
get_pg_flags:
        enter   $0, $0
        pushl   %edx

        movl    %eax, %edx
        andl    $0xfff, %edx
        movl    $0x2e202020, %eax
        testl   $1, %edx             # check 'present' bit
        jz      .Lget_pg_flags_end
        movb    $'P', %al
        shll    $8, %eax
        movb    $'R', %al
        testl   $2, %edx             # check 'read/write' bit
        jz      .Lread_only
        movb    $'W', %al
.Lread_only:
        shll    $8, %eax
        movb    $'a', %al
        testl   $1<<5, %edx          # check 'accessed' bit
        jz      .Lnot_accessed
        movb    $'A', %al
.Lnot_accessed:
        shll    $8, %eax
        movb    $'d', %al
        testl   $1<<6, %edx          # check 'dirty' bit
        jz      .Lget_pg_flags_end
        movb    $'D', %al
        jmp     .Lget_pg_flags_end

.Ltable_not_mapped:
        movl    $0x20202020, %eax

.Lget_pg_flags_end:

        popl    %edx
        leave
        ret


        .type   get_page_addr, @function
get_page_addr:
        enter   $4, $0
        pushl   %edx
        pushl   %esi

        # get page directory address
        movl    %cr3, %esi
        # segmented page directory address
        subl    $LD_DATA_START, %esi

        # store linear address on stack
        movl    %eax, -4(%ebp)
        movl    %eax, %edx
        # initialise default return value
        xorl    %eax, %eax

        # get page directory entry
        shrl    $22, %edx
        # PDE #0 is reserved for the Kernel
        testl   %edx, %edx
        jz      .Lget_page_addr_end

        movl    (%esi,%edx,4), %esi
        testl   $1, %esi
        jz      .Lget_page_addr_end

        movl    -4(%ebp), %edx
        shrl    $12, %edx
        andl    $0x3ff, %edx
        andl    $0xfffff000, %esi
        leal    (%esi,%edx,4), %esi
        # segmented page table address
        subl    $LD_DATA_START, %esi
        movl    (%esi), %edx
        testl   $1, %edx
        jz      .Lget_page_addr_end

        # load linear address from stack
        movl    -4(%ebp), %eax
        # mask page offset
        andl    $0xfffff000, %eax

.Lget_page_addr_end:
        popl    %esi
        popl    %edx
        leave
        ret


#-------------------------------------------------------------------
# FUNCTION:   hex2int
#
# PURPOSE:    Convert a hexadecimal ASCII string into an integer
#
# PARAMETERS: (via register)
#             ESI - pointer to input string
#
# RETURN:     EAX - converted integer
#             ESI points to the next character of the hex string
#
#-------------------------------------------------------------------
        .type   hex2int, @function
hex2int:
        enter   $0, $0
        pushl   %edx

        xorl    %eax, %eax
.Lspcloop:
        movb    (%esi), %dl
        testb   %dl, %dl
        jz      .Lexit
        cmpb    $'\n', %dl
        jz      .Lexit
        cmpb    $'\r', %dl
        jz      .Lexit
        incl    %esi
        cmpb    $' ', %dl
        je      .Lspcloop
        decl    %esi
.Lhexloop:
        movb    (%esi), %dl
        testb   %dl, %dl
        jz      .Lexit
        cmpb    $'\n', %dl
        jz      .Lexit
        cmpb    $'\r', %dl
        jz      .Lexit
        cmpb    $' ', %dl
        jz      .Lexit
        cmpb    $0, %dl
        jb      .Lexit
        # dl >= '0'
        cmpb    $'f', %dl
        ja      .Lexit
        # dl >= '0' && dl <= 'f'
        cmpb    $'9', %dl
        movb    $'0', %dh
        jbe     .Lconv_digit     # dl >= '0' && dl <= '9'
        # dl > '9' && dl <= 'f'
        cmpb    $'A', %dl
        jb      .Lexit
        # dl >= 'A' && dl <= 'f'
        cmpb    $'F', %dl
        movb    $'A'-10, %dh
        jbe     .Lconv_digit     # dl => 'A' && dl <= 'F'
        # dl > 'F' && dl <= 'f'
        cmpb    $'a', %dl
        jb      .Lexit
        # dl >= 'a' && dl <= 'f'
        movb    $'a'-10, %dh
.Lconv_digit:
        subb    %dh, %dl        # convert hex digit to int 0..15
        shll    $4, %eax        # multiply result by 16
        movzxb  %dl, %edx
        addl    %edx, %eax      # add digit value to result
        incl    %esi
        jmp     .Lhexloop
.Lexit:
        incl    %esi
        popl    %edx
        leave
        ret

