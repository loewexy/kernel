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
# it at linear address 0x00030000.
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
        #----------------------------------------------------------
        # equates for Elf32 file-format (derived from 'elf.h')
        #----------------------------------------------------------
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

        #----------------------------------------------------------
        # equates for ISRs/IRQs
        #----------------------------------------------------------
        .equ    IRQ_PIT_ID,     0x00
        .equ    IRQ_KBD_ID,     0x01
        .equ    ISR_DBG_ID,     0x01
        .equ    ISR_SNP_ID,     0x0B


#==================================================================
# S I G N A T U R E
#==================================================================
        .section        .signature, "a", @progbits
        .long   progname_size
progname:
        .ascii  "ELFEXEC"
        .equ    progname_size, (.-progname)
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
        # Code/Data, 32 bit, 4kB, Priv 0, Type 0x00, 'Read-Only'
        # Base Address: 0x00100000   Limit: 0x000000ff
        .equ    sel_extmem, (.-theGDT)+0 # selector for file-image
        .globl  sel_extmem
        .quad   0x00C09010000000FF      # file segment-descriptor
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
        .word   limTSS, theTSS+0x0000, 0x8902, 0x0000  # task descriptor
        #----------------------------------------------------------
        .equ    limGDT, (. - theGDT)-1  # our GDT's segment-limit
#------------------------------------------------------------------
        # image for GDTR register
        #
        #----------------------------------------------------------
        # Note: the linear address offset of the data segment needs
        #       to be added to theGDT at run-time before this GDT
        #       is installed
        #----------------------------------------------------------
        .align  16
        .global regGDT
regGDT: .word   limGDT
        .long   theGDT
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
        .align  4
dr7sav: .space  4                       # DR7 copy
#------------------------------------------------------------------
        .align  4
inscnt: .space  8
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
        # establish our Task-State Segment and a new ring-0 stack
        #----------------------------------------------------------
        mov     %esp, tossav+0
        mov     %ss,  tossav+4
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
        mov     $sel_extmem, %ax
        mov     %ax, %fs
        cmpl    $ELF_SIG, %fs:e_ident   # check ELF-file signature
        jne     .Lelferror              #   no, handle elf error
        cmpb    $ELF_32, %fs:e_class    # check file class is 32-bit
        jne     .Lelferror              #   no, handle elf error
        cmpw    $ET_EXEC, %fs:e_type    # check type is 'executable'
        jne     .Lelferror              #   no, handle elf error

        #----------------------------------------------------------
        # save copy of current DR7 settings
        #----------------------------------------------------------
        mov     %dr7, %eax
        mov     %eax, dr7sav

        #----------------------------------------------------------
        # set new output screen
        #----------------------------------------------------------
        xor     %eax, %eax
        inc     %eax
        movb    %al, (scnid)
        call    screen_sel_page

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
        pushl   $0x00050000             # top of ring's stack
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

.Lelferror:
        #-----------------------------------------------------------
        # print error message
        #-----------------------------------------------------------
        lea     elferrmsg, %esi
        mov     $elferrmsglen, %ecx
        call    screen_write

finis:
        #-----------------------------------------------------------
        # load appropriate ring0 data segment descriptor
        #-----------------------------------------------------------
        mov     $privDS, %ax
        mov     %ax, %ds

        call    print_exit_msg

        #-----------------------------------------------------------
        # disable hardware interrupts
        #-----------------------------------------------------------
        cli

        #-----------------------------------------------------------
        # reprogram PICs to their original setting
        #-----------------------------------------------------------
        call    remap_isr_rm

        #-----------------------------------------------------------
        # recover original DR7 contents
        #-----------------------------------------------------------
        mov     dr7sav, %eax
        mov     %eax, %dr7

        #----------------------------------------------------------
        # reset output screen
        #----------------------------------------------------------
        xor     %eax, %eax
        call    screen_sel_page

        #----------------------------------------------------------
        # trigger triple fault in order to reboot
        #----------------------------------------------------------
        movl    $0, theIDT+13*8
        movl    $0, theIDT+13*8+4
        lidt    theIDT
        int     $13
        hlt     # just in case ;-)

#------------------------------------------------------------------
        .section        .data
        .align   4
finmsg: .ascii  "\r\n\r\nProgram finished. "
        .ascii  "Press any key to reboot\r\n"
        .equ    finmsglen, (.-finmsg)
elferrmsg:
        .ascii  "\r\nERROR: Cannot load ELF image.\r\n"
        .equ    elferrmsglen, (.-elferrmsg)
#------------------------------------------------------------------
        .section        .text
        .code32
        .type   print_exit_msg, @function
        .global print_exit_msg
        .align  8
print_exit_msg:
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
.Lwaitkey:
        hlt
        cmpb    $0, (lastkey)
        je      .Lwaitkey
        ret
#------------------------------------------------------------------


        .type   bail_out, @function
        .global bail_out
        .align  8
bail_out:
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
        mov     $sel_extmem, %ax        # address ELF file-image
        mov     %ax, %ds                #    with DS register
        mov     $userDS, %ax            # address entire memory
        mov     %ax, %es                #    with ES register
        cld                             # do forward processing

        #-----------------------------------------------------------
        # extract load-information from the ELF-file's image
        #-----------------------------------------------------------
        mov     e_phoff, %ebx           # segment-table's offset
        movzxw  e_phnum, %ecx           # count of table entries
        movzxw  e_phentsize, %edx       # length of table entries

.Lnxseg:
        push    %ecx                    # save outer loop-counter
        mov     p_type(%ebx), %eax      # get program-segment type
        cmp     $PT_LOAD, %eax          # segment-type 'LOADABLE'?
        jne     .Lfillx                 # no, loading isn't needed
        mov     p_offset(%ebx), %esi    # DS:ESI is segment-source
        mov     p_paddr(%ebx), %edi     # ES:EDI is desired address
        mov     p_filesz(%ebx), %ecx    # ECX is length for copying
        jecxz   .Lcopyx                 # maybe copying is skipped
        rep     movsb                   # 'load' program-segment
.Lcopyx:
        mov     p_memsz(%ebx), %ecx     # segment-size in memory
        sub     p_filesz(%ebx), %ecx    # minus its size in file
        jecxz   .Lfillx                 # maybe fill is unneeded
        xor     %al, %al                # use zero for filling
        rep     stosb                   # clear leftover space
.Lfillx:
        pop     %ecx                    # recover outer counter
        add     %edx, %ebx              # advance to next record
        loop    .Lnxseg                 # process another record

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
#    | INS WORD        |  -4
#    +-----------------+
#    | CNT             |  -8
#    +-----------------+
#    | DR7             |  -12
#    +-----------------+
#    | DR6             |  -16
#    +-----------------+
#    | DR2             |  -20
#    +-----------------+
#    | DR1             |  -24
#    +-----------------+
#    | DR0             |  -28
#    +-----------------+
#
#-----------------------------------------------------------------
        .section        .data
#-----------------------------------------------------------------
        .align   4
preval1:.space  20 * 4, 0
preval2:.space   8 * 4, 0
#-----------------------------------------------------------------
dbgname:.ascii  "DR0 DR1 DR2 DR6 DR7 CNT INS "
        .equ    DBG_LEN, .-dbgname
        .equ    DBG_NUM, (.-dbgname)/4  # number of array entries
        .equ    DR0_OFF, -28
        .equ    DR7_OFF, -12
        .equ    INS_OFF, -4
#-----------------------------------------------------------------
regname:.ascii  " GS  FS  ES  DS  SS  CS "
        .ascii  "EDI ESI EBP ESP EBX EDX ECX EAX "
        .ascii  "EIP "
        .ascii  "EFL "
        .equ    REG_LEN, .-regname
        .equ    REG_NUM, (.-regname)/4  # number of array entries
regidx: .byte    0,  4,  8, 12  # GS, FS, ES, DS
        .byte   72, 60          # SS, CS
        .byte   16, 20, 24, 68  # EDI, ESI, EBP, ESP
        .byte   32, 36, 40, 44  # EBX, EDX, ECX, EAX
        .byte   56, 64          # EIP, EFL
regloc: .long   0
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
        # setup stack frame access via ebp and use edx to access
        # caller stack frame
        #-----------------------------------------------------------
        enter   $0, $0
        mov     8(%ebp), %edx           # read ISR stack frame ptr
        lea     theGDT, %ebx            # EBX = offset for GDT

        #-----------------------------------------------------------
        # address ring0 data segment with DS register
        #-----------------------------------------------------------
        mov     $privDS, %ax            # address data segment
        mov     %ax, %ds                #   with DS register

        #-----------------------------------------------------------
        # ok, let's display the Debug Registers, too
        #-----------------------------------------------------------
        pushl   $0                      # dummy value for instruction word
        pushl   inscnt
        mov     %dr7, %eax
        push    %eax                    # push value from DR7
        mov     %dr6, %eax
        push    %eax                    # push value from DR6
        mov     %dr2, %eax
        push    %eax                    # push value from DR2
        mov     %dr1, %eax
        push    %eax                    # push value from DR1
        mov     %dr0, %eax
        push    %eax                    # push value from DR0

        mov     $REG_NUM, %ecx
.Lregcopy:
        movzxb  regidx-1(,%ecx,1), %eax
        movl    %ss:(%edx,%eax,1), %eax
        push    %eax
        loop    .Lregcopy
        mov     %esp, regloc

        #-----------------------------------------------------------
        # ISR stub disables interrupts, so we need to re-enable them
        # in order to be able to capture keybaord interrupts while
        # waiting in this handler. This is probably not the most sane
        # solution...
        #-----------------------------------------------------------
        sti

        #-----------------------------------------------------------
        # increment 64-bit instruction counter
        #-----------------------------------------------------------
        addl    $1, inscnt+0
        adcl    $0, inscnt+4

        #-----------------------------------------------------------
        # examine the Debug Status Register DR6
        #-----------------------------------------------------------
        mov     %dr6, %eax              # examine register DR6
        test    $0x0000000F, %eax       # any breakpoints?
        jz      .Lnobpt                 # no, keep RF-flag
        btsl    $16, %ss:64(%edx)       # else set RF-flag
.Lnobpt:
        #-----------------------------------------------------------
        # load CS:EIP return address stored on stack into FS:ESI
        #-----------------------------------------------------------
        lfs     %ss:56(%edx), %esi

        #-----------------------------------------------------------
        # pick the selector's descriptor-table
        #-----------------------------------------------------------
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
        mov     %eax, INS_OFF(%ebp)

        #-----------------------------------------------------------
        # set breakpoint trap after any 'int-nn' instruction
        #-----------------------------------------------------------
        cmp     $0xCD, %al              # opcode is 'int-nn'?
        jne     .Lnobrk                 # no, don't set breakpoint
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
        mov     %esi, DR0_OFF(%ebp)     # and also update DR0 on the stack

        #-----------------------------------------------------------
        # activate the code-breakpoint in register DR0
        #-----------------------------------------------------------
        mov     %dr7, %eax              # get current DR7 settings
        and     $0xFFF0FFFC, %eax       # clear the G0 and L0 bits
        or      $0x00000003, %eax       # enable G0/L0 code-breakpoint
        mov     %eax, %dr7              # update settings in DR7
        mov     %eax, DR7_OFF(%ebp)     # and also update DR7 on the stack
        jmp     .Lprintstack

.Lnobrk:
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

.Lprintstack:
        pushl   $0                      # do not highlight any registers
        pushl   $65                     # set display column
        pushl   $0x9e0faf               # white,green   white, black
        pushl   $REG_NUM
        pushl   $preval1
        pushl   $regname
        pushl   regloc
        call    print_stacktrace
        # note: post-call stack cleanup done by leave instruction below

        #-----------------------------------------------------------
        # highlight breakpoints in register DR6
        #-----------------------------------------------------------
        mov     %dr6, %eax
        # only highlight breakpoint in DR0 and DR1
        and     $0x00000003,%eax
        pushl   %eax
        pushl   $50                     # set display column
        pushl   $0x9e0faf               # white,green   white, black
        pushl   $DBG_NUM
        pushl   $preval2
        pushl   $dbgname
        lea     -DBG_LEN(%ebp), %eax
        pushl   %eax
        call    print_stacktrace
        # note: post-call stack cleanup done by leave instruction below

        #-----------------------------------------------------------
        # now await the release of a user's keypress
        #-----------------------------------------------------------
.Lpollkey:
        hlt
        cmpb    $0, (lastkey)
        je      .Lpollkey
        cmpb    $'r', (lastkey)
        jne     .Lnorun

        #-----------------------------------------------------------
        # disable any active debug-breakpoints and clear TF-Flag,
        # in order that the remainder of the loaded program will be
        # executed until its end without single-stepping
        #-----------------------------------------------------------
        mov     %dr7, %eax              # get current DR7 settings
        and     $0x0000040C, %eax       # clear the G0 and L0 bits
        mov     %eax, %dr7              # and load zero into DR7
        btrl    $8, %ss:64(%edx)        # clear Trap Flag
.Lnorun:
        movb    $0, (lastkey)

        #-----------------------------------------------------------
        # erase local stack frame and reestablish original stack
        # pointer. Finally, return to caller.
        #-----------------------------------------------------------
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
status: .ascii  "HH:MM:SS  "            # time string
tickmsg:.ascii  "__________ "           # ticks (dec)
        .space  73 - (.-status), ' '
        .ascii  "SCN #"
scnnum: .ascii  "  "
        .align  4
prevticks: .long   0
scnid:     .byte   0
prevscnid: .byte   0
#-----------------------------------------------------------------
        .section        .text
        .code32
        .type   irqPIT, @function
        .global irqPIT
        .align   16
irqPIT:
        #-----------------------------------------------------------
        # setup stack frame access via ebp
        #-----------------------------------------------------------
        enter   $0, $0
        pushl   %fs
        pushl   %es

        #----------------------------------------------------------
        # setup access to BIOS data area using the FS segment
        #----------------------------------------------------------
        mov     $sel_bs, %ax
        mov     %ax, %fs

        #-----------------------------------------------------------
        # increment the 32-bit counter for timer-tick interrupts
        #-----------------------------------------------------------
        incl    %fs:N_TICKS             # increment tick-count
        cmpl    $HOURS24, %fs:N_TICKS   # past midnight?
        jl      .Lisok                  # no, don't rollover yet
        movl    $0, %fs:N_TICKS         # else reset count to 0
        movb    $1, %fs:TM_OVFL         # and set rollover flag
.Lisok:

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

        mov     (scnid), %dl
        cmp     %dl, (prevscnid)
        jne     .Ldoupdate
.Lcheckticks:
        cmp     %eax, prevticks
        je      .Lskipupdate
        mov     %eax, prevticks
.Ldoupdate:
        mov     %dl, (prevscnid)
        add     $0x30, %dl
        mov     %dl, (scnnum)

        incl    ticks
        mov     $SECS_PER_DAY, %ebx
        movl    ticks, %eax
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

        mov     ticks, %eax
        lea     tickmsg, %edi
        mov     $10, %cx
        call    uint32_to_dec

        #----------------------------------------------------------
        # setup access to CGA video memory using the ES segment
        #----------------------------------------------------------
        mov     $sel_cga, %ax
        mov     %ax, %es

        #-----------------------------------------------------------
        # loop to write character-codes to the screen
        #-----------------------------------------------------------
        lea     status, %esi            # message-offset into ESI
        movzxb  (scnid), %bx
        xor     %eax, %eax
        imul    $0x1000, %bx, %ax
        mov     $160*24, %edi
        add     %eax, %edi
        mov     $80, %ecx               # message-length into ECX
        cld
        mov     $0x7020, %ax            # normal text attribute
.Lcpchr:
        lodsb                           # fetch next character
        stosw                           # write to the display
        loop    .Lcpchr

        movzxb  (scnid), %eax
        call    screen_sel_page
.Lskipupdate:
        popl   %es
        popl   %fs
        leave
        ret


#==================================================================
#===========      HANDLER FOR KEYBOARD INTERRUPTS      ============
#==================================================================
#
#-----------------------------------------------------------------
# Stack Frame Layout
#-----------------------------------------------------------------
#
#                 Byte 0
#                      V
#    +=================+
#    |  Int Stack Ptr  |  +8
#    +-----------------+
#    |  Return Address |  +4
#    +-----------------+
#    |       EBP       |  <-- ebp
#    +=================+
#
#-----------------------------------------------------------------
        .section        .data
            .align   4
lastkey:    .byte       0
scancode:   .byte       0
#-----------------------------------------------------------------
        .section        .text
        .code32
        .type   irqKBD, @function
        .global irqKBD
        .align   16
irqKBD:
        #-----------------------------------------------------------
        # setup stack frame access via ebp and use edx to access
        # caller stack frame
        #-----------------------------------------------------------
        enter   $0, $0
        mov     8(%ebp), %edx           # read ISR stack frame ptr

        in      $0x64, %al              # poll keyboard status
        test    $0x01, %al              # new scancode ready?
        jz      .Lkbdend                #   no, then don't return char

        in      $0x60, %al              # input the new scancode
        test    $0x80, %al              # was a key released?
        jz      .Lkbdend                #   no, then don't return char

        and     $0x0000007f, %eax       # mask for 7-bit ASCII
        mov     %al, (scancode)
        mov     kbdus(%eax), %al        # translate scancode into ASCII
        cmp     $127, %al               # is char outside ASCII range?
        ja      .Lnoascii               #   yes, then check special char
        mov     %al, (lastkey)
.Lkbdend:
        leave
        ret
.Lnoascii:
        cmp     $129, %al
        jne     .Lnopgdn
        decb    (scnid)
        andb    $0x3, (scnid)
        jmp     .Lnopgup
.Lnopgdn:
        cmp     $130, %al
        jne     .Lnopgup
        incb    (scnid)
        andb    $0x3, (scnid)
.Lnopgup:
        leave
        ret

#------------------------------------------------------------------
        .end
#------------------------------------------------------------------

