
#==================================================================
#=========  TRAP-HANDLER FOR GENERAL PROTECTION FAULTS  ===========
#==================================================================
#
#-----------------------------------------------------------------
# Stack Frame Layout
#-----------------------------------------------------------------
#
#                 Byte 0
#                      V
#    +-----------------+
#    |     EFLAGS      |  +64
#    +-----------------+
#    |       CS        |  +60
#    +-----------------+
#    |       EIP       |  +56
#    +-----------------+
#    |    Error Code   |  +52
#    +-----------------+
#    |      INT ID     |  +48
#    +-----------------+
#    |   General Regs  |
#    | EAX ECX EDX EBX |  +32
#    | ESP EBP ESI EDI |  +16
#    +-----------------+
#    |  Segment  Regs  |
#    |   DS ES FS GS   |  <-- ebp
#    +=================+
#
#-----------------------------------------------------------------
        .section    .text
        .type       isrGPF, @function
        .globl      isrGPF
        .extern     bail_out
        .code32
        .align   16
#------------------------------------------------------------------
isrGPF:
        #----------------------------------------------------------
        # push interrupt id onto stack for register/stack dump
        # 13: General Protection Fault Exception (With Error Code!)
        #----------------------------------------------------------
        pushl   $13

        #-----------------------------------------------------------
        # push general-purpose and all data segment registers onto
        # stack in order to preserve their value and also for display
        #-----------------------------------------------------------
        pushal
        pushl   %ds
        pushl   %es
        pushl   %fs
        pushl   %gs
        mov     %esp, %ebp              # store current stack pointer

        #----------------------------------------------------------
        # setup segment registers
        #----------------------------------------------------------
        mov     $privDS, %ax
        mov     %ax, %ds

        #-----------------------------------------------------------
        # pick the stack segment descriptor-table
        #-----------------------------------------------------------
        lea     theGDT, %ebx            # EBX = offset for GDT
        mov     %ss, %ecx               # copy selector to ECX
        and     $0xFFF8, %ecx           # isolate selector-index

        #-----------------------------------------------------------
        # extract the stack segment descriptor's limit in order to
        # determine how many bytes starting at SS:ESP we can read
        # without violating the limit
        #-----------------------------------------------------------
        mov     4(%ebx, %ecx), %eax
        and     $0x000f0000, %eax
        mov     0(%ebx, %ecx), %ax

        #----------------------------------------------------------
        # print register values
        #----------------------------------------------------------
        pushl   $1<<14+1<<15            # highlight CS:EIP registers
        pushl   $50
        pushl   $0x9e7070
        pushl   $INT_NUM-2
        pushl   $0
        pushl   $intname
        pushl   %ebp
        call    print_stacktrace
        add     $7*4, %esp

        pushl   $0
        pushl   $35
        pushl   $0x9e7070
        pushl   $STK_NUM
        pushl   $0
        pushl   $stkname
        mov     28(%ebp), %eax
        add     $20, %eax
        pushl   %eax
        call    print_stacktrace
        add     $7*4, %esp

        #----------------------------------------------------------
        # restore the values to the registers we've modified here
        #----------------------------------------------------------
        popl    %gs
        popl    %fs
        popl    %es
        popl    %ds
        popal

        #----------------------------------------------------------
        # remove interrupt id from stack
        #----------------------------------------------------------
        add     $4, %esp

        jmp     bail_out

