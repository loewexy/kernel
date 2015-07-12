
#==================================================================
# S E C T I O N   D A T A
#==================================================================
        .section        .data

mon_addr:
        .long 0, 0, 0, 0, 0, 0, 0, 0

errmsg: .ascii  "Syntax Error\n"
        .equ    errmsg_len, (.-errmsg)

hlpmsg: .ascii  "Monitor Commands:\n"
        .ascii  "  H           - Help (this text)\n"
        .ascii  "  Q           - Quit monitor\n"
        .ascii  "  M           - Show all mapped non-kernel pages\n"
        .ascii  "  C           - Release allocated pages (except kernel)\n"
        .ascii  "  D ADDR NUM  - Dump NUM words beginning at address ADDR\n"
        .ascii  "  P ADDR      - Invalidate TLB entry for virtual address ADDR\n"
        .ascii  "  R ADDR      - Read from address ADDR\n"
        .ascii  "  F ADDR WORD - Fill page belonging to ADDR with 32-bit word WORD,\n"
        .ascii  "                incremented by one for each address step\n"
        .ascii  "  W ADDR WORD - Write 32-bit word WORD into ADDR\n\n"
        .ascii  "All addresses/words are in hexadecimal, e.g. 00123ABC\n"
        .ascii  "Leading zeros can be omitted\n"
        .ascii  "\n"
        .equ    hlpmsg_len, (.-hlpmsg)

dumpmsg:.ascii  "________ ________ ________ ________\n"
        .equ    dumpmsg_len, (.-dumpmsg)

addrmsg:.ascii  "________: ________\n"
        .equ    addrmsg_len, (.-addrmsg)

pagemsg:.ascii  "________: ________ ____\n"
        .equ    pagemsg_len, (.-pagemsg)

#==================================================================
# S E C T I O N   T E X T
#==================================================================
        .section        .text


        .type   run_monitor, @function
        .global run_monitor
        .extern kgets
        .extern freeAllPages
run_monitor:
        enter   $268, $0
        pusha
        push    %gs

        #----------------------------------------------------------
        # setup GS segment register for linear addressing
        #----------------------------------------------------------
        mov     $linDS, %ax
        mov     %ax, %gs

        xor     %ecx, %ecx
.Lloop:
        lea     -256(%ebp), %esi
        call    kgets
        test    %eax, %eax
        mov     %eax, %ecx          # buffer index
        jz      .Lmonitor_exit
        movb    (%esi), %al
        cmpb    $10, %al
        je      .Lloop
        cmpb    $13, %al
        je      .Lloop
        # commands without parameters
        cmpb    $'Q', %al
        je      .Lmonitor_exit
        cmpb    $'H', %al
        je      .Lhelp
        cmpb    $'M', %al
        je      .Lmappedpages
        cmpb    $'C', %al
        je      .Lreleasepages
        cmpb    $'#', %al
        je      .Lloop
        # commands that require parameters
        cmp     $3, %cl
        jb      .Lerror
        cmpb    $'W', %al
        je      .Lwriteaddr
        cmpb    $'R', %al
        je      .Lreadaddr
        cmpb    $'D', %al
        je      .Ldumpaddr
        cmpb    $'F', %al
        je      .Lfilladdr
        cmpb    $'P', %al
        je      .Lpginvaddr
.Lerror:
        mov     %ecx, -260(%ebp)
        lea     errmsg, %esi
        mov     $errmsg_len, %ecx
        call    screen_write
        mov     -260(%ebp), %ecx
        jmp     .Lloop
.Lhelp:
        mov     %ecx, -260(%ebp)
        lea     hlpmsg, %esi
        mov     $hlpmsg_len, %ecx
        call    screen_write
        mov     -260(%ebp), %ecx
        jmp     .Lloop
.Lwriteaddr:
        inc     %esi
        # read linear address
        call    hex2int
        mov     %eax, %edi

        # read value to write into address
        call    hex2int
        movl    %eax, %gs:(%edi)
        jmp     .Lloop
.Lreadaddr:
        mov     %ecx, -260(%ebp)
        inc     %esi
        # read linear address
        call    hex2int
        mov     %eax, -264(%ebp)        # store address on stack

        lea     addrmsg, %edi           # pointer to output string
        mov     $8, %ecx                # number of output digits
        call    int_to_hex

        mov     -264(%ebp), %edi
        movl    %gs:(%edi), %eax

        lea     addrmsg+10, %edi        # pointer to output string
        mov     $8, %ecx                # number of output digits
        call    int_to_hex

        lea     addrmsg, %esi           # message-offset
        mov     $addrmsg_len, %ecx      # message-length
        call    screen_write
        mov     -260(%ebp), %ecx
        jmp     .Lloop
.Ldumpaddr:
        inc     %esi
        sub     $8, %esp
        # read linear address
        call    hex2int
        # put linear address onto stack
        mov     %eax, (%esp)
        mov     %eax, mon_addr

        # read number of words
        call    hex2int
        # put number of words onto stack
        mov     %eax, 4(%esp)
        mov     %eax, mon_addr+4

        #mov     8(%ebp), %ebx    # linear address
        #mov     %ebx, mon_addr
        #mov     12(%ebp), %edx   # number of words
        #mov     %edx, mon_addr+4

        call    dump_memory
        add     $8, %esp
        jmp     .Lloop
.Lfilladdr:
        mov     %ecx, -260(%ebp)
        inc     %esi
        # read linear address
        call    hex2int
        call    get_page_addr
        test    %eax, %eax
        jz      .Lloop
        mov     %eax, %edi

        # read fill word
        call    hex2int

        xor     %ecx, %ecx
.Lfillloop:
        mov     %eax, %gs:(%edi,%ecx,4)
        inc     %eax
        inc     %ecx
        cmp     $1024, %ecx
        jb      .Lfillloop

        mov     -260(%ebp), %ecx
        jmp     .Lloop
.Lmappedpages:
        call    print_mapped_pages
        jmp     .Lloop
.Lreleasepages:
        call    freeAllPages
        jmp     .Lloop
.Lpginvaddr:
        inc     %esi
        call    hex2int
        invlpg  %gs:(%eax)
        jmp     .Lloop
.Lmonitor_exit:
        pop     %gs
        popa
        leave
        ret


        .type   dump_memory, @function
        .global dump_memory
dump_memory:
        enter   $4, $0
        pusha
        push    %gs

        #----------------------------------------------------------
        # setup GS segment register for linear addressing
        #----------------------------------------------------------
        mov     $linDS, %ax
        mov     %ax, %gs

        mov     8(%ebp), %ebx    # linear address
        mov     12(%ebp), %edx   # number of words
        # cut number to 12-bit
        and     $0x1fff, %edx
        mov     %edx, -4(%ebp)   # store number of words
        xor     %edx, %edx       # counter
        lea     dumpmsg, %esi    # message pointer
        mov     %esi, %edi
.Ldumploop:
        mov     %gs:(%ebx,%edx,4), %eax
        mov     $8, %ecx              # number of output digits
        call    int_to_hex
        add     $9, %edi
        inc     %edx
        test    $3, %edx              # multiple of 4?
        jnz     .Lnonewline
        mov     %esi, %edi
        mov     $dumpmsg_len, %ecx    # message-length
        call    screen_write
.Lnonewline:
        cmp     %edx, -4(%ebp)
        jne     .Ldumploop
        and     $3, %edx
        jz      .Ldumpfinished
        mov     %esi, %edi
        lea     (%edx,%edx,8), %ecx   # message length
        movb    $'\n', -1(%esi,%ecx,1)
        call    screen_write
        movb    $' ', -1(%esi,%ecx,1)
.Ldumpfinished:
        pop     %gs
        popa
        leave
        ret


        .type   print_mapped_pages, @function
print_mapped_pages:
        enter   $4, $0
        pusha

        # get page directory address
        mov     %cr3, %esi
        # segmented page directory address
        sub     $LD_DATA_START, %esi
        # ignore first table table, which contains kernel pages
        mov     $1, %ecx
.Lpdeloop:
        # read page directory entry (PDE)
        mov     (%esi,%ecx,4), %ebx
        # check present bit
        test    $1, %ebx
        jz      .Lskippde
        # save PDE index
        mov     %ecx, -4(%ebp)
        xor     %ecx, %ecx
        # mask page table address
        and     $0xfffff000, %ebx
        # segmented page table address
        sub     $LD_DATA_START, %ebx
.Lpteloop:
        # read page table entry (PTE)
        mov     (%ebx,%ecx,4), %edx
        # check present bit
        test    $1, %edx
        jz      .Lskippte
        # read PDE index and shift it
        mov     -4(%ebp), %eax
        shl     $10, %eax
        # add PTE index and shift it
        add     %ecx, %eax
        shl     $12, %eax
        call    print_mapped_addr
.Lskippte:
        inc     %ecx
        cmp     $1024, %ecx
        jb      .Lpteloop
        # restore PDE index
        mov     -4(%ebp), %ecx
.Lskippde:
        inc     %ecx
        cmp     $1024, %ecx
        jb      .Lpdeloop

        popa
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
        pusha

        lea     pagemsg, %edi           # pointer to output string
        mov     $8, %ecx                # number of output digits
        call    int_to_hex

        mov     %edx, %eax
        lea     pagemsg+10, %edi        # pointer to output string
        mov     $8, %ecx                # number of output digits
        call    int_to_hex

        call    get_pg_flags
        movl    %eax, pagemsg+19

        lea     pagemsg, %esi           # message-offset
        mov     $pagemsg_len, %ecx      # message-length
        call    screen_write

        popa
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
        push    %edx

        mov     %eax, %edx
        and     $0xfff, %edx
        mov     $0x2e202020, %eax
        test    $1, %edx             # check 'present' bit
        jz      .Lget_pg_flags_end
        mov     $'P', %al
        shl     $8, %eax
        mov     $'R', %al
        test    $2, %edx             # check 'read/write' bit
        jz      .Lread_only
        mov     $'W', %al
.Lread_only:
        shl     $8, %eax
        mov     $'a', %al
        test    $1<<5, %edx          # check 'accessed' bit
        jz      .Lnot_accessed
        mov     $'A', %al
.Lnot_accessed:
        shl     $8, %eax
        mov     $'d', %al
        test    $1<<6, %edx          # check 'dirty' bit
        jz      .Lget_pg_flags_end
        mov     $'D', %al
        jmp     .Lget_pg_flags_end

.Ltable_not_mapped:
        mov     $0x20202020, %eax

.Lget_pg_flags_end:

        pop     %edx
        leave
        ret


        .type   get_page_addr, @function
get_page_addr:
        enter   $4, $0
        push    %edx
        push    %esi

        # get page directory address
        mov     %cr3, %esi
        # segmented page directory address
        sub     $LD_DATA_START, %esi

        # store linear address on stack
        mov     %eax, -4(%ebp)
        mov     %eax, %edx
        # initialise default return value
        xor     %eax, %eax

        # get page directory entry
        shr     $22, %edx
        # PDE #0 is reserved for the Kernel
        test    %edx, %edx
        jz      .Lget_page_addr_end

        mov     (%esi,%edx,4), %esi
        test    $1, %esi
        jz      .Lget_page_addr_end

        mov     -4(%ebp), %edx
        shr     $12, %edx
        and     $0x3ff, %edx
        and     $0xfffff000, %esi
        lea     (%esi,%edx,4), %esi
        # segmented page table address
        sub     $LD_DATA_START, %esi
        mov     (%esi), %edx
        test    $1, %edx
        jz      .Lget_page_addr_end

        # load linear address from stack
        mov     -4(%ebp), %eax
        # mask page offset
        and     $0xfffff000, %eax

.Lget_page_addr_end:
        pop     %esi
        pop     %edx
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
        push    %edx

        xor     %eax, %eax
.Lspcloop:
        mov     (%esi), %dl
        test    %dl, %dl
        jz      .Lexit
        cmp     $'\n', %dl
        jz      .Lexit
        cmp     $'\r', %dl
        jz      .Lexit
        inc     %esi
        cmp     $' ', %dl
        je      .Lspcloop
        dec     %esi
.Lhexloop:
        mov     (%esi), %dl
        test    %dl, %dl
        jz      .Lexit
        cmp     $'\n', %dl
        jz      .Lexit
        cmp     $'\r', %dl
        jz      .Lexit
        cmp     $' ', %dl
        jz      .Lexit
        cmp     $0, %dl
        jb      .Lexit
        # dl >= '0'
        cmp     $'f', %dl
        ja      .Lexit
        # dl >= '0' && dl <= 'f'
        cmp     $'9', %dl
        mov     $'0', %dh
        jbe     .Lconv_digit     # dl >= '0' && dl <= '9'
        # dl > '9' && dl <= 'f'
        cmp     $'A', %dl
        jb      .Lexit
        # dl >= 'A' && dl <= 'f'
        cmp     $'F', %dl
        mov     $'A'-10, %dh
        jbe     .Lconv_digit     # dl => 'A' && dl <= 'F'
        # dl > 'F' && dl <= 'f'
        cmp     $'a', %dl
        jb      .Lexit
        # dl >= 'a' && dl <= 'f'
        mov     $'a'-10, %dh
.Lconv_digit:
        sub     %dh, %dl        # convert hex digit to int 0..15
        shl     $4, %eax        # multiply result by 16
        movzxb  %dl, %edx
        add     %edx, %eax      # add digit value to result
        inc     %esi
        jmp     .Lhexloop
.Lexit:
        inc     %esi
        pop     %edx
        leave
        ret

