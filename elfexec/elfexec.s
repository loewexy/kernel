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
        movw    $isrDBG, theIDT+0x01*8
        movw    $isrSNP, theIDT+0x0B*8

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
        # disable hardware interrupts
        cli

        # load appropriate ring0 data segment descriptor
        mov     $privDS, %ax
        mov     %ax, %ds

        # reprogram PICs to their original setting
        call    remap_isr_rm

        # recover former stack
        lss     tossav, %esp

        ret

#------------------------------------------------------------------
        .type   bail_out, @function
        .global bail_out
bail_out:
        #----------------------------------------------------------
        # terminate this demo
        #----------------------------------------------------------
        ljmp    $privCS, $finis
#------------------------------------------------------------------


#==================================================================
#========  TRAP-HANDLER FOR SEGMENT-NOT-READY EXCEPTIONS  =========
#==================================================================
        .section        .text
        .code32
        .type   isrSNP, @function
        .global isrSNP
isrSNP:
        enter   $0, $0                  # setup error-code access
        pushal                          # preserve registers
        pushl   %ds
        pushl   %es

        # setup segment-registers for 'loading' program-segments
        mov     $sel_fs, %ax            # address ELF file-image
        mov     %ax, %ds                #    with DS register
        mov     $userDS, %ax            # address entire memory
        mov     %ax, %es                #    with ES register
        cld                             # do forward processing

        # extract load-information from the ELF-file's image
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

        # now mark segment-descriptor as 'present'
        mov     $privDS, %ax            # address GDT descriptors
        mov     %ax, %ds                #  using the DS register
        lea     theGDT, %ebx            # DS:EBX = our GDT's base
        mov     4(%ebp), %eax           # get fault's error-code
        and     $0xFFF8, %eax           # isolate its index-field
        btsw    $15, 4(%ebx, %eax, 1)   # set P-bit in descriptor

        # increment Interrupt counter
        incl    intcnt+0x0B*4

        popl    %es                     # recover saved registers
        popl    %ds
        popal
        leave                           # discard stackframe

        add     $4, %esp                # discard error-code
        iret                            # retry faulting opcode


#==================================================================
#===========  TRAP-HANDLER FOR SINGLE-STEP EXCEPTIONS  ============
#==================================================================
#
#                 Byte 0
#                      V
#    +-----------------+
#    |       SS        |  +68
#    +-----------------+
#    |       ESP       |  +64
#    +-----------------+               +-------------+
#    |     EFLAGS      |  +60          |  ISR Stack  |
#    +-----------------+               |  see left   |  <-- ebp
#    |       CS        |  +56          +-------------+
#    +-----------------+               | DR7         |   -4
#    |       EIP       |  +52          +-------------+
#    +-----------------+               | DR6         |   -8
#    |    Error Code   |  +48          +-------------+
#    +-----------------+               | DR3         |  -12
#    |   General Regs  |               +-------------+
#    | EAX ECX EDX EBX |  +32          | DR2         |  -16
#    | ESP EBP ESI EDI |  +16          +-------------+
#    +-----------------+               | DR1         |  -20
#    |  Segment  Regs  |               +-------------+
#    |   DS ES FS GS   |  <-- ebp      | DR0         |  -24
#    +=================+               +-------------+
#
#-----------------------------------------------------------------
        .section        .data
preval: .space  30 * 4
#-----------------------------------------------------------------
        .section        .text
        .code32
        .extern         get_flags_str
        .extern         wait_keypress
        .type   isrDBG, @function
        .global         isrDBG
isrDBG:
        # push dummy error code onto stack. In this handler, this
        # location will later hold four opcode bytes starting at
        # the interrupted instruction
        pushl   $0

        # push general-purpose and all data segment registers onto
        # stack in order to preserve their value and also for display
        pushal
        pushl   %ds
        pushl   %es
        pushl   %fs
        pushl   %gs

        # setup stackframe pointer. All locations on the stack with
        # negative offset relative to EBP hold registers that are
        # specific to the register dump of this handler
        mov     %esp, %ebp

        # ok, let's display the Debug Registers, too
        mov     %dr7, %eax
        push    %eax                    # push value from DR7
        mov     %dr6, %eax
        push    %eax                    # push value from DR6
        mov     %dr3, %eax
        push    %eax                    # push value from DR3
        mov     %dr2, %eax
        push    %eax                    # push value from DR2
        mov     %dr1, %eax
        push    %eax                    # push value from DR1
        mov     %dr0, %eax
        push    %eax                    # push value from DR0

        # address ring0 data segment with DS register
        mov     $privDS, %ax            # address data segment
        mov     %ax, %ds                #   with DS register

        # examine the Debug Status Register DR6
        mov     %dr6, %eax              # examine register DR6
        test    $0x0000000F, %eax       # any breakpoints?
        jz      nobpt                   # no, keep RF-flag
        btsl    $16, 60(%ebp)           # else set RF-flag
nobpt:
        # examine instruction at saved CS:EIP address
        lfs     52(%ebp), %esi          # point FS:ESI to retn-addr

        # Pick the selector's descriptor-table
        lea     theGDT, %ebx            # EBX = offset for GDT
        mov     %fs, %ecx               # copy selector to ECX
        and     $0xFFF8, %ecx           # isolate selector-index

        # Extract the FS segment descriptor's limit in order to
        # determine how many instructions bytes starting at
        # FS:ESI we can read without violating the limit
        mov     4(%ebx, %ecx), %eax
        and     $0x000f0000, %eax
        mov     0(%ebx, %ecx), %ax

        # fetch next opcode-bytes and write to stack for display
        mov     %fs:(%esi), %eax
        mov     %eax, 48(%ebp)

        # set breakpoint trap after any 'int-nn' instruction
        cmp     $0xCD, %al              # opcode is 'int-nn'?
        jne     nobrk                   # no, don't set breakpoint
        add     $2, %esi                # else point past 'int-nn'

        # Extract the DS segment descriptor's base-address and
        # use it to compute linear-address of the instruction at
        # FS:ESI
        mov     0(%ebx, %ecx), %eax     # descriptor[31..0]
        mov     4(%ebx, %ecx), %al      # descriptor[39..32]
        mov     7(%ebx, %ecx), %ah      # descriptor[63..54]
        rol     $16, %eax               # segment's base-address

        # Setup the instruction-breakpoint in DR0
        add     %eax, %esi              # add segbase to offset
        mov     %esi, %dr0              # breakpoint into DR0
        mov     %esi, -24(%ebp)         # and also update DR0 on the stack

        # Activate the code-breakpoint in register DR0
        mov     %dr7, %eax              # get current DR7 settings
        and     $0xFFF0FFFC, %eax       # clear the G0 and L0 bits
        or      $0x00000001, %eax       # enable L0 code-breakpoint
        mov     %eax, %dr7              # update settings in DR7
        mov     %eax, -4(%ebp)          # and also update DR7 on the stack
        jmp     printstack

nobrk:
        # clear instruction-breakpoint address in DR0
        xor     %eax, %eax
        mov     %eax, %dr0
        # clear the G0 and L0 bits in DR7
        mov     %dr7, %eax
        and     $0xFFF0FFFC, %eax
        mov     %eax, %dr7
        # NOTE: do not update DR0 and DR7 on the stack now as this
        # would prevent correct display of the breakpoint address and
        # status when the breakpoint is hit.

printstack:
        # highlight breakpoints in register DR6
        mov     %dr6, %eax
        and     $0x0000000F, %eax
        pushl   %eax
        pushl   $65
        pushl   $0x9e0faf               # white,green   white, black
        pushl   $DBG_NUM
        pushl   $preval
        pushl   $dbgname
        lea     -24(%ebp), %eax
        pushl   %eax
        call    print_stacktrace

        # now await the release of a user's keypress
        call    wait_keypress
        cmp     $'r', %al
        jne     norun

        # disable any active debug-breakpoints and clear TF-Flag,
        # in order that the remainder of the loaded program will be
        # executed until its end without single-stepping
        xor     %eax, %eax              # clear general register
        mov     %eax, %dr7              # and load zero into DR7
        btrl    $8, 60(%ebp)            # clear Trap Flag
norun:
        mov     %ebp, %esp              # discard other stack data

        # restore the suspended task's registers
        popl    %gs
        popl    %fs
        popl    %es
        popl    %ds
        popal

        # remove dummy error code from stack
        add     $4, %esp

        # resume interrupted work
        iret


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

        .section        .data
status: .ascii  "00:00:00"
        .ascii  "                                        "
        .ascii  "                                        "
        .globl  ticks
ticks:  .long   0
prevticks: .long   0
#-----------------------------------------------------------------
        .section        .text
        .code32
        .type   isrPIT, @function
        .global isrPIT
isrPIT:
        #-----------------------------------------------------------
        # preserve all registers, including modified segment registers
        #-----------------------------------------------------------
        pushal
        pushl   %ds
        pushl   %es
        pushl   %fs

        #-----------------------------------------------------------
        # setup segment registers
        #-----------------------------------------------------------
        mov     $sel_bs, %ax            # address rom-bios data
        mov     %ax, %fs                #   using FS register
        mov     $sel_es, %ax            # address video memory
        mov     %ax, %es                #   with ES register
        mov     $privDS, %ax            # address data segment
        mov     %ax, %ds                #   with DS register

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
        mov     $64, %ecx               # message-length into ECX
        cld
        mov     $0x7020, %ax            # normal text attribute
cpchr:  lodsb                           # fetch next character
        stosw                           # write to the display
        loop    cpchr

skip_update:
        #-----------------------------------------------------------
        # send an 'End-of-Interrupt' command to the Master PIC
        #-----------------------------------------------------------
        mov     $0x20, %al              # non-specific EOI command
        out     %al, $0x20              #  sent to the Master-PIC

        #-----------------------------------------------------------
        # restore the values to the registers we've modified here
        #-----------------------------------------------------------
        popl    %fs
        popl    %es
        popl    %ds
        popal

        #-----------------------------------------------------------
        # resume execution of whichever procedure got interrupted
        #-----------------------------------------------------------
        iret

#------------------------------------------------------------------
        .end
#------------------------------------------------------------------

