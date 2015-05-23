//-----------------------------------------------------------------
//      welcome.s
//
//      This boot-sector replacement program uses some ROM-BIOS 
//      services to write a text-string to the console display.
//
//       to assemble:  $ as welcome.s -o welcome.o
//       and to link:  $ ld welcome.o -T ldscript -o welcome.b
//       and install:  $ dd if=welcome.b of=/dev/sda4
//
//      NOTE: This code begins executing with CS:IP = 0000:7C00
//
//      programmer: ALLAN CRUSE
//      written on: 28 AUG 2008
//-----------------------------------------------------------------

        .section        .text
#------------------------------------------------------------------
        .code16                         # for real-mode execution
        ljmp    $0x07C0, $main          # to address our symbols
#------------------------------------------------------------------
msg:    .ascii  "\r\n Welcome to Computer Science 630 \r\n"
        .ascii  "\n Advanced Microcomputer Programming \r\n"
len:    .short  . - msg                 # length of message string
att:    .byte   0x0A                    # bright green upon black
#------------------------------------------------------------------
        .globl  main
main:   # setup stack area (so we can call ROM-BIOS functions)
        xor     %ax, %ax                # address bottom of memory
        mov     %ax, %ss                #   with the SS register
        mov     $0x7C00, %sp            # set the stacktop address

        # setup segment-registers (so we can use symbol addresses)
        mov     %cs, %ax                # address our program data
        mov     %ax, %ds                #   with the DS register
        mov     %ax, %es                #   also the ES register

        # invoke the ROM-BIOS 'write_string' function
        mov     $0x13, %ah              # function-selector in AH
        mov     $0, %bh                 # vram page-number in BH
        mov     $10, %dh                # row-number goes in DH
        mov     $0, %dl                 # column-number into DL
        mov     $msg, %bp               # point ES:BP to message
        mov     len, %cx                # message-length into CX
        mov     att, %bl                # color attributes in BL
        mov     $1, %al                 # move cursor forward
        int     $0x10                   # invoke BIOS service

        # wait for the user to press a key
        mov     $0x00, %ah              # function-selector in AH
        int     $0x16                   # invoke BIOS service

        # reboot the computer
        int     $0x19
#------------------------------------------------------------------
        .org    510                     # boot-signature's offset
        .byte   0x55, 0xAA              # value of boot-signature
#------------------------------------------------------------------
        .end                            # nothing more to assemble

