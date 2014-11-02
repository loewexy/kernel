#-----------------------------------------------------------------
#
# elfexec.s
#
#
# Here we will simulate 'loading' of an executable ELF-file
# at its intended load-address in extended physical memory.
# At the outset our segment-descriptor for application code
# (in the Global Descriptor Table) is marked 'Not Present',
# so that actual initialization of the memory-contents will
# be deferred until a 'Segment Not Present' fault occurs at
# the point where the first instruction-fetch is attempted.
#
# The executable ELF file-image (e.g., 'demoapp') needs to
# be preinstalled on our disk image starting at block 130,
# so that our boot loader will read it into memory putting
# it at linear address 0x00018000.
#
# Later, those portions of the ELF file-image which need to
# reside during execution at higher addresses (i.e., in the
# PC's 'Extended' memory, above 1-MB) will be 'loaded' when
# our 'Segment-Not-Present' fault-handler gets executed, as
# a result of the initial attempt to transfer out to ring3.
#
# $Id: elfexec.s,v 1.4 2014/03/25 00:18:23 ralf Exp ralf $
#
#-----------------------------------------------------------------
# Original version based on elfexec.s written by Allan Cruse,
# University of San Francisco, Course CS 630, Fall 2008
#-----------------------------------------------------------------


#-----------------------------------------------------------------
# M A C R O S
#-----------------------------------------------------------------
    .macro  INSTALL_ISR id handler
        pushl   $\handler               # push pointer to handler
        pushl   $\id                    # push interrupt-ID
        call    register_isr
        add     $8, %esp
    .endm

    .macro  INSTALL_IRQ id handler
        pushl   $\handler               # push pointer to handler
        pushl   $\id+0x20               # push interrupt-ID
        call    register_isr
        add     $8, %esp
    .endm


#-----------------------------------------------------------------
# C O N S T A N T S
#-----------------------------------------------------------------
        # equates for Elf32 file-format (derived from 'elf.h')
        .equ    ELF_SIG,  0x464C457F    # ELF-file's 'signature'
        .equ    ELF_32,            1    # Elf_32 file format
        .equ    ET_EXEC,           2    # Executable file type
        .equ    e_ident,        0x00    # offset to ELF signature
        .equ    e_class,        0x04    # offset to file class
        .equ    e_type,         0x10    # offset to (TYPE,MACHINE)
        .equ    e_entry,        0x18    # offset to entry address
        .equ    e_phoff,        0x1C    # offset to PHT file-offset
        .equ    e_phentsize,    0x2A    # offset to PHT entry size
        .equ    e_phnum,        0x2C    # offset to PHT entry count
        .equ    PT_LOAD,           1    # Loadable program segment
        .equ    p_type,         0x00    # offset to segment type
        .equ    p_offset,       0x04    # offset to seg file-offset
        .equ    p_paddr,        0x0C    # offset to seg phys addr
        .equ    p_filesz,       0x10    # offset to seg size in file
        .equ    p_memsz,        0x14    # offset to seg size in mem

        .equ    IRQ_PIT_ID,     0x00
        .equ    IRQ_KBD_ID,     0x01
        .equ    ISR_DBG_ID,     0x01
        .equ    ISR_SNP_ID,     0x0B


#==================================================================
# S I G N A T U R E
#==================================================================
        .section        .signature, "a", @progbits
        .word   signame_size
signame:.ascii  "ELFEXEC"
        .equ    signame_size, (.-signame)
        .byte   0


#==================================================================
# S E C T I O N   D A T A
#==================================================================
        .section        .data

#------------------------------------------------------------------
# G L O B A L   D E S C R I P T O R   T A B L E
#------------------------------------------------------------------
        .align  16
        .global theGDT
theGDT:
        .include "comgdt.inc"
        #----------------------------------------------------------
        # Code/Data, 32 bit, Byte, Priv 0, Type 0x00, 'Read-Only'
        # Base Address: 0x00018000   Limit: 0x0000ffff
        .equ    sel_fs, (.-theGDT)+0    # selector for file-image
        .globl  sel_fs
        .quad   0x004090018000FFFF      # file segment-descriptor
        #----------------------------------------------------------
        # Code/Data, 32 bit, 4kB, Priv 3, Type 0x0a, 'Execute/Read'
        # Base Address: 0x00000000   Limit: 0x0001ffff
        .equ    userCS, (.-theGDT)+3    # selector for ring3 code
        .globl  userCS
        .quad   0x00C17A000000FFFF      # code segment-descriptor
        #----------------------------------------------------------
        # Code/Data, 32 bit, 4kB, Priv 3, Type 0x02, 'Read/Write'
        # Base Address: 0x00000000   Limit: 0x0001ffff
        .equ    userDS, (.-theGDT)+3    # selector for ring3 data
        .globl  userDS
        .quad   0x00C1F2000000FFFF      # data segment-descriptor
        #----------------------------------------------------------
        .equ    selTSS, (.-theGDT)+0    # selector for Task-State
        .word   limTSS, theTSS+0x2000, 0x8901, 0x0000  # task descriptor
        #----------------------------------------------------------
        .equ    limGDT, (. - theGDT)-1  # our GDT's segment-limit
#------------------------------------------------------------------
        # image for GDTR register
        .align  16
        .global regGDT
regGDT: .word   limGDT
        .long   theGDT+0x12000          # create linear address
#------------------------------------------------------------------
# T A S K   S T A T E   S E G M E N T S
#------------------------------------------------------------------
        .align  16
theTSS: .long   0x00000000              # back-link field (unused)
        .long   0x00010000              # stacktop for Ring0 stack
        .long   privDS                  # selector for Ring0 stack
        .zero   0x68-((.-theTSS))
        .equ    limTSS, (.-theTSS)-1    # this TSS's segment-limit
#------------------------------------------------------------------
tossav: .space  6                       # 48-bit pointer ss:esp
#------------------------------------------------------------------

#==================================================================
# S E C T I O N   T E X T
#==================================================================
        .section        .text
        .code32
#------------------------------------------------------------------
        .type   main, @function
        .global main
main:
        #----------------------------------------------------------
        # save stack-address (we use it when returning to 'start')
        # use stack segment selector in order to have write access
        #----------------------------------------------------------
        mov     %esp, tossav+0
        mov     %ss,  tossav+4

        #----------------------------------------------------------
        # establish our Task-State Segment and a new ring-0 stack
        #----------------------------------------------------------
        mov     $selTSS, %ax
        ltr     %ax
        lss     theTSS+4, %esp

        #----------------------------------------------------------
        # install private exception handlers
        #----------------------------------------------------------
        INSTALL_IRQ IRQ_PIT_ID, irqPIT
        INSTALL_IRQ IRQ_KBD_ID, irqKBD
        INSTALL_ISR ISR_DBG_ID, isrDBG
        INSTALL_ISR ISR_SNP_ID, isrSNP

        #----------------------------------------------------------
        # reprogram PICs and enable hardware interrupts
        #----------------------------------------------------------
        call    remap_isr_pm
        sti

        #----------------------------------------------------------
        # verify ELF file's presence and 32-bit 'executable'.
        # address the elf headers using the FS segment register
        #----------------------------------------------------------
        mov     $sel_fs, %ax
        mov     %ax, %fs
        cmpl    $ELF_SIG, %fs:e_ident   # check ELF-file signature
        jne     elf_error               #   no, handle elf error
        cmpb    $ELF_32, %fs:e_class    # check file class is 32-bit
        jne     elf_error               #   no, handle elf error
        cmpw    $ET_EXEC, %fs:e_type    # check type is 'executable'
        jne     elf_error               #   no, handle elf error

        #----------------------------------------------------------
        # setup segment-registers for the Linux application
        #----------------------------------------------------------
        mov     $userDS, %ax
        mov     %ax, %ds
        mov     %ax, %es

        #----------------------------------------------------------
        # clear general registers for the Linux application
        #----------------------------------------------------------
        xor     %eax, %eax
        xor     %ebx, %ebx
        xor     %ecx, %ecx
        xor     %edx, %edx
        xor     %ebp, %ebp
        xor     %esi, %esi
        xor     %edi, %edi

        #----------------------------------------------------------
        # transfer control to the Linux application in ring3
        #----------------------------------------------------------
        pushl   $userDS                 # selector for 'data'
        pushl   $0x00040000             # top of ring's stack
        pushl   $userCS                 # selector for 'code'
        pushl   %fs:e_entry             # program entry-point

        #----------------------------------------------------------
        # set the TF-bit in FLAGS register just prior to 'lret'
        #----------------------------------------------------------
        pushf                           # push current FLAGS
        btsw    $8, (%esp)              # set image of TF-bit
        popf                            # pop modified FLAGS
        #----------------------------------------------------------
        # transfer to user program
        #----------------------------------------------------------
        lret

elf_error:

finis:
        #-----------------------------------------------------------
        # disable hardware interrupts
        #-----------------------------------------------------------
        cli

        #-----------------------------------------------------------
        # load appropriate ring0 data segment descriptor
        #-----------------------------------------------------------
        mov     $privDS, %ax
        mov     %ax, %ds

        #-----------------------------------------------------------
        # reprogram PICs to their original setting
        #-----------------------------------------------------------
        call    remap_isr_rm

        #-----------------------------------------------------------
        # recover former stack
        #-----------------------------------------------------------
        lss     tossav, %esp

        ret

#------------------------------------------------------------------
        .section        .data
        .align   4
finmsg: .ascii  "\n\nProgram finished. "
        .ascii  "Press any key to return to bootloader\n"
        .equ    finmsglen, (. - finmsg) # message-length
#------------------------------------------------------------------
        .section        .text
        .code32
        .type    bail_out, @function
        .global  bail_out
        .align   16
bail_out:
        #-----------------------------------------------------------
        # load ring0 data segment descriptor
        #-----------------------------------------------------------
        mov     $privDS, %ax
        mov     %ax, %ds
        #-----------------------------------------------------------
        # print out program completion message
        #-----------------------------------------------------------
        lea     finmsg, %esi
        mov     $finmsglen, %ecx
        call    screen_write

        #----------------------------------------------------------
        # now await the release of a user's keypress
        #----------------------------------------------------------
        sti
waitkey:
        hlt
        cmp     $0, (lastkey)
        je      waitkey

        #----------------------------------------------------------
        # terminate this demo
        #----------------------------------------------------------
        ljmp    $privCS, $finis
#------------------------------------------------------------------


#==================================================================
#========  TRAP-HANDLER FOR SEGMENT-NOT-READY EXCEPTIONS  =========
#==================================================================
#
#-----------------------------------------------------------------
# Stack Frame Layout
#-----------------------------------------------------------------
#
#                 Byte 0
#                      V
#    +-----------------+
#    |       SS        |  +72
#    +-----------------+
#    |       ESP       |  +68
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
#    |   DS ES FS GS   |  <-- 8(%ebp)
#    +=================+
#    |  Int Stack Ptr  |  +8
#    +-----------------+
#    |  Return Address |  +4
#    +-----------------+
#    |       EBP       |  <-- ebp
#    +=================+
#
#
# Selector Error Code
#    31         16   15         3   2   1   0
#   +---+--  --+---+---+--  --+---+---+---+---+
#   |   Reserved   |    Index     |  Tbl  | E |
#   +---+--  --+---+---+--  --+---+---+---+---+
#
#-----------------------------------------------------------------
        .section        .text
        .code32
        .type   isrSNP, @function
        .global isrSNP
        .align   16
isrSNP:
        #-----------------------------------------------------------
        # setup stack frame access via ebp
        #-----------------------------------------------------------
        enter   $0, $0

        #-----------------------------------------------------------
        # setup segment-registers for 'loading' program-segments
        #-----------------------------------------------------------
        mov     $sel_fs, %ax            # address ELF file-image
        mov     %ax, %ds                #    with DS register
        mov     $userDS, %ax            # address entire memory
        mov     %ax, %es                #    with ES register
        cld                             # do forward processing

        #-----------------------------------------------------------
        # extract load-information from the ELF-file's image
        #-----------------------------------------------------------
        mov     e_phoff, %ebx       # segment-table's offset
        movzxw  e_phnum, %ecx       # count of table entries
        movzxw  e_phentsize, %edx   # length of table entries

nxseg:
        push    %ecx                    # save outer loop-counter
        mov     p_type(%ebx), %eax      # get program-segment type
        cmp     $PT_LOAD, %eax          # segment-type 'LOADABLE'?
        jne     fillx                   # no, loading isn't needed
        mov     p_offset(%ebx), %esi    # DS:ESI is segment-source
        mov     p_paddr(%ebx), %edi     # ES:EDI is desired address
        mov     p_filesz(%ebx), %ecx    # ECX is length for copying
        jecxz   copyx                   # maybe copying is skipped
        rep     movsb                   # 'load' program-segment
copyx:
        mov     p_memsz(%ebx), %ecx     # segment-size in memory
        sub     p_filesz(%ebx), %ecx    # minus its size in file
        jecxz   fillx                   # maybe fill is unneeded
        xor     %al, %al                # use zero for filling
        rep     stosb                   # clear leftover space
fillx:
        pop     %ecx                    # recover outer counter
        add     %edx, %ebx              # advance to next record
        loop    nxseg                   # process another record

        #-----------------------------------------------------------
        # now mark segment-descriptor as 'present'
        #-----------------------------------------------------------
        mov     $privDS, %ax            # address GDT descriptors
        mov     %ax, %ds                #  using the DS register
        lea     theGDT, %ebx            # DS:EBX = our GDT's base
        mov     8(%ebp), %ecx           # read ISR stack frame ptr
        mov     52(%ecx), %eax          # get fault's error-code
        and     $0xFFF8, %eax           # isolate its index-field
        btsw    $15, 4(%ebx, %eax, 1)   # set P-bit in descriptor

        leave
        ret


#==================================================================
#===========  TRAP-HANDLER FOR SINGLE-STEP EXCEPTIONS  ============
#==================================================================
#
#-----------------------------------------------------------------
# Stack Frame Layout
#-----------------------------------------------------------------
#
#                 Byte 0
#                      V
#    +-----------------+
#    |       SS        |  +72
#    +-----------------+
#    |       ESP       |  +68
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
#    |   DS ES FS GS   |  <-- edx
#    +=================+
#    |  Int Stack Ptr  |  +8
#    +-----------------+
#    |  Return Address |  +4
#    +-----------------+
#    |       EBP       |  <-- ebp
#    +=================+
#    | DR7             |   -4
#    +-----------------+
#    | DR6             |   -8
#    +-----------------+
#    | DR1             |  -12
#    +-----------------+
#    | DR0             |  -16
#    +-----------------+
#
#-----------------------------------------------------------------
        .section        .data
        .align   4
preval1:.space  20 * 4, 0
preval2:.space   4 * 4, 0
#-----------------------------------------------------------------
        .section        .text
        .code32
        .extern         get_flags_str
        .extern         wait_keypress
        .type   isrDBG, @function
        .global         isrDBG
        .align   16
isrDBG:
        #-----------------------------------------------------------
        # ISR stub disables interrupts, so we need to re-enable them
        # in order to be able to capture keybaord interrupts while
        # waiting in this handler. This is probably not the most sane
        # solution...
        #-----------------------------------------------------------
        sti

        #-----------------------------------------------------------
        # setup stack frame access via ebp
        #-----------------------------------------------------------
        enter   $0, $0
        mov     8(%ebp), %edx           # read ISR stack frame ptr

        #-----------------------------------------------------------
        # ok, let's display the Debug Registers, too
        #-----------------------------------------------------------
        mov     %dr7, %eax
        push    %eax                    # push value from DR7
        mov     %dr6, %eax
        push    %eax                    # push value from DR6
        mov     %dr1, %eax
        push    %eax                    # push value from DR1
        mov     %dr0, %eax
        push    %eax                    # push value from DR0

        #-----------------------------------------------------------
        # address ring0 data segment with DS register
        #-----------------------------------------------------------
        mov     $privDS, %ax            # address data segment
        mov     %ax, %ds                #   with DS register

        #-----------------------------------------------------------
        # examine the Debug Status Register DR6
        #-----------------------------------------------------------
        mov     %dr6, %eax              # examine register DR6
        test    $0x0000000F, %eax       # any breakpoints?
        jz      nobpt                   # no, keep RF-flag
        btsl    $16, %ss:64(%edx)       # else set RF-flag
nobpt:
        #-----------------------------------------------------------
        # load CS:EIP return address stored on stack into FS:ESI
        #-----------------------------------------------------------
        lfs     %ss:56(%edx), %esi

        #-----------------------------------------------------------
        # pick the selector's descriptor-table
        #-----------------------------------------------------------
        lea     theGDT, %ebx            # EBX = offset for GDT
        mov     %fs, %ecx               # copy selector to ECX
        and     $0xFFF8, %ecx           # isolate selector-index

        #-----------------------------------------------------------
        # extract the FS segment descriptor's limit in order to
        # determine how many instructions bytes starting at
        # FS:ESI we can read without violating the limit
        #-----------------------------------------------------------
        mov     4(%ebx, %ecx), %eax
        and     $0x000f0000, %eax
        mov     0(%ebx, %ecx), %ax

        #-----------------------------------------------------------
        # fetch next four opcode-bytes starting at the interrupted
        # location and write them to the stack for display. On the
        # stack, we use the location of the error code, which is not
        # set by the trap exception
        #-----------------------------------------------------------
        mov     %fs:(%esi), %eax
        mov     %eax, %ss:52(%edx)

        #-----------------------------------------------------------
        # set breakpoint trap after any 'int-nn' instruction
        #-----------------------------------------------------------
        cmp     $0xCD, %al              # opcode is 'int-nn'?
        jne     nobrk                   # no, don't set breakpoint
        add     $2, %esi                # else point past 'int-nn'

        #-----------------------------------------------------------
        # extract the DS segment descriptor's base-address and
        # use it to compute linear-address of the instruction at
        # FS:ESI
        #-----------------------------------------------------------
        mov     0(%ebx, %ecx), %eax     # descriptor[31..0]
        mov     4(%ebx, %ecx), %al      # descriptor[39..32]
        mov     7(%ebx, %ecx), %ah      # descriptor[63..54]
        rol     $16, %eax               # segment's base-address

        #-----------------------------------------------------------
        # setup the instruction-breakpoint in DR0
        #-----------------------------------------------------------
        add     %eax, %esi              # add segbase to offset
        mov     %esi, %dr0              # breakpoint into DR0
        mov     %esi, -16(%ebp)         # and also update DR0 on the stack

        #-----------------------------------------------------------
        # activate the code-breakpoint in register DR0
        #-----------------------------------------------------------
        mov     %dr7, %eax              # get current DR7 settings
        and     $0xFFF0FFFC, %eax       # clear the G0 and L0 bits
        or      $0x00000001, %eax       # enable L0 code-breakpoint
        mov     %eax, %dr7              # update settings in DR7
        mov     %eax, -4(%ebp)          # and also update DR7 on the stack
        jmp     printstack

nobrk:
        #-----------------------------------------------------------
        # clear instruction-breakpoint address in DR0
        #-----------------------------------------------------------
        xor     %eax, %eax
        mov     %eax, %dr0
        #-----------------------------------------------------------
        # clear the G0 and L0 bits in DR7
        #-----------------------------------------------------------
        mov     %dr7, %eax
        and     $0xFFF0FFFC, %eax
        mov     %eax, %dr7
        #-----------------------------------------------------------
        # NOTE: do not update DR0 and DR7 on the stack now as this
        # would prevent correct display of the breakpoint address and
        # status when the breakpoint is hit.
        #-----------------------------------------------------------

printstack:
        pushl   $0                      # do not highlight any registers
        pushl   $65
        pushl   $0x9e0faf               # white,green   white, black
        pushl   $INT_NUM
        pushl   $preval1
        pushl   $intname
        pushl   %edx
        call    print_stacktrace

        #-----------------------------------------------------------
        # highlight breakpoints in register DR6
        #-----------------------------------------------------------
        mov     %dr6, %eax
        and     $0x00000003, %eax
        pushl   %eax
        pushl   $50
        pushl   $0x9e0faf               # white,green   white, black
        pushl   $DBG_NUM
        pushl   $preval2
        pushl   $dbgname
        lea     -16(%ebp), %eax
        pushl   %eax
        call    print_stacktrace

        #-----------------------------------------------------------
        # now await the release of a user's keypress
        #-----------------------------------------------------------
pollkey:
        hlt
        cmp     $0, (lastkey)
        je      pollkey
        cmp     $'r', (lastkey)
        jne     norun

        #-----------------------------------------------------------
        # disable any active debug-breakpoints and clear TF-Flag,
        # in order that the remainder of the loaded program will be
        # executed until its end without single-stepping
        #-----------------------------------------------------------
        xor     %eax, %eax              # clear general register
        mov     %eax, %dr7              # and load zero into DR7
        btrl    $8, 64(%edx)            # clear Trap Flag
norun:
        movb    $0, (lastkey)

        leave
        ret


#==================================================================
#===========        HANDLER FOR TIMER INTERRUPTS       ============
#==================================================================
#
# Here is our code for handing timer-interrupts while the CPU is
# executing in 'protected-mode'; it follows closely the original
# 'real-mode' Interrupt-Service Routine used in the IBM-PC BIOS,
#
#-----------------------------------------------------------------
# EQUATES for timing-constants and for ROM-BIOS address-offsets
#-----------------------------------------------------------------
        .equ    HOURS24, 0x180000       # number of ticks-per-day
        .equ    N_TICKS, 0x006C         # offset for tick-counter
        .equ    TM_OVFL, 0x0070         # offset of rollover-flag
        .equ    PULSES_PER_SEC, 1193182 # timer input-frequency
        .equ    PULSES_PER_TICK, 65536  # BIOS frequency-divisor
        .equ    SECS_PER_MIN, 60        # seconds per minute
        .equ    SECS_PER_HOUR, 60*SECS_PER_MIN # seconds per hour
        .equ    SECS_PER_DAY, 24*SECS_PER_HOUR # seconds per day
#-----------------------------------------------------------------
        .section        .data
        .align   4
status: .ascii  "00:00:00"
        .ascii  "                                        "
        .ascii  "                                        "
        .globl  ticks
ticks:  .long   0
prevticks: .long   0
#-----------------------------------------------------------------
        .section        .text
        .code32
        .type   irqPIT, @function
        .global irqPIT
        .align   16
irqPIT:
        enter   $0, $0

        #-----------------------------------------------------------
        # increment the 32-bit counter for timer-tick interrupts
        #-----------------------------------------------------------
        incl    %fs:N_TICKS             # increment tick-count
        cmpl    $HOURS24, %fs:N_TICKS   # past midnight?
        jl      isok                    # no, don't rollover yet
        movl    $0, %fs:N_TICKS         # else reset count to 0
        movb    $1, %fs:TM_OVFL         # and set rollover flag
isok:

        #-----------------------------------------------------------
        # calculate total seconds (= N_TICKS * 65536 / 1193182)
        #-----------------------------------------------------------
        mov     %fs:N_TICKS, %eax       # setup the multiplicand
        mov     $PULSES_PER_TICK, %ecx  # setup the multiplier
        mul     %ecx                    # 64 bit product is in (EDX,EAX)
        mov     $PULSES_PER_SEC, %ecx   # setup the divisor
        div     %ecx                    # quotient is left in EAX

        #--------------------------------------------------------
        # ok, now we 'round' the quotient to the nearest integer
        #--------------------------------------------------------
        # rounding-rule:
        #       if  ( remainder >= (1/2)*divisor )
        #          then increment the quotient
        #--------------------------------------------------------
        add     %edx, %edx      # EDX = twice the remainder
        sub     %ecx, %edx      # CF=1 if 2*rem < divisor
        cmc                     # CF=1 if 2*rem >= divisor
        adc     $0, %eax        # ++EAX if 2+rem >= divisor
        mov     %eax, ticks

        cmp     %eax, prevticks
        je      skip_update

        mov     %eax, prevticks

        mov     $SECS_PER_DAY, %ebx
        xor     %edx, %edx
        div     %ebx

        #-----------------------------------------------------------
        # calculate the number of hours
        #-----------------------------------------------------------
        mov     %edx, %eax
        xor     %edx, %edx
        mov     $SECS_PER_HOUR, %ebx
        div     %ebx
        #-----------------------------------------------------------
        # convert decimal hours value into two-digit BCD
        #-----------------------------------------------------------
        mov     $10, %bl
        lea     status, %edi
        div     %bl    # div ax by bl -> al: quotient, ah: remainder
        add     $0x3030, %ax    # convert al and ah to BCD digits
        mov     %ax, (%edi)

        #-----------------------------------------------------------
        # calculate the number of minutes
        #-----------------------------------------------------------
        mov     %edx, %eax
        xor     %edx, %edx
        mov     $SECS_PER_MIN, %ebx
        div     %ebx
        #-----------------------------------------------------------
        # convert decimal minutes value into two-digit BCD
        #-----------------------------------------------------------
        mov     $10, %bl
        lea     status+3, %edi
        div     %bl    # div ax by bl -> al: quotient, ah: remainder
        add     $0x3030, %ax    # convert al and ah to BCD digits
        mov     %ax, (%edi)
        #-----------------------------------------------------------
        # finally, convert decimal seconds value into two-digit BCD
        #-----------------------------------------------------------
        mov     $10, %bl
        mov     %edx, %eax
        lea     status+6, %edi
        div     %bl    # div ax by bl -> al: quotient, ah: remainder
        add     $0x3030, %ax    # convert al and ah to BCD digits
        mov     %ax, (%edi)

        #-----------------------------------------------------------
        # loop to write character-codes to the screen
        #-----------------------------------------------------------
        lea     status, %esi            # message-offset into ESI
        mov     $160*24, %edi
        mov     $79, %ecx               # message-length into ECX
        cld
        mov     $0x7020, %ax            # normal text attribute
cpchr:  lodsb                           # fetch next character
        stosw                           # write to the display
        loop    cpchr

skip_update:
        leave
        ret


#==================================================================
#===========      HANDLER FOR KEYBOARD INTERRUPTS      ============
#==================================================================
        .section        .data
        .align   4
lastkey:.byte   0
        .section        .text
        .code32
        .type   irqKBD, @function
        .global irqKBD
        .align   16
irqKBD:
        #-----------------------------------------------------------
        # preserve all registers, including modified segment registers
        #-----------------------------------------------------------
        enter   $0, $0

        in      $0x64, %al              # poll keyboard status
        test    $0x01, %al              # new scancode ready?
        jz      ignore                  # no, false alarm

        in      $0x60, %al              # input the new scancode
        test    $0x80, %al              # was a key released?
        jz      ignore                  # no, wait for a release
        and     $0x0000007f, %eax       # mask for 7-bit ASCII
        mov     kbdus(%eax), %al        # translate scancode into ASCII
        mov     %al, (lastkey)
ignore:
        leave
        ret

#------------------------------------------------------------------
        .end
#------------------------------------------------------------------

