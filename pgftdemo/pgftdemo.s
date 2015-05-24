#-----------------------------------------------------------------
# pgftdemo.s
#
#-----------------------------------------------------------------


#==================================================================
# S I G N A T U R E
#==================================================================
        .section        .signature, "a", @progbits
        .long   progname_size
progname:
        .ascii  "PGFTDEMO"
        .equ    progname_size, (.-progname)
        .byte   0


#==================================================================
# S E C T I O N   D A T A
#==================================================================

        .section        .data

        .equ    DATA_START, 0x20000

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
        .align  16
        .global regGDT
regGDT: .word   limGDT
        .long   theGDT+DATA_START       # create linear address
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

        #----------------------------------------------------------
        # image for IDTR register
        #----------------------------------------------------------
        .align  16
        .global regIDT
regIDT: .word   limIDT
        .long   theIDT+DATA_START       # create linear address

#------------------------------------------------------------------

        #----------------------------------------------------------
        # output string for page fault result structure
        #----------------------------------------------------------
pgftmsg:.ascii  "________ "             # faulting address
        .ascii  "PDE:___ "
        .ascii  "PTE:___ "
        .ascii  "OFF:___ "
        .ascii  "________ "
        .ascii  "____\n"
        .equ    pgftmsg_len, (.-pgftmsg)

        #----------------------------------------------------------
        # address samples
        #----------------------------------------------------------
samples:.long   0x00010000, 0x000100ff, 0x00020000, 0x00020abc
        .long   0x000B8000, 0x000110ff, 0x08048000, 0x08048000
        .long   0xfffffffc, 0x08000000, 0x08048123, 0x08049321
        .long   0x08051c00, 0x08050abc, 0x60000000, 0x08048fff
        .long   0x08049004, 0x00000000


#==================================================================
        .section        .text
        .code32
#------------------------------------------------------------------
# M A I N   F U N C T I O N
#------------------------------------------------------------------
        .type   main, @function
        .global main
        .extern pfhandler
        .extern int_to_hex
        .extern screen_write
        .extern screen_sel_page
main:
        enter   $0, $0
        pushal

        #----------------------------------------------------------
        # Segment register usage (provided by start.o):
        #   CS - Code Segment
        #   DS - Data Segment
        #   SS - Stack Segment
        #   ES - CGA Video Memory
        #----------------------------------------------------------

        xor     %eax, %eax
        call    screen_sel_page
        #----------------------------------------------------------
        # read address samples from array
        # end of array is indicated by zero address
        #----------------------------------------------------------
        xor     %ecx, %ecx
read_samples:
        mov     samples(,%ecx,4), %eax
        test    %eax, %eax
        jz      read_done
        pushl   %ecx

        pushl   %eax
        call    pfhandler
        add     $4, %esp
        mov     %eax, %esi

        #----------------------------------------------------------
        # Convert 32-bit integers to hex strings
        # eax - value to output as 32-bit unsigned integer
        # edi - pointer to output string
        # ecx - number of output digits
        #----------------------------------------------------------
        mov     (%esi), %eax      # faulting address
        lea     pgftmsg, %edi
        mov     $8, %ecx
        call    int_to_hex

        mov     4(%esi), %eax     # PDE
        lea     pgftmsg+13, %edi
        mov     $3, %ecx
        call    int_to_hex

        mov     8(%esi), %eax     # PTE
        lea     pgftmsg+21, %edi
        mov     $3, %ecx
        call    int_to_hex

        mov     12(%esi), %eax    # address offset
        lea     pgftmsg+29, %edi
        mov     $3, %ecx
        call    int_to_hex

        mov     16(%esi), %eax    # physical address
        lea     pgftmsg+33, %edi
        mov     $8, %ecx
        call    int_to_hex

        mov     20(%esi), %eax    # flags
        lea     pgftmsg+42, %edi
        mov     $4, %ecx
        call    int_to_hex

        lea     pgftmsg, %esi           # message-offset into ESI
        mov     $pgftmsg_len, %ecx      # message-length into ECX
        call    screen_write
        popl    %ecx
        inc     %ecx
        jmp     read_samples
read_done:

        popal
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

