#-----------------------------------------------------------------
# pmhello.s
#
# This program prints a simple welcome message to the screen and
# triggers an exception by calling an unhandled interrupt.
#
#-----------------------------------------------------------------


#==================================================================
# S I G N A T U R E
#==================================================================
        .section        .signature, "a", @progbits
        .long   progname_size
progname:
        .ascii  "PMHELLO"
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
# I N T E R R U P T   D E S C R I P T O R   T A B L E
#------------------------------------------------------------------
        .align  16
        .global theIDT
        #----------------------------------------------------------
theIDT: # allocate 256 gate-descriptors
        #----------------------------------------------------------
        .quad   0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
        #----------------------------------------------------------
        # General Protection Exception (0x0D) gate descriptor
        #----------------------------------------------------------
        .word   isrGPF, privCS, 0x8E00, 0x0000
        #----------------------------------------------------------
        # allocate free space for the remaining unused descriptors
        #----------------------------------------------------------
        .zero   256*8 - (.-theIDT)
        .equ    limIDT, (.-theIDT)-1    # this IDT's segment_limit
#------------------------------------------------------------------
        # image for IDTR register
        #
        #----------------------------------------------------------
        # Note: the linear address offset of the data segment needs
        #       to be added to theIDT at run-time before this IDT
        #       is installed
        #----------------------------------------------------------
        .align  16
        .global regIDT
regIDT: .word   limIDT
        .long   theIDT
#------------------------------------------------------------------
pmmsg:  .ascii  " Hello from protected mode "   # message's text
pmlen:  .long  . - pmmsg                # size of message string

#==================================================================
        .section        .text
        .code32
#------------------------------------------------------------------
# M A I N   F U N C T I O N
#------------------------------------------------------------------
        .type   main, @function
        .global main
main:
        enter   $0, $0
        #pushal

        #----------------------------------------------------------
        # Segment register usage (provided by start.o):
        #   CS - Code Segment
        #   DS - Data Segment
        #   SS - Stack Segment
        #   ES - CGA Video Memory
        #----------------------------------------------------------

        #----------------------------------------------------------
        # copy message string to video memory
        #----------------------------------------------------------
        lea     pmmsg, %esi             # point DS:ESI to message string
        mov     $8*160, %edi            # point ES:EDI to screen
        mov     $0x2E, %ah              # color attribute: yellow on green
        mov     pmlen, %ecx             # string's length in CX
        cld                             # do forward processing
nxchr1: lodsb                           # fetch next character
        stosw                           # store char and color
        loop    nxchr1                  # again if chars remain
        #----------------------------------------------------------

        lea     hex_digits, %esi
        mov     $10*160, %edi            # point ES:EDI to screen
        mov     $0x0f, %ah
        mov     $16, %ecx
nxchr2:
        lodsb
        stosw
        loop    nxchr2

        mov     $11*160, %edi            # point ES:EDI to screen
        mov     $0x0020, %ax
        mov     $16, %ecx
nxchr3:
        stosw
        add     $0x10, %ah
        loop    nxchr3

        lea     hex_digits, %esi
        mov     $12*160, %edi            # point ES:EDI to screen
        mov     $0x0020, %ax
        mov     $16, %ecx
nxchr4:
        lodsb
        stosw
        add     $0x01, %ah
        loop    nxchr4

        #----------------------------------------------------------
        # initialise registers to some values
        #----------------------------------------------------------
        mov     $0x12345678, %eax
        mov     $0xa5a5a5a5, %ebx
        mov     $0x5a5a5a5a, %ecx
        mov     $0xabbaabba, %esi
        mov     $0xebbeebbe, %edi
        pushl   $0x33333333
        pushl   $0x22222222
        pushl   $0x11111111
        #----------------------------------------------------------
        # raise an unhandled interrupt to generate a GPF
        #----------------------------------------------------------
        int     $1

        #popal
        leave
        ret
#------------------------------------------------------------------
        .type   bail_out, @function
        .global bail_out
bail_out:
        cli
        hlt
#------------------------------------------------------------------
        .end

