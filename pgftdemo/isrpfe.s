
#==================================================================
#=========    TRAP-HANDLER FOR PAGE-FAULT EXCEPTIONS    ===========
#==================================================================
#
#-----------------------------------------------------------------
# Stack Frame Layout
#-----------------------------------------------------------------
#
#                 Byte 0
#                      V
#    +-----------------+
#    |     EFLAGS      |  +76
#    +-----------------+
#    |       CS        |  +72
#    +-----------------+
#    |       EIP       |  +68
#    +-----------------+
#    |    Error Code   |  +64
#    +-----------------+
#    |      INT ID     |  +60
#    +-----------------+
#    |   General Regs  |
#    | EAX ECX EDX EBX |  +44
#    | ESP EBP ESI EDI |  +28
#    +-----------------+
#    |  Segment  Regs  |
#    |   DS ES FS GS   |  +12
#    +=================+
#    |  Int Stack Ptr  |   +8
#    +-----------------+
#    |  Return Address |   +4
#    +-----------------+
#    |       EBP       |  <-- ebp
#    +-----------------+
#-----------------------------------------------------------------

#-----------------------------------------------------------------
# S E C T I O N   D A T A
#-----------------------------------------------------------------
        .section    .data
        #----------------------------------------------------------
        # output string for faulting address and physical address
        #----------------------------------------------------------
pgftmsg:
        .ascii  "Page fault @ 0x"
pgftaddr:
        .ascii  "________ (EIP 0x"
eipaddr:
        .ascii  "________) -> "
pgphaddr:
        .ascii  "________ "
pgvicaddr:
        .ascii  "________ "
pgsecaddr:
        .ascii  "________"
        .ascii  "\n"
        .equ    pgftmsg_len, (.-pgftmsg)

        .align  4
pgftcnt:.long   0   # counts how many page faults have occured

#-----------------------------------------------------------------
# S E C T I O N   T E X T
#-----------------------------------------------------------------
        .section    .text
        .type       isrPFE, @function
        .globl      isrPFE
        .extern     int_to_hex
        .extern     screen_write
        .extern     pfhandler
        .code32
        .align   16
#------------------------------------------------------------------
isrPFE:
        #-----------------------------------------------------------
        # setup stack frame access via ebp and use edx to access
        # caller stack frame
        #-----------------------------------------------------------
        enter   $0, $0

        #----------------------------------------------------------
        # setup data segment register
        #----------------------------------------------------------
        mov     $privDS, %ax
        mov     %ax, %ds

        #----------------------------------------------------------
        # setup GS segment register for linear addressing
        #----------------------------------------------------------
        mov     $linDS, %ax
        mov     %ax, %gs

        #----------------------------------------------------------
        # update page fault counter
        #----------------------------------------------------------
        incl    (pgftcnt)
        testb   $1, 64(%ebp)            # pf caused by not present page?
        jnz     .Lprotviol

        mov     %cr2, %eax              # faulting address
        invlpg  %gs:(%eax)              # invalidate TLB
        lea     pgftaddr, %edi
        mov     $8, %ecx
        call    int_to_hex

        mov     %cr2, %eax              # faulting address
        invlpg  (%eax)                  # invalidate TLB
        pushl   %eax
        call    pfhandler
        add     $4, %esp

        mov     %eax, %ebx
        mov     16(%ebx), %eax          # get physical address
        lea     pgphaddr, %edi
        mov     $8, %ecx
        call    int_to_hex

        mov     24(%ebx), %eax          # victim page address
        invlpg  %gs:(%eax)              # invalidate TLB
        lea     pgvicaddr, %edi
        mov     $8, %ecx
        call    int_to_hex

        mov     28(%ebx), %eax          # storage address
        lea     pgsecaddr, %edi
        mov     $8, %ecx
        call    int_to_hex

        mov     68(%ebp), %eax          # instruction addr
        lea     eipaddr, %edi
        mov     $8, %ecx
        call    int_to_hex

        lea     pgftmsg, %esi           # message-offset into ESI
        mov     $pgftmsg_len, %ecx      # message-length into ECX
        call    screen_write

        #----------------------------------------------------------
        # check wheter the faulting address is now present. If not,
        # something went wrong within the page allocation function.
        #----------------------------------------------------------
        mov     %cr2, %eax              # faulting address
        pushl   %eax
        call    is_page_present
        add     $4, %esp
        test    %eax, %eax              # 1 = page present?
        jz      .Lprotviol              # no, then raise event

        #----------------------------------------------------------
        # just make a simple check of the physical address
        # 0xffffffff indicates that the page fault could not be
        # resolved
        #----------------------------------------------------------
        cmpl    $0xffffffff, 16(%ebx)   # invalid address?
        jne     .Lpfe_exit              # no, then we're done

.Lprotviol:
        #----------------------------------------------------------
        # write the faulting address into the EAX value on the stack
        #----------------------------------------------------------
        mov     %cr2, %eax
        mov     %eax, 56(%ebp)
        #----------------------------------------------------------
        # print register values
        #----------------------------------------------------------
        pushl   $1<<11+1<<13+1<<14       # highlight some registers
        pushl   $50                      # text column
        pushl   $0x9e7070
        pushl   $INT_NUM-2
        pushl   $0
        pushl   $intname
        lea     12(%ebp), %eax
        pushl   %eax
        call    print_stacktrace

        #----------------------------------------------------------
        # modify the interrupt return address on the stack in order
        # to abort the instruction accessing the faulting address
        # and jump to a different code location instead
        #----------------------------------------------------------
        lea     pfcontinue, %eax
        mov     %eax, 68(%ebp)

.Lpfe_exit:
        #-----------------------------------------------------------
        # erase local stack frame and reestablish original stack
        # pointer. Finally, return to caller.
        #-----------------------------------------------------------
        leave
        ret

