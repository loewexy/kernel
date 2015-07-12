#-----------------------------------------------------------------
# pgftdemo.s
#
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
        # equates for ISRs
        #----------------------------------------------------------
        .equ    ISR_PFE_ID,     0x0E   # Page Fault Exception

        #----------------------------------------------------------
        # equates for IRQs
        #----------------------------------------------------------
        .equ    IRQ_PIT_ID,     0x00
        .equ    IRQ_UART_ID,    0x04


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


#------------------------------------------------------------------
# G L O B A L   D E S C R I P T O R   T A B L E
#------------------------------------------------------------------
        .align  16
        .global theGDT
theGDT:
        .include "comgdt.inc"
        #----------------------------------------------------------
        # Code/Data, 32 bit, 4kB, Priv 0, Type 0x02, 'Read/Write'
        # Base Address: 0x00000000   Limit: 0x000fffff
        .equ    linDS, (.-theGDT)       # selector for data
        .globl  linDS
        .quad   0x00CF92000000FFFF      # data segment-descriptor
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
        # IDT is defined in isr.o in libkernel library
#------------------------------------------------------------------

        #----------------------------------------------------------
        # output string for page directory address
        #----------------------------------------------------------
pgdirmsg:
        .ascii  "Page Directory is at linear address 0x"
pgdiraddr:
        .ascii  "________\n"
        .equ    pgdirmsg_len, (.-pgdirmsg)

rwchar: .ascii  "RW"

oldesp: .long   0x00000000

#==================================================================
# S E C T I O N   T E X T
#==================================================================
        .section        .text
        .code32
#------------------------------------------------------------------
# M A I N   F U N C T I O N
#------------------------------------------------------------------
        .type   main, @function
        .global main
        .extern init_paging
        .extern enable_paging
        .extern int_to_hex
        .extern screen_write
        .extern screen_sel_page
        .extern run_monitor
main:
        enter   $0, $0
        pushal
        push    %gs
        mov     %esp, oldesp    # save stack pointer

        #----------------------------------------------------------
        # Segment register usage (provided by start.o):
        #   CS - Code Segment
        #   DS - Data Segment
        #   SS - Stack Segment
        #   ES - CGA Video Memory
        #----------------------------------------------------------

        #----------------------------------------------------------
        # install interrupt/exception handlers
        #----------------------------------------------------------
        INSTALL_IRQ IRQ_PIT_ID, irqPIT
        #INSTALL_IRQ IRQ_UART_ID, irqUART
        INSTALL_ISR ISR_PFE_ID, isrPFE

        #----------------------------------------------------------
        # reprogram PICs and enable hardware interrupts
        #----------------------------------------------------------
        call    remap_isr_pm
        sti

        #----------------------------------------------------------
        # initialise multi-page console
        #----------------------------------------------------------
        xor     %eax, %eax       # select page #0
        call    screen_sel_page

        #----------------------------------------------------------
        # initialise page directory and page tables
        # page directory address will be returned in EAX
        #----------------------------------------------------------
        call    init_paging

        #----------------------------------------------------------
        # enable paging
        # page directory address expected in EAX
        #----------------------------------------------------------
        call    enable_paging

        #----------------------------------------------------------
        # print the page directory address
        #----------------------------------------------------------
        mov     %cr3, %eax
        lea     pgdiraddr, %edi
        mov     $8, %ecx
        call    int_to_hex
        lea     pgdirmsg, %esi          # message-offset into ESI
        mov     $pgdirmsg_len, %ecx     # message-length into ECX
        call    screen_write

        #----------------------------------------------------------
        # setup GS segment register for linear addressing
        #----------------------------------------------------------
        mov     $linDS, %ax
        mov     %ax, %gs

        .type   pfcontinue, @function
        .global pfcontinue
pfcontinue:
        mov     oldesp, %esp      # restore stack pointer
        call    run_monitor

        #----------------------------------------------------------
        # in order to succesfully go back to the boot loader we
        # have to disable paging first
        #----------------------------------------------------------
        call    disable_paging

        #-----------------------------------------------------------
        # disable hardware interrupts
        #-----------------------------------------------------------
        cli

        #-----------------------------------------------------------
        # load appropriate ring0 data segment descriptor
        #-----------------------------------------------------------
        mov     $privDS, %ax
        mov     %ax, %ds

        #-----------------------------------------------------------
        # reprogram PICs to their original setting
        #-----------------------------------------------------------
        call    remap_isr_rm

        #----------------------------------------------------------
        # trigger triple fault in order to reboot
        #----------------------------------------------------------
        movl    $0, theIDT+13*8
        movl    $0, theIDT+13*8+4
        lidt    theIDT
        int     $13
        hlt     # just in case ;-)

        #----------------------------------------------------------
        # NOT EXECUTED
        #----------------------------------------------------------
        pop     %gs
        popal
        leave
        ret

#------------------------------------------------------------------
# disable interrupts and halt processor
# will be called by the General Protection Fault ISR
#------------------------------------------------------------------
        .type   bail_out, @function
        .global bail_out
bail_out:
        cli
        hlt
#------------------------------------------------------------------
        .end

