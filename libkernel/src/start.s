#-----------------------------------------------------------------
# start.s
#
# This module contains the '_start' program entry point and
# program signature word. It transfers from 16-bit real-mode
# to 32-bit protected mode and calls the 'main' function of
# some other module. After completion of the main function,
# it returns back to 16-bit real-mode and finally back to the
# boot loader.
#
# NOTE: This program begins executing with CS:IP = 0x1000:OFFS,
# where the 16-bit offset to _start (OFFS) is stored in location
# 0x1000:0002.
#
#-----------------------------------------------------------------


#==================================================================
        .section        .signature, "a", @progbits
        .ascii  "DHBW"                  # application 'signature'
        .long   0
        .long   _start                  # store start address
        .long   etext
        .long   edata


        .equ    selPM32, 0x10
        .equ    selRM16, 0x18

#==================================================================
# SECTION .data
#==================================================================
        .section        .data
        .align  4
#------------------------------------------------------------------
# real-mode stack pointer and segment
#------------------------------------------------------------------
rmstack:.word   0, 0                    # 32-bit ss:sp  (16-bit RM)
#------------------------------------------------------------------
# here goes the backup of the real-mode interrupt vector table
#------------------------------------------------------------------
rmIVT:  .word   0x0000, 0x0000, 0x0000  # image for IDTR register
#------------------------------------------------------------------
#
#  struct tm {
#      int tm_sec;         /* seconds (SS) */
#      int tm_min;         /* minutes (MM) */
#      int tm_hour;        /* hours (HH) */
#      int tm_mday;        /* day of the month (DD) */
#      int tm_mon;         /* month (MM) */
#      int tm_year;        /* year (YY) */
#      int tm_wday;        /* day of the week */
#      int tm_yday;        /* day in the year */
#      int tm_isdst;       /* daylight saving time */
#  };
#
#------------------------------------------------------------------
# CMOS RTC data structures
#
#                         SS    MM    HH    DD    MM    YY
#------------------------------------------------------------------
cmos_rtc_idx:   .byte   0x00, 0x02, 0x04, 0x07, 0x08, 0x09
cmos_str_idx:   .byte      6,    3,    0,   15,   12,    9
cmos_rtc_reg:   .byte      0,    0,    0,    0,    0,    0
cmos_rtc_dt:    .ascii  "hh:mm:ss YY-MM-DD"
#------------------------------------------------------------------
a20_enabled:    .byte   0x00
#------------------------------------------------------------------
                .align  4
memsizes:       .word   0, 0, 0


#==================================================================
# 16-Bit Code
# SECTION .text16
#==================================================================
        .section        .text16, "ax", @progbits
        .code16
        .globl  _start
_start:

        #----------------------------------------------------------
        # disable hardware interrupts
        #----------------------------------------------------------
        cli

        #----------------------------------------------------------
        # setup real-mode data segments
        #----------------------------------------------------------
        mov     $0x2000, %ax
        mov     %ax, %ds
        mov     %ax, %es
        mov     %ax, %gs

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

        mov     $memsizes, %di
        call    detect_memory

        call    read_cmos_rtc

        #----------------------------------------------------------
        # enable protected mode
        #----------------------------------------------------------
        mov     %cr0, %eax              # get machine status
        bts     $0, %eax                # set PE-bit's image
        mov     %eax, %cr0              # turn on the PE-bit

        #----------------------------------------------------------
        # load new GDT and IDT for protected mode
        #----------------------------------------------------------
        lgdtl   regGDT
        lidtl   regIDT

        #----------------------------------------------------------
        # transfer to 32-bit protected mode via call gate
        #----------------------------------------------------------
        lcall   $selPM32, $0

        #----------------------------------------------------------
        # transfer to this location from protected mode is via call
        # gate
        #----------------------------------------------------------
        .global rm_enter
rm_enter:
        cli

        #----------------------------------------------------------
        # disable protected mode
        #----------------------------------------------------------
        mov     %cr0, %eax              # get machine's status
        btr     $0, %eax                # clear PE-bit's image
        mov     %eax, %cr0              # turn off protection

        #----------------------------------------------------------
        # clear 32-bit registers
        #----------------------------------------------------------
        xor     %eax, %eax
        xor     %ebx, %ebx
        xor     %ecx, %ecx
        xor     %edx, %edx
        xor     %esi, %esi
        xor     %edi, %edi

        #----------------------------------------------------------
        # return to real-mode...
        #----------------------------------------------------------
        ljmp    $0x1000, $rm            # code-segment into CS
rm:
        #----------------------------------------------------------
        # restore real-mode interrupt vector table
        #----------------------------------------------------------
        mov     $0x2000, %ax
        mov     %ax, %ds
        lidt    rmIVT

        #----------------------------------------------------------
        # restore real-mode stack-address and return to boot loader
        #----------------------------------------------------------
        lss     rmstack, %sp            # recover saved (SS:SP)
        #----------------------------------------------------------
        # re-enable hardware interrupts again
        #----------------------------------------------------------
        sti

        #----------------------------------------------------------
        # far-return to boot loader
        #----------------------------------------------------------
        lret


#------------------------------------------------------------------
        .align  8
read_cmos_rtc:
#
# This procedure reads the date/time fields from the CMOS RTC
#
        enter   $0, $0
        pushaw

.Lwait_rtc_uip_set:
        mov     $0x8A, %ax
        out     %al, $0x70
        in      $0x71, %al
        test    $0x80, %al
        jz      .Lwait_rtc_uip_set

.Lwait_rtc_uip_clear:
        mov     $0x0A, %ax
        out     %al, $0x70
        in      $0x71, %al
        test    $0x80, %al
        jnz     .Lwait_rtc_uip_clear

        xor     %si, %si
.Lrtc_reg_loop:
        mov     cmos_rtc_idx(%si), %al
        out     %al, $0x70
        in      $0x71, %al
        mov     %al, %bh
        and     $0xf, %bh
        shr     $4, %al
        mov     %al, %bl

        mov     $10, %dl
        mov     %bl, %al
        mul     %dl
        add     %bh, %al
        mov     %al,cmos_rtc_reg(%si)

        add     $0x3030, %bx
        movzxb  cmos_str_idx(%si),%di
        mov     %bx, cmos_rtc_dt(%di)
        inc     %si
        cmp     $6, %si
        jb      .Lrtc_reg_loop

        popaw
        leave
        ret


#------------------------------------------------------------------
        .align  8
a20_enable:
        enter   $0, $0

        call    a20_is_enabled
        mov     %al, a20_enabled
        test    %al, %al
        jnz     .La20_enabled

        mov     $0x2401, %ax
        int     $0x15                   # enable A20 using BIOS

        call    a20_is_enabled
        shl     $1, %al
        or      %al, a20_enabled
        test    %al, %al
        jnz     .La20_enabled

        in      $0x92, %al              # System Control Port
        or      $0x02, %al              # set bit #1 (Fast_A20)
        and     $0xfe, %al              # mask-out bit #0
        out     %al, $0x92              # output port settings

        call    a20_is_enabled
        shl     $2, %al
        or      %al, a20_enabled
.La20_enabled:
        leave
        ret


#------------------------------------------------------------------
        .align  8
a20_is_enabled:
        enter   $0, $0
        push    %ds
        push    %es

        #----------------------------------------------------------
        # the bootload signature 0x55aa is at location 0x0000:0x0500
        # in case the A20 address line is disabled, the address
        # 0xffff:0x0510 is wrapped-around to the same address above
        #----------------------------------------------------------
        xor     %ax, %ax
        mov     %ax, %es          # es = 0x0000
        mov     $0x0500, %di      # bootloader signature address
        not     %ax
        mov     %ax, %ds          # ds = 0xffff
        mov     $0x0510, %si      # wrapped-around address

        movb    %es:(%di), %al    # al <- *(0x0000:0x0500)
        movb    %ds:(%si), %ah    # ah <- *(0xffff:0x0510)
        push    %ax               # save original values on stack

        movb    $0x00, %es:(%di)
        movb    $0xff, %ds:(%si)
        cmpb    $0xff, %es:(%di)

        pop     %ax               # restore values from stack
        movb    %al, %es:(%di)
        movb    %ah, %ds:(%si)
        setne   %al

        pop     %es
        pop     %ds
        leave
        ret


#------------------------------------------------------------------
        .align  8
detect_memory:
        enter   $0, $0
        pusha

        #----------------------------------------------------------
        # invoke ROM-BIOS service to obtain memory-size (in KB)
        #----------------------------------------------------------
        xor     %ax, %ax
        int     $0x12        # get ram size below 1MB into AX
        jc      .Lerr
        test    %ax, %ax
        jz      .Lerr
        mov     %ax, (%di)

        xor     %cx, %cx
        xor     %dx, %dx
        mov     $0xe801, %ax
        int     $0x15        # request upper memory size
        jc      .Lerr
        cmp     $0x86, %ah   # unsupported function?
        je      .Lerr
        cmp     $0x80, %ah   # invalid command?
        je      .Lerr
        jcxz    .Luseax      # was the CX result invalid?
        mov     %cx, %ax
        mov     %dx, %bx
.Luseax:
        # AX = number of contiguous Kb, 1M to 16M
        # BX = contiguous 64Kb pages above 16M
        mov     %ax, 2(%di)
        mov     %bx, 4(%di)
.Lerr:
        popa
        leave
        ret


#==================================================================
# SECTION .data
#==================================================================
        .section        .data

#------------------------------------------------------------------
# protected mode stack pointer and segment
#------------------------------------------------------------------
        .align  4
pmstack:.long   0x4000                  # 48-bit ss:esp (32-bit PM)
        .word   privSS

#------------------------------------------------------------------
# seconds since epoche
#------------------------------------------------------------------
        .align  4
        .globl  ticks
ticks:  .long   0
#------------------------------------------------------------------


#==================================================================
# 32-Bit Code
# SECTION .text
#==================================================================
        .section        .text
        .code32
        .global pm_enter
        .align  8
pm_enter:
        #----------------------------------------------------------
        # setup protected-mode data segments
        #----------------------------------------------------------
        mov     $privDS, %ax
        mov     %ax, %ds
        mov     %ax, %gs

        #----------------------------------------------------------
        # setup protected-mode stack segment
        #----------------------------------------------------------
        lss     pmstack, %esp

        #----------------------------------------------------------
        # initialise bss section with zero words
        #----------------------------------------------------------
        mov     $bss, %edi
        xor     %eax, %eax
        mov     $end, %ecx
        sub     %edi, %ecx
        shr     $2, %ecx
        cld
        rep     stosl

        #----------------------------------------------------------
        # setup access to CGA video memory using the ES segment
        #----------------------------------------------------------
        mov     $sel_es, %ax
        mov     %ax, %es

        #----------------------------------------------------------
        # convert RTC segmented time to ticks value
        #----------------------------------------------------------
        push    $cmos_rtc_reg
        call    rtc_mktime
        add     $4, %esp
        mov     %eax, ticks

        #----------------------------------------------------------
        # call kernel main routine...
        #----------------------------------------------------------
        call    main

        #----------------------------------------------------------
        # transfer back to 16-bit real-mode via call gate
        #----------------------------------------------------------
        lcall    $selRM16, $0


#------------------------------------------------------------------
        .end                            # nothing more to assemble
#------------------------------------------------------------------

