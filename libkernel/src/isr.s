
        # equates for reprogramming the Interrupt Controllers
        .equ    OLD_IRQBASE1, 0x08      # default base for master PIC
        .equ    OLD_IRQBASE2, 0x70      # default base for slave PIC
        .equ    NEW_IRQBASE1, 0x20      # revised base for master PIC
        .equ    NEW_IRQBASE2, 0x28      # revised base for slave PIC

#-----------------------------------------------------------------
# M A C R O S
#-----------------------------------------------------------------
    .macro  ISR_WE id
        .align  16
        .Lisr\id:
        cli                             # disable hardware interrupts
        pushl   $\id                    # push interrupt-ID
        jmp     .Lisr_common_stub       # goto common ISR handler
    .endm

    .macro  ISR_NE id
        .align  16
        .Lisr\id:
        cli                             # disable hardware interrupts
        pushl   $0                      # push dummy error code onto stack
        pushl   $\id                    # push interrupt-ID
        jmp     .Lisr_common_stub       # goto common ISR handler
    .endm

    .macro  IRQ_CALL id irq
        .align  16
        .Lirq\irq:
        .Lisr\id:
        cli                             # disable hardware interrupts
        pushl   $0                      # push dummy error code onto stack
        pushl   $\id                    # push interrupt-ID
        jmp     .Lisr_common_stub       # goto common ISR handler
    .endm
#-----------------------------------------------------------------


#------------------------------------------------------------------
# I N T E R R U P T   D E S C R I P T O R   T A B L E
#------------------------------------------------------------------
        .section        .data
        .align  16
        .global theIDT
theIDT:
        #----------------------------------------------------------
        # 0x00: Divide By Zero Exception
        .word   .Lisr0,  privCS, 0xEF00, 0x0000
        #----------------------------------------------------------
        # 0x01: Single-Step Exception
        .word   .Lisr1,  privCS, 0xEF00, 0x0000
        #----------------------------------------------------------
        # 0x02: Non Maskable Interrupt Exception
        .word   .Lisr2,  privCS, 0xEF00, 0x0000
        #----------------------------------------------------------
        # 0x03: Int 3 Exception
        .word   .Lisr3,  privCS, 0xEF00, 0x0000
        #----------------------------------------------------------
        # 0x04: INTO Exception
        .word   .Lisr4,  privCS, 0xEF00, 0x0000
        #----------------------------------------------------------
        # 0x05: Out of Bounds Exception
        .word   .Lisr5,  privCS, 0xEF00, 0x0000
        #----------------------------------------------------------
        # 0x06: Invalid Opcode Exception
        .word   .Lisr6,  privCS, 0xEF00, 0x0000
        #----------------------------------------------------------
        # 0x07: Coprocessor Not Available Exception
        .word   .Lisr7,  privCS, 0xEF00, 0x0000
        #----------------------------------------------------------
        # 0x08: Double Fault Exception
        .word   .Lisr8,  privCS, 0xEF00, 0x0000
        #----------------------------------------------------------
        # 0x09: Coprocessor Segment Overrun Exception
        .word   .Lisr9,  privCS, 0xEF00, 0x0000
        #----------------------------------------------------------
        # 0x0A: Bad TSS Exception
        .word   .Lisr10, privCS, 0xEF00, 0x0000
        #----------------------------------------------------------
        # 0x0B: Segment-Not-Present Exceptions
        .word   .Lisr11, privCS, 0x8E00, 0x000
        #----------------------------------------------------------
        # 0x0C: Stack Fault Exception
        .word   .Lisr12, privCS, 0xEF00, 0x0000
        #----------------------------------------------------------
        # 0x0D: General Protection Exception
        .word   isrGPF, privCS, 0x8E00, 0x0000
        #----------------------------------------------------------
        # 0x0E: Page Fault Exception
        .word   .Lisr14, privCS, 0xEF00, 0x0000
        #----------------------------------------------------------
        # 0x0F: Reserved Exception
        .word   .Lisr15, privCS, 0xEF00, 0x0000
        #----------------------------------------------------------
        # 0x10: Floating Point Exception
        .word   .Lisr16, privCS, 0xEF00, 0x0000
        #----------------------------------------------------------
        # 0x11: Alignment Check Exception
        .word   .Lisr17, privCS, 0xEF00, 0x0000
        #----------------------------------------------------------
        # 0x12: Machine Check Exception
        .word   .Lisr18, privCS, 0xEF00, 0x0000
        #----------------------------------------------------------
        .zero   0x20*8 - (.-theIDT)
        #----------------------------------------------------------
        .word   .Lirq0,  privCS, 0x8E00, 0x0000
        .word   .Lirq1,  privCS, 0x8E00, 0x0000
        .word   .Lirq2,  privCS, 0x8E00, 0x0000
        .word   .Lirq3,  privCS, 0x8E00, 0x0000
        .word   .Lirq4,  privCS, 0x8E00, 0x0000
        .word   .Lirq5,  privCS, 0x8E00, 0x0000
        .word   .Lirq6,  privCS, 0x8E00, 0x0000
        .word   .Lirq7,  privCS, 0x8E00, 0x0000
        .word   .Lirq8,  privCS, 0x8E00, 0x0000
        .word   .Lirq9,  privCS, 0x8E00, 0x0000
        .word   .Lirq10, privCS, 0x8E00, 0x0000
        .word   .Lirq11, privCS, 0x8E00, 0x0000
        .word   .Lirq12, privCS, 0x8E00, 0x0000
        .word   .Lirq13, privCS, 0x8E00, 0x0000
        .word   .Lirq14, privCS, 0x8E00, 0x0000
        .word   .Lirq15, privCS, 0x8E00, 0x0000
        #----------------------------------------------------------
        .zero   0x80*8 - (.-theIDT)
        #----------------------------------------------------------
        # Linux SuperVisor-Calls (0x80) gate-descriptor
        .word   isrSVC, privCS, 0xEE00, 0x0000
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
#-----------------------------------------------------------------
        .align  16
intcnt: .space  256*4, 0                # 256 counters (32-bit size)
#-------------------------------------------------------------------
        .align  16
isr_table:
        .space  256*4, 0                # 256 ISR handler pointers
#-------------------------------------------------------------------
        .section .text
        .global remap_isr_pm
        .type   remap_isr_pm, @function
        .align  8
remap_isr_pm:
        #----------------------------------------------------------
        # mask all interrupt sources during PIC reprogramming
        #----------------------------------------------------------
        cli                             # no device interrupts

        #----------------------------------------------------------
        # reprogram the Master Interrupt Controller
        #----------------------------------------------------------
        mov     $0x11, %al              # write ICW1
        out     %al, $0x20              #  to PIC #1
        mov     $NEW_IRQBASE1, %al      # write ICW2
        out     %al, $0x21              #  to PIC #1
        mov     $0x04, %al              # write ICW3
        out     %al, $0x21              #  to PIC #1
        mov     $0x01, %al              # write ICW4
        out     %al, $0x21              #  to PIC #1

        #----------------------------------------------------------
        # reprogram the Slave Interrupt Controller
        #----------------------------------------------------------
        mov     $0x11, %al              # write ICW1
        out     %al, $0xA0              #  to PIC #2
        mov     $NEW_IRQBASE2, %al      # write ICW2
        out     %al, $0xA1              #  to PIC #2
        mov     $0x02, %al              # write ICW3
        out     %al, $0xA1              #  to PIC #2
        mov     $0x01, %al              # write ICW4
        out     %al, $0xA1              #  to PIC #2

        sti                             # allow interrupts again

        ret
#-----------------------------------------------------------------
        .global remap_isr_rm
        .type   remap_isr_rm, @function
        .align  8
remap_isr_rm:
        #----------------------------------------------------------
        # mask all interrupt sources during PIC reprogramming
        #----------------------------------------------------------
        cli                             # no device interrupts

        #----------------------------------------------------------
        # reprogram the Master Interrupt Controller
        # send ICW1 to Master and Slave PIC
        #----------------------------------------------------------
        mov     $0x11, %al              # write ICW1
        out     %al, $0x20              #  to Master PIC
        out     %al, $0xA0              #  to Slave PIC

        #----------------------------------------------------------
        # Master PIC handles IRQ 0..7
        # remap IRQ 0 to interrupt number 0x20
        #----------------------------------------------------------
        mov     $OLD_IRQBASE1, %al      # write ICW2
        out     %al, $0x21              #  to Master PIC
        mov     $OLD_IRQBASE2, %al      # write ICW2
        out     %al, $0xA1              #  to Slave PIC

        #----------------------------------------------------------
        # the 80x86 architecture uses IRQ line 2 to connect
        # the master PIC to the slave PIC.
        # 0x04 => 0100b, second bit (IR line 2)
        #----------------------------------------------------------
        mov     $0x04, %al              # write ICW3
        out     %al, $0x21              #  to Master PIC
        # 0x02 =>  010b, connect using IR line 2
        mov     $0x02, %al              # write ICW3
        out     %al, $0xA1              #  to Slave PIC

        #----------------------------------------------------------
        # set x86 mode by setting bit 0 for Master and Slave PIC
        #----------------------------------------------------------
        mov     $0x01, %al              # write ICW4
        out     %al, $0x21              #  to Master PIC
        out     %al, $0xA1              #  to Slave PIC

        #----------------------------------------------------------
        # clear-out data registers
        #----------------------------------------------------------
        xor     %al, %al
        out     %al, $0x21
        out     %al, $0xA1

        sti                             # allow interrupts again

        ret


#-----------------------------------------------------------------
#   12(%ebp)    pointer to IRQ handler
#    8(%ebp)    IRQ ID
#------------------------------------------------------------------
        .global register_isr
        .type   register_isr, @function
        .align  8
register_isr:
        enter   $0, $0
        push    %ebx

        mov     8(%ebp), %ebx
        mov     $-1, %eax
        cmp     $255, %ebx
        ja      register_isr_end
        mov     12(%ebp), %eax
        mov     %eax, isr_table(,%ebx,4)
register_isr_end:
        pop     %ebx
        leave
        ret


#------------------------------------------------------------------
# Interrupt Service Routines (ISRs)
#------------------------------------------------------------------
ISR_NE       0 #  0: Divide By Zero Exception
ISR_NE       1 #  1: Debug Exception
ISR_NE       2 #  2: Non Maskable Interrupt Exception
ISR_NE       3 #  3: Int 3 Exception
ISR_NE       4 #  4: INTO Exception
ISR_NE       5 #  5: Out of Bounds Exception
ISR_NE       6 #  6: Invalid Opcode Exception
ISR_NE       7 #  7: Coprocessor Not Available Exception
ISR_WE       8 #  8: Double Fault Exception (With Error Code!)
ISR_NE       9 #  9: Coprocessor Segment Overrun Exception
ISR_WE      10 # 10: Bad TSS Exception (With Error Code!)
ISR_WE      11 # 11: Segment Not Present Exception (With Error Code!)
ISR_WE      12 # 12: Stack Fault Exception (With Error Code!)
ISR_WE      13 # 13: General Protection Fault Exception (With Error Code!)
ISR_WE      14 # 14: Page Fault Exception (With Error Code!)
ISR_NE      15 # 15: Reserved Exception
ISR_NE      16 # 16: Floating Point Exception
ISR_NE      17 # 17: Alignment Check Exception
ISR_NE      18 # 18: Machine Check Exception
ISR_NE      19 # 19: Reserved
ISR_NE      20 # 20: Reserved
ISR_NE      21 # 21: Reserved
ISR_NE      22 # 22: Reserved
ISR_NE      23 # 23: Reserved
ISR_NE      24 # 24: Reserved
ISR_NE      25 # 25: Reserved
ISR_NE      26 # 26: Reserved
ISR_NE      27 # 27: Reserved
ISR_NE      28 # 28: Reserved
ISR_NE      29 # 29: Reserved
ISR_NE      30 # 30: Reserved
ISR_NE      31 # 31: Reserved


#------------------------------------------------------------------
# Interrupt Requests (IRQs)
#------------------------------------------------------------------
IRQ_CALL    32,  0 # 32 <- IRQ0
IRQ_CALL    33,  1 # 33 <- IRQ1
IRQ_CALL    34,  2 # 34 <- IRQ2
IRQ_CALL    35,  3 # 35 <- IRQ3
IRQ_CALL    36,  4 # 36 <- IRQ4
IRQ_CALL    37,  5 # 37 <- IRQ5
IRQ_CALL    38,  6 # 38 <- IRQ6
IRQ_CALL    39,  7 # 39 <- IRQ7
IRQ_CALL    40,  8 # 40 <- IRQ8
IRQ_CALL    41,  9 # 41 <- IRQ9
IRQ_CALL    42, 10 # 42 <- IRQ10
IRQ_CALL    43, 11 # 43 <- IRQ11
IRQ_CALL    44, 12 # 44 <- IRQ12
IRQ_CALL    45, 13 # 45 <- IRQ13
IRQ_CALL    46, 14 # 46 <- IRQ14
IRQ_CALL    47, 15 # 47 <- IRQ15


#==================================================================
#===========  DEFAULT INTERRUPT SERVICE ROUTINE (ISR)  ============
#==================================================================
#
#                 Byte 0
#                      V
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
#    |   DS ES FS GS   |  <-- ebp
#    +=================+
#
#-----------------------------------------------------------------
        .align  8
.Lisr_common_stub:
        #-----------------------------------------------------------
        # push general-purpose and all data segment registers onto
        # stack in order to preserve their value and also for display
        #-----------------------------------------------------------
        pushal
        pushl   %ds
        pushl   %es
        pushl   %fs
        pushl   %gs
        mov     %esp, %ebp

        #----------------------------------------------------------
        # setup segment registers
        #----------------------------------------------------------
        mov     $sel_bs, %ax            # address rom-bios data
        mov     %ax, %fs                #   using FS register
        mov     $sel_es, %ax            # address video memory
        mov     %ax, %es                #   with ES register
        mov     $privDS, %ax            # address data segment
        mov     %ax, %ds                #   with DS register

        #----------------------------------------------------------
        # load interrupt ID and increment interrupt counter
        #----------------------------------------------------------
        mov     48(%ebp), %ebx
        incl    intcnt(,%ebx,4)

        #----------------------------------------------------------
        # check whether an interrupt handler has been registered
        #----------------------------------------------------------
        mov     isr_table(,%ebx,4), %edx
        test    %edx, %edx
        jz      .Lskiphandler
        #----------------------------------------------------------
        # put ebp onto stack in order to make ISR stack frame available
        # to interrupt handler. Finally, call the interrupt handler
        #----------------------------------------------------------
        push    %ebp
        call    *%edx
        #----------------------------------------------------------
        # restore ebp and reload interrupt ID
        #----------------------------------------------------------
        pop     %ebp
        mov     48(%ebp), %ebx
.Lskiphandler:
        #----------------------------------------------------------
        # check whether the Interrupt ID was greater than or equal
        # to 32 (0x20), then we need to handle an IRQ
        #----------------------------------------------------------
        cmp     $0x20, %ebx             # check int id >= 0x20
        jb      .Lnoirq                 #   no, then skip IRQ

        #----------------------------------------------------------
        # check whether the Interrupt ID was greater than or equal
        # to 40 (0x28, meaning IRQ8-15), then we need to send an
        # 'End-of-Interrupt' (EOI) command to the Slave PIC
        #----------------------------------------------------------
        mov     $0x20, %al              # non-specific EOI command
        cmp     $0x28, %ebx             # check int id >= 0x28
        jb      .Lnopic2                #   no, then skip Slave-PIC
        out     %al, $0xA0              # send EOI to Slave-PIC
.Lnopic2:
        #----------------------------------------------------------
        # send an EOI to the Master PIC in any case
        #----------------------------------------------------------
        out     %al, $0x20              # send EOI to Master-PIC

.Lnoirq:
        #----------------------------------------------------------
        # restore the values to the registers we've modified here
        #----------------------------------------------------------
        popl    %gs
        popl    %fs
        popl    %es
        popl    %ds
        popal

        #----------------------------------------------------------
        # remove error code and interrupt id from stack
        #----------------------------------------------------------
        add     $8, %esp

        #----------------------------------------------------------
        # enable hardware interrupts
        #----------------------------------------------------------
        sti

        #----------------------------------------------------------
        # resume execution of whichever procedure got interrupted
        #----------------------------------------------------------
        iret

