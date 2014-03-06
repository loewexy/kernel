//-----------------------------------------------------------------
//      elfexec.s
//
//      Here we will simulate 'loading' of an executable ELF-file
//      at its intended load-address in extended physical memory.
//      At the outset our segment-descriptor for application code
//      (in the Global Descriptor Table) is marked 'Not Present',
//      so that actual initialization of the memory-contents will
//      be deferred until a 'Segment Not Present' fault occurs at
//      the point where the first instruction-fetch is attempted.
//      The executable ELF file-image (e.g., 'linuxapp') needs to
//      be preinstalled on our hard-disk's partition, starting at
//      block 65, so that our 'cs630ipl' loader will read it into
//      memory along with 'elfexec.b' (putting it at 0x00018000):
//
//               $ dd if=linuxapp of=/dev/sda4 seek=65
//
//      Later, those portions of the ELF file-image which need to
//      reside during execution at higher addresses (i.e., in the
//      PC's 'Extended' memory, above 1-MB) will be 'loaded' when
//      our 'Segment-Not-Present' fault-handler gets executed, as
//      a result of the initial attempt to transfer out to ring3
//
//        to assemble: $ as elfexec.s -o elfexec.o
//        and to link: $ ld elfexec.o -T ldscript -o elfexec.b
//        and install: $ dd if=elfexec.b of=/dev/sda4 seek=1
//
//      NOTE: This code begins execution with CS:IP = 1000:0002
//
//      programmer: ALLAN CRUSE
//      date begun: 01 NOV 2008
//      completion: 06 NOV 2008
//-----------------------------------------------------------------


        # equates for Elf32 file-format (derived from 'elf.h')
        .equ    ELF_SIG,  0x464C457F    # ELF-file's 'signature'
        .equ    ELF_32,            1    # Elf_32 file format
        .equ    ET_EXEC,           2    # Executable file type
        .equ    e_ident,      0x8000    # offset to ELF signature
        .equ    e_class,      0x8004    # offset to file class
        .equ    e_type,       0x8010    # offset to (TYPE,MACHINE)
        .equ    e_entry,      0x8018    # offset to entry address
        .equ    e_phoff,      0x801C    # offset to PHT file-offset
        .equ    e_phentsize,  0x802A    # offset to PHT entry size
        .equ    e_phnum,      0x802C    # offset to PHT entry count
        .equ    PT_LOAD,           1    # Loadable program segment
        .equ    p_type,         0x00    # offset to segment type
        .equ    p_offset,       0x04    # offset to seg file-offset
        .equ    p_paddr,        0x0C    # offset to seg phys addr
        .equ    p_filesz,       0x10    # offset to seg size in file
        .equ    p_memsz,        0x14    # offset to seg size in mem




        .section        .text
#------------------------------------------------------------------
        .word   0xABCD                  # our loader expects this
#------------------------------------------------------------------
main:   .code16

        mov     %esp, %cs:ipltos+0      # save loader's ESP-value
        mov     %ss,  %cs:ipltos+4      # also loader's SS value

        mov     %cs, %ax                # address program's arena
        mov     %ax, %ss                #    using SS register
        lea     tos, %esp               # and establish new stack

        call    initialize_os_tables
        call    enter_protected_mode
        call    execute_program_demo
        call    leave_protected_mode

        lss     %cs:ipltos, %esp        # recover loader's SS:ESP
        lret                            # loader regains control 
#------------------------------------------------------------------
ipltos: .space  6                       # stores a 48-bit pointer
#------------------------------------------------------------------
theGDT: .quad   0x0000000000000000      # null segment-descriptor
        #----------------------------------------------------------
        # Code/Data, 16 bit, Byte, Priv 0, Type 0x0a, 'Execute/Read'
        # Base Address: 0x00010000   Limit: 0x0000ffff
        .equ    sel_cs, (.-theGDT)+0    # selector for 16bit code
        .quad   0x00009A010000FFFF      # code segment-descriptor
        #----------------------------------------------------------
        # Code/Data, 16 bit, Byte, Priv 0, Type 0x02, 'Read/Write'
        # Base Address: 0x00010000   Limit: 0x0000ffff
        .equ    sel_ds, (.-theGDT)+0    # selector for 16bit data
        .quad   0x000092010000FFFF      # data segment-descriptor
        #----------------------------------------------------------
        # Code/Data, 16 bit, Byte, Priv 0, Type 0x02, 'Read/Write'
        # Base Address: 0x000b8000   Limit: 0x00007fff
        .equ    sel_es, (.-theGDT)+0    # selector for video area
        .quad   0x0000920B80007FFF      # vram segment-descriptor
        #----------------------------------------------------------
        # Code/Data, 16 bit, Byte, Priv 0, Type 0x00, 'Read-Only'
        # Base Address: 0x00018000   Limit: 0x0000ffff
        .equ    sel_fs, (.-theGDT)+0    # selector for file-image
        .quad   0x000090018000FFFF      # file segment-descriptor
        #----------------------------------------------------------
        # Code/Data, 32 bit, 4kB, Priv 0, Type 0x0a, 'Execute/Read'
        # Base Address: 0x00010000   Limit: 0x000fffff
        .equ    privCS, (.-theGDT)+0    # selector for ring0 code
        .quad   0x00CF9A010000FFFF      # code segment-descriptor
        #----------------------------------------------------------
        # Code/Data, 32 bit, 4kB, Priv 0, Type 0x02, 'Read/Write'
        # Base Address: 0x00010000   Limit: 0x000fffff
        .equ    privDS, (.-theGDT)+0    # selector for ring0 data
        .quad   0x00CF92010000FFFF      # data segment-descriptor
        #----------------------------------------------------------
        # Code/Data, 32 bit, 4kB, Priv 3, Type 0x0a, 'Execute/Read'
        # Base Address: 0x00000000   Limit: 0x000fffff
        .equ    userCS, (.-theGDT)+3    # selector for ring3 code
        .quad   0x00CF7A000000FFFF      # code segment-descriptor
        #----------------------------------------------------------
        # Code/Data, 32 bit, 4kB, Priv 3, Type 0x02, 'Read/Write'
        # Base Address: 0x00000000   Limit: 0x000fffff
        .equ    userDS, (.-theGDT)+3    # selector for ring3 data
        .quad   0x00CFF2000000FFFF      # data segment-descriptor
        #----------------------------------------------------------
        .equ    selTSS, (.-theGDT)+0    # selector for Task-State
        .word   limTSS, theTSS, 0x8901, 0x0000  # task descriptor
        #----------------------------------------------------------
        .equ    limGDT, (.-theGDT)-1    # this GDT's segment-limit
#------------------------------------------------------------------
theTSS: .long   0x00000000              # back-link field (unused)
        .long   0x00010000              # stacktop for Ring0 stack
        .long   privDS                  # selector for Ring0 stack
        .equ    limTSS, (.-theTSS)-1    # this TSS's segment-limit
#------------------------------------------------------------------
theIDT: .space  256*8                   # for 256 gate-descriptors
        .equ    limIDT, (.-theIDT)-1    # this IDT's segment-limit
#------------------------------------------------------------------
regGDT: .word   limGDT, theGDT, 0x0001  # register-image for GDTR
regIDT: .word   limIDT, theIDT, 0x0001  # register-image for IDTR
regIVT: .word   0x03FF, 0x0000, 0x0000  # register-image for IDTR
#------------------------------------------------------------------
initialize_os_tables:

        # setup gate-descriptor for Single-Step Exceptions
        mov     $0x01, %ebx             # ID-number for the gate
        lea     theIDT(,%ebx,8), %di    # gate's offset-address
        movw    $isrDBG, %ss:0(%di)     # entry-point's loword
        movw    $privCS, %ss:2(%di)     # 32-bit code-selector
        movw    $0xEF00, %ss:4(%di)     # 32-bit trap-gate
        movw    $0x0000, %ss:6(%di)     # entry-point's hiword

        # setup gate-descriptor for Segment-Not-Present Exceptions
        mov     $0x0B, %ebx
        lea     theIDT(,%ebx,8), %di
        movw    $isrSNP, %ss:0(%di)
        movw    $privCS, %ss:2(%di)
        movw    $0x8E00, %ss:4(%di)
        movw    $0x0000, %ss:6(%di)

        # setup gate-descriptor for General Protection Exceptions
        mov     $0x0D, %ebx
        lea     theIDT(,%ebx,8), %di
        movw    $isrGPF, %ss:0(%di)
        movw    $privCS, %ss:2(%di)
        movw    $0x8E00, %ss:4(%di)
        movw    $0x0000, %ss:6(%di)

        # setup gate-descriptor for Linux SuperVisor-Calls
        mov     $0x80, %ebx
        lea     theIDT(,%ebx,8), %di
        movw    $isrSVC, %ss:0(%di)
        movw    $privCS, %ss:2(%di)
        movw    $0xEE00, %ss:4(%di)
        movw    $0x0000, %ss:6(%di)

        ret
#------------------------------------------------------------------
enter_protected_mode:

        cli
        lgdt    %cs:regGDT
        lidt    %cs:regIDT

        mov     %cr0, %eax
        bts     $0, %eax
        mov     %eax, %cr0

        ljmp    $sel_cs, $pm
pm:     mov     $sel_ds, %ax
        mov     %ax, %ss
        ret
#------------------------------------------------------------------
#------------------------------------------------------------------
tossav: .long   0, 0                    # will hold 48-bit pointer
#------------------------------------------------------------------
execute_program_demo:

        # save stack-address (we use it when returning to 'main')
        mov     %esp, %ss:tossav+0
        mov     %ss,  %ss:tossav+4

        # establish our Task-State Segment and a new ring-0 stack
        mov     $selTSS, %ax
        ltr     %ax
        lss     %cs:theTSS+4, %esp

        # turn on the A20 address-line
        in      $0x92, %al              # System Control Port
        or      $0x02, %al              # set bit #1 (Fast_A20)
        out     %al, $0x92              # output port settings

        # verify ELF file's presence and 32-bit 'executable'
        cmpl    $ELF_SIG, %cs:e_ident   # ELF-file signature
        jne     finis
        cmpb    $ELF_32, %cs:e_class    # file class is 32-bit
        jne     finis
        cmpw    $ET_EXEC, %cs:e_type    # type is 'executable'
        jne     finis

        # setup segment-registers for the Linux application
        mov     $userDS, %ax
        mov     %ax, %ds
        mov     %ax, %es
        xor     %ax, %ax
        mov     %ax, %fs
        mov     %ax, %gs

        # clear general registers for the Linux application
        xor     %eax, %eax
        xor     %ebx, %ebx
        xor     %ecx, %ecx
        xor     %edx, %edx
        xor     %ebp, %ebp
        xor     %esi, %esi
        xor     %edi, %edi

        # transfer control to the Linux application in ring3
        pushl   $userDS                 # selector for 'data'
        pushl   $0x00040000             # top of ring's stack
        pushl   $userCS                 # selector for 'code'
        pushl   %cs:e_entry             # program entry-point

        # set the TF-bit in FLAGS register just prior to 'lret'
        pushf                           # push current FLAGS
        btsw    $8, (%esp)              # set image of TF-bit
        popf                            # pop modified FLAGS

        # transfer to user program
        lretl

finis:  # return control to 'main' routine with interrupts off
        cli                             # no device interrupts
        lss     %cs:tossav, %esp        # recover former stack
        ret                             # and return to 'main'
#------------------------------------------------------------------
#------------------------------------------------------------------
isrSNP: .code32  # fault-handler for Segment-Not-Present exception

        enter   $0, $0                  # setup error-code access
        pushal                          # preserve registers
        pushl   %ds
        pushl   %es

        # extract load-information from the ELF-file's image
        mov     %cs:e_phoff, %ebx       # segment-table's offset
        movzxw  %cs:e_phnum, %ecx       # count of table entries
        movzxw  %cs:e_phentsize, %edx   # length of table entries

        # setup segment-registers for 'loading' program-segments 
        mov     $sel_fs, %ax            # address ELF file-image
        mov     %ax, %ds                #    with DS register
        mov     $userDS, %ax            # address entire memory
        mov     %ax, %es                #    with ES register
        cld                             # do forward processing
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
        loop    nxseg                   # process anther record

        # now mark segment-descriptor as 'present'
        mov     $privDS, %ax            # address GDT descriptors
        mov     %ax, %ds                #  using the DS register
        lea     theGDT, %ebx            # DS:EBX = our GDT's base
        mov     4(%ebp), %eax           # get fault's error-code
        and     $0xFFF8, %eax           # isolate its index-field
        btsw    $15, 4(%ebx, %eax, 1)   # set P-bit in descriptor

        popl    %es                     # recover saved registers
        popl    %ds
        popal
        leave                           # discard stackframe

        add     $4, %esp                # discard error-code
        iret                            # retry faulting opcode
#------------------------------------------------------------------
names:  .ascii  "  GS  FS  ES  DS"
        .ascii  " EDI ESI EBP ESP EBX EDX ECX EAX"
        .ascii  " err EIP  CS EFL ESP  SS"
        .equ    ITEMS, (. - names) / 4
msg13:  .ascii  " NNN=xxxxxxxx "
len13:  .int    . - msg13
att13:  .byte   0x70
loc13:  .int    (22*80 + 64)*2
#------------------------------------------------------------------
isrGPF: .code32  # fault-handler for General Protection exception
        pushal

        pushl   $0
        mov     %ds, (%esp)

        pushl   $0
        mov     %es, (%esp)

        pushl   $0
        mov     %fs, (%esp)

        pushl   $0
        mov     %gs, (%esp)

        mov     $sel_es, %ax
        mov     %ax, %es

        mov     $privDS, %ax
        mov     %ax, %ds

        # loop to display registers
        xor     %ebx, %ebx
nxelt:
        # setup register-name
        mov     names(,%ebx,4), %eax
        mov     %eax, msg13

        # setup register-value
        mov     (%esp, %ebx, 4), %eax
        lea     msg13+5, %edi
        call    eax2hex

        # setup screen-destination
        mov     loc13, %edi
        #imul    $160, %ebx, %eax
        lea     (%ebx, %ebx, 4), %eax
        shl     $5, %eax
        sub     %eax, %edi

        # draw message-string
        lea     msg13, %esi
        mov     len13, %ecx
        mov     att13, %ah
        cld
nxchr:  lodsb
        stosw
        loop    nxchr

        # advance register-number
        inc     %ebx
        cmp     $ITEMS, %ebx
        jb      nxelt

        # terminate this demo
        ljmp    $sel_cs, $finis         # jump back to 16-bit code
#------------------------------------------------------------------
hex:    .ascii  "0123456789ABCDEF"
#------------------------------------------------------------------
eax2hex: .code32
        pushal
        mov     $8, %ecx
nxnyb:  rol     $4, %eax
        mov     %al, %bl
        and     $0x0F, %ebx
        mov     hex(%ebx), %dl
        mov     %dl, (%edi)
        inc     %edi
        loop    nxnyb
        popal
        ret
#------------------------------------------------------------------
#==================================================================
#------------------------------------------------------------------
sys_call_table: # our jump-table (for dispatching OS system-calls)      
        .long   do_nothing
        .long   do_exit
        .long   do_nothing
        .long   do_nothing
        .long   do_write
        .equ    N_SYSCALLS, (.-sys_call_table)/4
#------------------------------------------------------------------
isrSVC: .code32  # our dispatcher-routine for OS supervisor calls

        cmp     $N_SYSCALLS, %eax       # ID-number out-of-bounds?
        jb      idok                    # no, then we can use it
        xor     %eax, %eax              # else replace with zero
idok:   jmp     *%cs:sys_call_table(, %eax, 4)  # to call handler
#------------------------------------------------------------------
do_nothing: .code32     # for any unimplemented system-calls

        mov     $-1, %eax               # return-value: minus one 
        iret                            # resume the calling task
#------------------------------------------------------------------
do_exit: .code32        # for transfering back to our USE16 code

        # disable any active debug-breakpoints
        xor     %eax, %eax              # clear general register 
        mov     %eax, %dr7              # and load zero into DR7

        # transfer control back to our 16-bit code-segment
        ljmp    $sel_cs, $finis         # back to 16-bit code 
#------------------------------------------------------------------
#------------------------------------------------------------------
do_write: .code32       # for writing a string to standard output
#
#       EXPECTS:        EBX = ID-number for device (=1)
#                       ECX = offset of message-string
#                       EDX = length of message-string
#
#       RETURNS:        EAX = number of bytes written
#                             (or -1 for any errors)
#
# NOTE: This hastily recrafted 'do_write()' function handles one
# special ascii control-code (i.e., '\n' for newline), but we've
# left it as an exercise to handle others (e.g., '\r' and '\b')
#
        enter   $0, $0                  # setup stackframe access

        pushal                          # preserve registers
        pushl   %ds
        pushl   %es

        # check for invalid device-ID 
        cmp     $1, %ebx                # device is standard output?
        jne     inval                   # no, return with error-code

        # check for invalid message-offset
        cmp     $0x08048000, %ecx       # string within Linux arena?
        jb      inval                   # no, return with error-code

        # check for negative message-length
        cmp     $0, %edx                # string length nonnegative?
        jl      inval                   # no, return with error_code

        jmp     argok                   # else proceed with writing

inval:  # return to application with the error-code in register EAX
        movl    $-1, -4(%ebp)           # else write -1 as EAX image
        jmp     wrxxx                   # and return with error-code
argok:
        movl    $0, -4(%ebp)            # setup zero as EAX image
        cmp     $0, %edx                # empty message-string?
        je      wrxxx                   # yes, no writing needed

        # point ES:EDI to screen-position 
        mov     $sel_es, %ax            # address video memory
        mov     %ax, %es                #   with ES register
        mov     $0x400, %ebx            # ROM-BIOS DATA-SEGMENT
        mov     0x50(%ebx), %dx         # row,column for page zero
        mov     $80, %al                # cells-per-row
        mul     %dh                     # times row-number
        add     %dl, %al                # plus column-number
        adc     $0, %ah                 # as 16-bit value
        movzx   %ax, %eax               # exended to dword
        lea     (,%eax,2), %edi         # vram-offset into EDI

        # loop to write character-codes to the screen
        movl    $0, -4(%ebp)            # setup zero as EAX image
        mov     -8(%ebp), %esi          # message-offset into ESI
        mov     -12(%ebp), %ecx         # message-length into ECX
        cld
        mov     $0x07, %ah              # normal text attribute
nxmchr: lodsb                           # fetch next character

        cmp     $'\n', %al              # newline?
        je      do_nl                   # yes, do CR/LF
        jmp     do_wr

do_wr:  stosw                           # write to the display
        inc     %dl                     # advance column-number
        cmp     $80, %dl                # end-of-row reached?
        jb      advok                   # no, column is ok
do_nl:  inc     %dh                     # else advance row-number
        mov     $0, %dl                 # with zero column-number
        cmp     $24, %dh                # bottom-of-screen reached?
        jb      advok                   # no, row is ok
        dec     %dh                     # else reduce row-number

        pushal
        xor     %edi, %edi
        mov     $160, %esi
        mov     $160*24, %ecx
        rep     movsw   %es:(%esi), %es:(%edi)
        mov     $0x0720, %ax
        mov     $160, %ecx
        rep     stosw
        popal
advok:
        incl    -4(%ebp)                # increment return-value
        mov     %dx, 0x50(%ebx)         # store new cursor-location
        loop    nxmchr                  # again for full string

        # adjust hardware cursor-location
        mov     %edi, %ebx
        and     $0xFFF, %ebx
        shr     $1, %ebx
        mov     $0x03D4, %dx            # CRTC i/o-port
        mov     $0x0E, %al              # cursor-offset HI
        mov     %ah, %bh                # offset 15..8
        out     %ax, %dx
        mov     $0x0F, %al              # cursor-offset LO
        mov     %bl, %ah                # offset 7..0
        out     %ax, %dx
wrxxx:
        popl    %es
        popl    %ds
        popal

        leave
        iret


#==================================================================
#===========  TRAP-HANDLER FOR SINGLE-STEP EXCEPTIONS  ============
#==================================================================
name:   .ascii  "INS="
        .ascii  "DR7=DR6=DR3=DR2=DR1=DR0="
        .ascii  " GS= FS= ES= DS="
        .ascii  "EDI=ESI=EBP=ESP=EBX=EDX=ECX=EAX="
        .ascii  "EIP= CS=EFL=ESP= SS="
        .equ    RNUM, ( . - name )/4    # number of array entries
info:   .ascii  " nnn=xxxxxxxx "        # buffer for hex display
        .equ    ILEN, . - info          # length of outbup buffer
preval: .space  RNUM * 4
color:  .byte   0x0F                    # fg=white, bg=black
hicolor:.byte   0xAF                    # fg=white, bg=green
#-----------------------------------------------------------------
        .code32
isrDBG:
        pushal                          # push general registers
        mov     %esp, %ebp              # setup stackframe access

        pushl   $0                      # push doubleword zero
        mov     %ds, (%esp)             # store DS in low word
        pushl   $0                      # push doubleword zero
        mov     %es, (%esp)             # store ES in low word
        pushl   $0                      # push doubleword zero
        mov     %fs, (%esp)             # store FS in low word
        pushl   $0                      # push doubleword zero
        mov     %gs, (%esp)             # store GS in low word

        # ok, let's display the Debug Registers, too
        mov     %dr0, %eax
        push    %eax                    # push value from DR0
        mov     %dr1, %eax
        push    %eax                    # push value from DR1
        mov     %dr2, %eax
        push    %eax                    # push value from DR2
        mov     %dr3, %eax
        push    %eax                    # push value from DR3
        mov     %dr6, %eax
        push    %eax                    # push value from DR6
        mov     %dr7, %eax
        push    %eax                    # push value from DR7
        pushl   $0                      # push doubleword zero to
                                        # hold instruction byte

        push    %ds                     # preseve task's selectors
        push    %es                     #   found in DS and ES

        # examine the Debug Status Register DR6
        mov     %dr6, %eax              # examine register DR6
        test    $0x0000000F, %eax       # any breakpoints?
        jz      nobpt                   # no, keep RF-flag
        btsl    $16, 40(%ebp)           # else set RF-flag
nobpt:
        # examine instruction at saved CS:EIP address
        lds     0x20(%ebp), %esi        # point DS:ESI to retn-addr

        #-----------------------------------------------------
        # Note: the following instruction causes a GPF
        # See debugging exercise mentioned in the program header
        #-----------------------------------------------------
        xor     %eax, %eax
        mov     %ds:(%esi), %al         # fetch next opcode-bytes
        mov     %al, -44(%ebp)

        # set breakpoint trap after any 'int-nn' instruction
        cmp     $0xCD, %al              # opcode is 'int-nn'?
        jne     nobrk                   # no, don't set breakpoint

        add     $2, %esi                # else point past 'int-nn'

        #-----------------------------------------------------
        # compute linear-address of the instruction at DS:ESI
        #-----------------------------------------------------

        # Step 1: Pick the selector's descriptor-table
        lea     theGDT, %ebx            # EBX = offset for GDT
        mov     %ds, %ecx               # copy selector to ECX

        # Step 2: Extract the descriptor's base-address
        and     $0xFFF8, %ecx           # isolate selector-index
        mov     %cs:0(%ebx, %ecx), %eax # descriptor[31..0]
        mov     %cs:4(%ebx, %ecx), %al  # descriptor[39..32]
        mov     %cs:7(%ebx, %ecx), %ah  # descriptor[63..54]
        rol     $16, %eax               # segment's base-address

        # Step 3: Setup the instruction-breakpoint in DR0
        add     %eax, %esi              # add segbase to offset
        mov     %esi, %dr0              # breakpoint into DR0

        # Step 4: Activate the code-breakpoint in register DR0
        mov     %dr7, %eax              # get current DR7 settings
        and     $0xFFF0FFFC, %eax       # clear the G0 and L0 bits
        or      $0x00000001, %eax       # enable L0 code-breakpoint
        mov     %eax, %dr7              # update settings in DR7
nobrk:

        # ok, here we display our stack-frame (with labels)
        mov     $sel_es, %ax            # address video memory
        mov     %ax, %es                #   with ES register

        mov     $sel_ds, %ax            # address this segment
        mov     %ax, %ds                #   with DS register
        cld                             # do forward processing
        xor     %ebx, %ebx              # counter starts from 0
nxreg:
        # store next field-label in the info-buffer
        mov     name(, %ebx, 4), %eax   # fetch register label
        mov     %eax, info+1            # store register label

        # store next field-value in the info-buffer
        lea     info+5, %edi            # point to output field
        mov     -44(%ebp, %ebx, 4), %eax
        call    eax2hex                 # store value as hex

        # compute screen-location for this element
        mov     $23, %eax               # bottom item line-number
        sub     %ebx, %eax              # minus the item's number
        #imul    $160, %eax, %edi        # times screen-row's size
        lea     (%eax, %eax, 4), %edi
        shl     $5, %edi
        add     $100, %edi              # and indent to column 50

        mov     color, %ah              # setup color attribute
        mov     -44(%ebp, %ebx, 4), %edx
        cmp     preval(,%ebx,4), %edx
        je      nohigh
        mov     hicolor, %ah
nohigh:
        mov     %edx, preval(,%ebx, 4)

        # transfer info-buffer onto the screen
        lea     info, %esi              # point to info buffer
        mov     $ILEN, %ecx             # setup message length
nxchx:  lodsb                           # fetch message character
        stosw                           # store char and color
        loop    nxchx                   # transfer entire string

        inc     %ebx                    # increment the iterator
        cmp     $RNUM, %ebx             # maximum value reached?
        jl      nxreg                   # no, show next register


        # now await the release of a user's keypress
kbwait:
        in      $0x64, %al              # poll keyboard status
        test    $0x01, %al              # new scancode ready?
        jz      kbwait                  # no, continue polling

        in      $0x60, %al              # input the new scancode
        test    $0x80, %al              # was a key released?
        jz      kbwait                  # no, wait for a release

        # restore the suspended task's registers, and resume

        pop     %es                     # restore saved selectors
        pop     %ds                     # for registers DS and ES
        mov     %ebp, %esp              # discard other stack data
        popal                           # restore saved registers

        iret                            # resume interrupted work

#------------------------------------------------------------------
leave_protected_mode: .code16

        mov     $sel_ds, %ax
        mov     %ax, %ds
        mov     %ax, %es
        mov     %ax, %fs
        mov     %ax, %gs

        mov     %cr0, %eax
        btr     $0, %eax
        mov     %eax, %cr0

        ljmp    $0x1000, $rm
rm:     mov     %cs, %ax
        mov     %ax, %ss

        lidt    %cs:regIVT
        sti

        ret
#------------------------------------------------------------------
        .align  16                      # insure stack's alignment
        .space  256                     # reserved for stack usage
tos:                                    # label real-mode stacktop
#------------------------------------------------------------------
        .end


