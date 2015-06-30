#-----------------------------------------------------------------
#
# himem.s - PC Bootloader for DHBW Kernel
#
#
# Here is a 'boot-loader' that you can use for launching our
# programming demos and exercises.
#
# This boot-loader first demonstrates use of the ROM-BIOS
# 'Get Memory Size' service (int 0x12) in order to find out
# the upper limit on memory available for use in real-mode.
# Then, it loads a chunk of blocks from floppy disk into
# memory starting at address 0x07E0:0000.
#
# If a program with signature word 0xABCD is found at location
# 0x1000:0000, this program is executed with CS:IP = 0x1000:0002.
#
# Otherwise, address 0x1000:0000 is checked for signature string
# 'DHBW', and if found, the program located there is executed
# with CS:IP = 0x1000:addr, where the 16-bit start # address
# 'addr' is stored at location 0x1000:0008.
#
#-----------------------------------------------------------------
# NOTES:
# This code begins executing with CS:IP = 0x07C0:0000
#
#-----------------------------------------------------------------
# LIMITATIONS:
# This bootloader assumes a virtual floppy disk, e.g. as provided
# by qemu. In order to support real floppy drive hardware, drive
# motor control needs to added.
#
#-----------------------------------------------------------------
# Author(s): Ralf Reutemann
#
# $Id: bootload.s,v 3.0 2014/12/14 12:28:23 ralf Exp ralf $
#
#-----------------------------------------------------------------
# Based on cs630ipl.s and memsize.s written by Allan Cruse,
# University of San Francisco, Course CS 630, Fall 2008
#-----------------------------------------------------------------

        #----------------------------------------------------------
        # generate 16-bit code (x86 'real-mode')
        #----------------------------------------------------------
        .code16
        .section        .text

        .global _start
_start:
        #----------------------------------------------------------
        # We better not rely on any particular value of the code
        # segment register CS and therefore use a far jump to load
        # CS and IP with the appropriate values.
        #----------------------------------------------------------
        ljmp   $0x0, $.Lmystart
        #----------------------------------------------------------
        # Bootloader Signature String
        #----------------------------------------------------------
        .ascii  "DHBWBOOT_V3"
        .align  8
        #----------------------------------------------------------
.Lmystart:
        #----------------------------------------------------------
        # initialize our stack segment and stack-pointer
        #----------------------------------------------------------
        xor     %ax, %ax                # address lowest arena
        mov     %ax, %ss                #   with SS register
        mov     $0x7C00, %sp            # stack is beneath code

        #----------------------------------------------------------
        # setup segment-registers to address our data
        #----------------------------------------------------------
        mov     %cs, %ax                # address program data
        mov     %ax, %ds                # with DS register
        mov     %ax, %es                #   also ES register

        #----------------------------------------------------------
        # enable external interrupts
        #----------------------------------------------------------
        sti

        #----------------------------------------------------------
        # clear the screen
        #----------------------------------------------------------
        mov     $0x0F, %ah
        int     $0x10
        xor     %ah, %ah
        int     $0x10

        #----------------------------------------------------------
        # invoke ROM-BIOS service to obtain memory-size (in KB) and
        # use repeated division by ten to convert the value found
        # in AX to a decimal digit-string (without leading zeros)
        #----------------------------------------------------------
        xor     %ax, %ax
        int     $0x12                   # get ram's size into AX
        jc      .Llmemfail
        test    %ax, %ax
        jz      .Llmemfail
        mov     $10, %bx                # divide by 10
        mov     $5, %di                 # initialize buffer-index
.Lnxdgt:xor     %dx, %dx                # extend AX to doubleword
        divw    %bx                     # divide by decimal radix
        add     $'0', %dl               # convert number to ascii
        dec     %di                     # buffer-index moved left
        mov     %dl, mbuf(%di)          # store numeral in buffer
        or      %ax, %ax                # was the quotient zero?
        jnz     .Lnxdgt                 # no, get another numeral
.Llmemfail:
        #----------------------------------------------------------
        # print boot message
        #----------------------------------------------------------
        pushw   $bootmsg_len            # message length
        pushw   $bootmsg                # message offset
        call    showmsg
        #----------------------------------------------------------

        #----------------------------------------------------------
        # read sectors from floppy disk into memory one single
        # sector at a time
        #----------------------------------------------------------
        mov     $go_stage1, %dx
        shr     $4, %dx
        mov     %dx, loadloc+2
        mov     $edata, %dx
        sub     $go_stage1, %dx
        dec     %dx
        and     $0xffe0, %dx
        shr     $9, %dx
        inc     %dx
        mov     %dx, numsec
        mov     $1, %bx
.Lreadloop:
        pushw   $1                      # message length
        pushw   $dot                    # message offset
        call    showmsg
        push    %bx                     # put parameter on stack
        call    read_one_sector
        inc     %bx
        cmp     %dx, %bx
        jbe     .Lreadloop

        pushw   $2                      # message length
        pushw   $crlf                   # message offset
        call    showmsg

        call    go_stage1

        #----------------------------------------------------------
        # print 'reboot' message
        #----------------------------------------------------------
        pushw   $msg0_len               # message length
        pushw   $msg0                   # message offset
.Lwaitkey:
        call    showmsg
        #----------------------------------------------------------
        # await our user's keypress
        #----------------------------------------------------------
        xor     %ah, %ah                # await keyboard input
        int     $0x16                   # request BIOS service

        #----------------------------------------------------------
        # invoke the ROM-BIOS reboot service to reboot this PC
        #----------------------------------------------------------
        int     $0x19
        #----------------------------------------------------------
        # REBOOT
        #----------------------------------------------------------

#------------------------------------------------------------------
# Parameters:
#   - "logical" sector number   [bp+4]
#------------------------------------------------------------------
# INT 13,2 - Read Disk Sectors
#
# AH    = 02
# AL    = number of sectors to read  (1-128 dec.)
# CH    = track/cylinder number  (0-1023 dec., see below)
# CL    = sector number  (1-17 dec.)
# DH    = head number  (0-15 dec.)
# DL    = drive number (0=A:, 1=2nd floppy, 80h=drive 0, 81h=drive 1)
# ES:BX = pointer to buffer
#
# Return:
#  AH   = status  (see INT 13,STATUS)
#  AL   = number of sectors read
#  CF   = 0 if successful, 1 if error
#
#  - BIOS disk reads should be retrievedd at least three times and the
#    controller should be reset upon error detection
#  - be sure ES:BX does not cross a 64K segment boundary or a
#    DMA boundary error will occur
#  - many programming references list only floppy disk register values
#  - only the disk number is checked for validity
#  - the parameters in CX change depending on the number of cylinders;
#    the track/cylinder number is a 10 bit value taken from the 2 high
#    order bits of CL and the 8 bits in CH (low order 8 bits of track):
#
#    |F|E|D|C|B|A|9|8|7|6|5-0|  CX
#     | | | | | | | | | |  v-----  sector number
#     | | | | | | | |  v---------  high order 2 bits of track/cylinder
#     +-+-+-+-+-+-+-+------------  low order 8 bits of track/cyl number
#
#------------------------------------------------------------------
        .align  8
        .type           read_one_sector, @function
        .global         read_one_sector
read_one_sector:
        enter   $0, $0
        pusha
        push    %ds
        push    %es

        #----------------------------------------------------------
        # Sector = log_sec % SECTORS_PER_TRACK
        # Head = (log_sec / SECTORS_PER_TRACK) % HEADS
        # get logical sector number from stack
        #----------------------------------------------------------
        mov     4(%bp), %ax
        xor     %dx, %dx
        mov     $18, %bx
        div     %bx
        mov     %dl, sec
        and     $1, %ax
        mov     %al, head

        #----------------------------------------------------------
        # Track = log_sec / (SECTORS_PER_TRACK*HEADS)
        #----------------------------------------------------------
        mov     4(%bp), %ax
        xor     %dx, %dx
        mov     $18*2, %bx
        div     %bx
        mov     %al, track

        #----------------------------------------------------------
        # load ES:BX with the start address where the sectors
        # from floppy disk will be loaded to
        #----------------------------------------------------------
        les     loadloc, %bx
        #----------------------------------------------------------
        # ah = 0x02 read disk function
        # al = 0x01 read a single sector
        #----------------------------------------------------------
        mov     $0x0201, %ax
        #----------------------------------------------------------
        # read sector into cl and track into ch, combine
        # into a single word read
        #----------------------------------------------------------
        mov     sectrack, %cx
        #----------------------------------------------------------
        # physical sector number starts at 1, so increment
        # logical sector number that has been calculated above
        #----------------------------------------------------------
        inc     %cl
        mov     head, %dh
        #----------------------------------------------------------
        # set drive id to zero (floppy drive)
        #----------------------------------------------------------
        xor     %dl, %dl
        #----------------------------------------------------------
        # use ROM-BIOS service to read from floppy disk
        #----------------------------------------------------------
        int     $0x13
        #----------------------------------------------------------
        # CF is set in case of an error
        #----------------------------------------------------------
        jc      .Lrderr                 # error? exit w/message

        #----------------------------------------------------------
        # increment segmented address by sector size (512 bytes)
        # start address of a segment is a multiple of 16, therefore
        # increment segment address by 32 (= 512/16)
        #----------------------------------------------------------
        addw    $0x20, loadloc+2

        pop     %es
        pop     %ds
        popa
        leave
        ret     $2


#------------------------------------------------------------------
        .align  8
        .type           showmsg, @function
        .global         showmsg
showmsg:
        #----------------------------------------------------------
        # use ROM-BIOS services to write a message to the screen
        #----------------------------------------------------------
        pusha
        mov     %sp, %bp
        mov     20(%bp), %cx
        mov     18(%bp), %bp
        push    %es

        push    %cx                     # preserve string-length
        mov     $0x0F, %ah              # get page-number in BH
        int     $0x10                   # request BIOS service
        mov     $0x03, %ah              # get cursor locn in DX
        int     $0x10                   # request BIOS service
        pop     %cx                     # recover string-length
        mov     %ds, %ax                # address our variables
        mov     %ax, %es                #   using ES register
        mov     $0x0f, %bl              # put text colors in BL
        mov     $0x1301, %ax            # write_string function
        int     $0x10                   # request BIOS service
        pop     %es
        popa
        ret     $4


#------------------------------------------------------------------
.Lrderr:
        lea     msg1, %bp               # message offset
        mov     $msg1_len, %cx          # message length
        jmp     .Lwaitkey
#------------------------------------------------------------------

        .section    .data
        .align  4
sectrack:               # synonym for word access
sec:    .byte   0       #   will go into cl register
track:  .byte   0       #   will go into ch register
head:   .byte   0
#------------------------------------------------------------------
# This is the segmented address where to load the disk-sectors.
# NOTE: this segmented address is updated by the load procedure
# after each read sector, and, finally, points to the memory
# location following the last loaded byte
        .global loadloc
        .align  4
loadloc:.word   0x0000, 0x0000          # offset, segment
#------------------------------------------------------------------
numsec: .word   0x0000
#------------------------------------------------------------------
extmem: .word   0, 0
#------------------------------------------------------------------
msg0:   .ascii  "Hit any key to reboot"
        .equ    msg0_len, (.-msg0)
msg1:   .ascii  "\r\nRead error\r\n"
        .equ    msg1_len, (.-msg1)
bootmsg:.ascii  "\r\n*** DHBW SNP Boot Loader ***"
crlf:   .ascii  "\r\n\r\n"
        .equ    crlf_len, (.-crlf)
        .ascii  "Real-Mode Memory:"
mbuf:   .ascii  "    ? KB\r\n\r\n"      # size to report
        .ascii  "Loading stage1 (one dot per sector)\r\n"
        .equ    bootmsg_len, (.-bootmsg)
dot:    .ascii   "."

