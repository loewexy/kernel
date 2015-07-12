
        .equ    selUsr, 0x20

#==================================================================
#==========  TRAP-HANDLER FOR SUPERVISOR CALLS INT 80h  ===========
#==================================================================
        .section        .data
        .align  16
svccnt: .space  N_SYSCALLS * 4, 0
#-------------------------------------------------------------------
        .section    .text
        .type       isrSVC, @function
        .globl      isrSVC
        .code32
#------------------------------------------------------------------
# our jump-table (for dispatching OS system-calls)
        .align      8
sys_call_table:
        .long   do_nothing   #  0
        .long   sys_exit     #  1
        .long   do_nothing   #  2
        .long   do_nothing   #  3
        .long   sys_write    #  4
        .long   do_nothing   #  5
        .long   do_nothing   #  6
        .long   do_nothing   #  7
        .long   do_nothing   #  8
        .long   do_nothing   #  9
        .long   do_nothing   # 10
        .long   do_nothing   # 11
        .long   do_nothing   # 12
        .long   sys_time     # 13
        .equ    N_SYSCALLS, (.-sys_call_table)/4
#------------------------------------------------------------------
        .align   16
isrSVC: .code32  # our dispatcher-routine for OS supervisor calls

        cmp     $N_SYSCALLS, %eax       # ID-number out-of-bounds?
        jb      .Lidok                  # no, then we can use it
        xor     %eax, %eax              # else replace with zero
.Lidok:
        incl    svccnt(,%eax,4)
        jmp     *%cs:sys_call_table(,%eax,4)  # to call handler

#------------------------------------------------------------------
        .align      8
do_nothing:     # for any unimplemented system-calls

        mov     $-1, %eax               # return-value: minus one
        iret                            # resume the calling task

#------------------------------------------------------------------
        .align      8
sys_exit:       # for transfering back to our ring0 code
        .extern bail_out

        # disable any active debug-breakpoints
        xor     %eax, %eax              # clear general register
        mov     %eax, %dr7              # and load zero into DR7
        ljmp    $selUsr, $0
        jmp     bail_out

#------------------------------------------------------------------
        .align      8
sys_write:      # for writing a string to standard output
        .extern screen_write
#
#       EXPECTS:        EBX = ID-number for device (=1)
#                       ECX = offset of message-string
#                       EDX = length of message-string
#
#       RETURNS:        EAX = number of bytes written
#                             (or -1 for any errors)
#
        enter   $0, $0                  # setup stackframe access
        pushal                          # preserve registers

        # check for invalid device-ID
        cmp     $1, %ebx                # device is standard output?
        jne     inval                   # no, return with error-code

        # check for negative message-length
        test    %edx, %edx              # test string length
        jns     argok                   # not negative, proceed with writing
        mov     %edx, -4(%ebp)          # use string length as return value in EAX
        jz      wrxxx                   # zero, no writing needed
        # otherwise string length is negative
inval:  # return to application with the error-code in register EAX
        movl    $-1, -4(%ebp)           # else write -1 as return value in EAX
        jmp     wrxxx                   # and return with error-code

argok:
        mov     -8(%ebp), %esi          # message-offset into ESI
        mov     -12(%ebp), %ecx         # message-length into ECX
        call    screen_write

wrxxx:
        popal
        leave
        iret

#------------------------------------------------------------------
# EQUATES for timing-constants and for ROM-BIOS address-offsets
        .equ    N_TICKS, 0x006C         # offset for tick-counter
        .equ    PULSES_PER_SEC, 1193182 # timer input-frequency
        .equ    PULSES_PER_TICK,  65536 # BIOS frequency-divisor
#------------------------------------------------------------------
        .align      8
sys_time:       # time system call
        .extern     ticks

        pushl   %ds

        mov     $privDS, %ax
        mov     %ax, %ds
        mov     ticks, %eax

        popl    %ds
        iret                    # resume the calling task

