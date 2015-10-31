

#------------------------------------------------------------------
# G L O B A L   D E S C R I P T O R   T A B L E
#------------------------------------------------------------------
        .section    .data
#------------------------------------------------------------------
        .align  16
theGDT:
        #----------------------------------------------------------
        .quad   0x0000000000000000      # null segment-descriptor
        #----------------------------------------------------------
        # Code/Data, 32 bit, 4kB, Priv 0, Type 0x0a, 'Execute/Read'
        # Base Address: 0x00000000   Limit: 0x0000ffff
        .quad   0x00CF92000000FFFF      # code segment-descriptor
        #----------------------------------------------------------
        .equ    limGDT, (.-theGDT)-1    # our GDT's segment-limit
#------------------------------------------------------------------
        .align  16
        #----------------------------------------------------------
        # image for GDTR register
        #----------------------------------------------------------
        .global regGDT
regGDT:
        .word   limGDT
        .long   theGDT
#------------------------------------------------------------------
        .align  16
        .global theIDT
theIDT:
        #----------------------------------------------------------
        .zero   256*8 - (.-theIDT)
        .equ    limIDT, (.-theIDT)-1    # this IDT's segment_limit
#------------------------------------------------------------------
        # image for IDTR register
        .align  16
        .global regIDT
regIDT: .word   limIDT
        .long   theIDT
#-----------------------------------------------------------------


        #----------------------------------------------------------
        # generate 16-bit code (x86 'real-mode')
        #----------------------------------------------------------
        .code16
        .section        .text

        .align  8
        .global go_stage1
go_stage1:
        enter   $0, $0
        pusha
        push    %ds
        push    %es

        #----------------------------------------------------------
        # preserve the caller's stack-address (for a return later)
        #----------------------------------------------------------
        mov     %sp, rmstack+0          # save SP register-value
        mov     %ss, rmstack+2          # save SS register-value

        #----------------------------------------------------------
        # store real-mode IVT
        #----------------------------------------------------------
        sidt    rmIVT

        #----------------------------------------------------------
        # turn on the A20 address-line
        #----------------------------------------------------------
        call    a20_enable
        mov     %al, a20_enabled

        mov     $memsizes, %di
        call    check_memory_avail

        call    load_extmem

        push    $cmos_rtc_reg
        call    read_cmos_rtc

        pushw   $cmos_rtc_str_len        # message length
        pushw   $cmos_rtc_str            # message offset
        call    showmsg

        call    load_prog
        test    %ax, %ax
        jz      retloc

        #----------------------------------------------------------
        # push segment and address offset of return location
        #----------------------------------------------------------
        pushw   %cs
        pushw   $retloc
        #----------------------------------------------------------
        # push segment and address offset of target location
        #----------------------------------------------------------
        pushw   %es
        pushw   %ax
        #----------------------------------------------------------
        # jump to target location
        #----------------------------------------------------------
        lret
        #==========================================================

        #----------------------------------------------------------
        # return location
        #----------------------------------------------------------
retloc:
        #----------------------------------------------------------
        # setup segment-registers to address our program-data
        #----------------------------------------------------------
        mov     %cs, %ax                # address program data
        mov     %ax, %ds                # with DS register
        mov     %ax, %es                #   also ES register

        #----------------------------------------------------------
        # restore real-mode stack-address and return to boot loader
        #----------------------------------------------------------
        lss     rmstack, %sp            # recover saved (SS:SP)

        pop     %es
        pop     %ds
        popa
        leave
        ret


#------------------------------------------------------------------
        .section    .data
#------------------------------------------------------------------
        .align  16
#------------------------------------------------------------------
# real-mode stack pointer and segment
#------------------------------------------------------------------
rmstack:        .word   0, 0            # 32-bit ss:sp  (16-bit RM)
#------------------------------------------------------------------
# here goes the backup of the real-mode interrupt vector table
#------------------------------------------------------------------
rmIVT:          .word   0x0000, 0x0000, 0x0000
#------------------------------------------------------------------
a20_enabled:    .byte   0x00
#------------------------------------------------------------------
                .align  4
memsizes:       .word   0, 0, 0
#------------------------------------------------------------------
cmos_rtc_reg:   .byte      0,    0,    0,    0,    0,    0
cmos_rtc_str:   .ascii  "hh:mm:ss YY-MM-DD"
                .ascii  "\r\n\r\n"
                .equ    cmos_rtc_str_len, (.-cmos_rtc_str)

#------------------------------------------------------------------
        .end                            # nothing more to assemble
#------------------------------------------------------------------

