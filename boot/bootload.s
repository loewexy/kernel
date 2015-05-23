#-----------------------------------------------------------------
#
# bootload.s - PC Bootloader for DHBW Kernel
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
# If a program with signature word 0xBEEF is found at this
# location, this program is executed with CS:IP = 0x07E0:0010.
#
# Otherwise, address 0x1000:0000 is checked for signature
# word 0xCAFE, and if found, the program located there is
# executed with CS:IP = 0x1000:addr, where the 16-bit start
# address 'addr' is stored at location 0x1000:0002.
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
# $Id: bootload.s,v 2.0 2014/10/03 18:59:34 ralf Exp ralf $
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

        #----------------------------------------------------------
        # Tell the assembler that our code starts at offset 0.
        # By doing so, our code can easily be relocated by changing
        # the value of the segment register. This offset can also
        # be passed to the linker using the -Ttext option.
        #----------------------------------------------------------
        .org 0

        .global _start
_start:
        #----------------------------------------------------------
        # We better not rely on any particular value of the code
        # segment register CS and therefore use a far jump to load
        # CS and IP with the appropriate values.
        #----------------------------------------------------------
        ljmp   $0x07C0, $mystart
        #----------------------------------------------------------
        # Bootloader Signature String
        #----------------------------------------------------------
        .ascii  "DHBWBOOT_V2"
        .align  8
        #----------------------------------------------------------
mystart:
        #----------------------------------------------------------
        # initialize our stack-pointer for servicing interrupts
        #----------------------------------------------------------
        xor     %ax, %ax                # address lowest arena
        mov     %ax, %ss                #   with SS register
        mov     $0x7C00, %sp            # stack is beneath code

        #----------------------------------------------------------
        # enable external interrupts
        #----------------------------------------------------------
        sti

        #----------------------------------------------------------
        # setup segment-registers to address our program-data
        #----------------------------------------------------------
        mov     %cs, %ax                # address program data
        mov     %ax, %ds                # with DS register
        mov     %ax, %es                #   also ES register

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
        int     $0x12                   # get ram's size into AX
        mov     $5, %di                 # initialize buffer-index
nxdgt:  xor     %dx, %dx                # extend AX to doubleword
        divw    ten                     # divide by decimal radix
        add     $'0', %dl               # convert number to ascii
        dec     %di                     # buffer-index moved left
        mov     %dl, mbuf(%di)          # store numeral in buffer
        or      %ax, %ax                # was the quotient zero?
        jnz     nxdgt                   # no, get another numeral

        lea     mmsg, %bp               # message-offset in BP
        mov     mmlen, %cx              # message-length in CX
        call    showmsg
        #----------------------------------------------------------

        #----------------------------------------------------------
        # read sectors from floppy disk into memory one single
        # sector at a time
        #----------------------------------------------------------
        mov     $1, %cx
readloop:
        push    %cx                     # put parameter on stack
        call    read_one_sector
        add     $2, %sp                 # remove parameter again
        inc     %cx
        cmp     $512, %cx
        jbe     readloop

        #----------------------------------------------------------
        # check for our application signature
        #----------------------------------------------------------
        les     progloc, %di            # point ES:DI to program location
        cmpw    $0xCAFE, %es:(%di)      # our signature there?
        mov     %es:2(%di), %ax         # store segment offset
        je      load_prog               # yes, load program

        #----------------------------------------------------------
        # check for orignal USF signature
        #----------------------------------------------------------
        les     progloc, %di            # point ES:DI to program location
        cmpw    $0xABCD, %es:(%di)      # our signature there?
        jne     inval                   # no, format not valid
        mov     $2, %ax

load_prog:
        #----------------------------------------------------------
        # push segment and address offset of return location
        #----------------------------------------------------------
        pushw   %cs
        pushw   $cleanup
        #----------------------------------------------------------
        # push segment and address offset of target location
        #----------------------------------------------------------
        pushw   %es
        pushw   %ax
        #----------------------------------------------------------
        # jump to target location
        #----------------------------------------------------------
        lret
cleanup:
        #----------------------------------------------------------
        # accommodate 'quirk' in some ROM-BIOS service-functions
        #----------------------------------------------------------
        mov     %cs, %ax                # address our variables
        mov     %ax, %ds                #   using DS register
        lgdt    regGDT                  # setup register GDTR
        cli                             # turn off interrupts
        mov     %cr0, %eax              # get machine status
        bts     $0, %eax                # set image of PE-bit
        mov     %eax, %cr0              # enter protected-mode
        mov     $8, %dx                 # descriptor's selector
        mov     %dx, %fs                # for 4GB segment-limit
        mov     %dx, %gs                # both in FS and in GS
        btr     $0, %eax                # reset image of PE-bit
        mov     %eax, %cr0              # leave protected-mode
        sti                             # interrupts on again

        #----------------------------------------------------------
        # show the user our 'reboot' message
        #----------------------------------------------------------
        lea     msg0, %bp               # message-offset in BP
        mov     len0, %cx               # message-length in CX
waitkey:
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
rderr:  lea     msg1, %bp               # message-offset in BP
        mov     len1, %cx               # message-length in CX
        jmp     waitkey
#------------------------------------------------------------------
inval:  lea     msg2, %bp               # message-offset in BP
        mov     len2, %cx               # message-length in CX
        jmp     waitkey
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
#  - BIOS disk reads should be retried at least three times and the
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
read_one_sector:
        push    %bp
        mov     %sp, %bp
        pusha

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
        jc      rderr                   # error? exit w/message

        #----------------------------------------------------------
        # increment segmented address by sector size (512 bytes)
        #----------------------------------------------------------
        addw    $0x20, loadloc+2        # add sector size to segment

        popa
        pop     %bp
        ret
#------------------------------------------------------------------
showmsg:
        #----------------------------------------------------------
        # use ROM-BIOS services to write a message to the screen
        #----------------------------------------------------------
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
        ret

#------------------------------------------------------------------
sectrack:           # synonym for word access
sec:    .byte  0    #   will go into cl register
track:  .byte  0    #   will go into ch register
head:   .byte  0
#------------------------------------------------------------------
# This bootloader supports loading programs to two different
# locations in memory, based on a signature word stored in the
# first two bytes of the program image.
#
# Segmented address where to find the program
progloc:.word   0x0000, 0x1000          # offset, segment
#------------------------------------------------------------------
# This is the segmented address where to load the disk-sectors.
# NOTE: this segmented address is updated by the load procedure
# after each read sector, and, finally, points to the memory
# location following the last loaded byte
loadloc:.word   0x0000, 0x07E0          # offset, segment
#------------------------------------------------------------------
msg0:   .ascii  "Hit any key to reboot\r\n"  # message-text
len0:   .short  . - msg0                # length of message-string
msg1:   .ascii  "Read error\r\n"      # message-text
len1:   .short  . - msg1                # length of message-string
msg2:   .ascii  "Signature error\r\n"   # message-text
len2:   .short  . - msg2                # length of message-string
ten:    .short  10                      # decimal-system's radix
mmsg:   .ascii  "\r\n*** DHBW SNP Boot Loader ***\r\n\r\n"
        .ascii  "Real-Mode Memory:"
mbuf:   .ascii  "    0 KB\r\n\n"        # size to report
mmlen:  .short  . - mmsg                # message length
#------------------------------------------------------------------
theGDT: .quad   0, 0x008F92000000FFFF   # has 4GB data-descriptor
regGDT: .word   15, theGDT + 0x7C00, 0  # image for register GDTR
#------------------------------------------------------------------
        .end                            # nothing more to assemble

