
#==================================================================
#===========        HANDLER FOR TIMER INTERRUPTS       ============
#==================================================================
#
# Here is our code for handing timer-interrupts while the CPU is
# executing in 'protected-mode'; it follows closely the original
# 'real-mode' Interrupt-Service Routine used in the IBM-PC BIOS,
#
#-----------------------------------------------------------------
# Stack Frame Layout
#-----------------------------------------------------------------
#
#                 Byte 0
#                      V
#    +=================+
#    |  Int Stack Ptr  |  +8
#    +-----------------+
#    |  Return Address |  +4
#    +-----------------+
#    |       EBP       |  <-- ebp
#    +=================+
#
#-----------------------------------------------------------------

#-----------------------------------------------------------------
# EQUATES for timing constants and for ROM-BIOS address offsets
#-----------------------------------------------------------------
        .equ    HOURS24, 0x180000       # number of ticks-per-day
        .equ    N_TICKS, 0x006C         # offset for tick-counter
        .equ    TM_OVFL, 0x0070         # offset of rollover-flag
        .equ    PULSES_PER_SEC, 1193182 # timer input-frequency
        .equ    PULSES_PER_TICK, 65536  # BIOS frequency-divisor
        .equ    SECS_PER_MIN, 60        # seconds per minute
        .equ    SECS_PER_HOUR, 60*SECS_PER_MIN # seconds per hour
        .equ    SECS_PER_DAY, 24*SECS_PER_HOUR # seconds per day

#-----------------------------------------------------------------
# S E C T I O N   D A T A
#-----------------------------------------------------------------
        .section    .data

prevticks: .long   0

#-----------------------------------------------------------------
# S E C T I O N   T E X T
#-----------------------------------------------------------------
        .section        .text
        .code32
        .type   irqPIT, @function
        .global irqPIT
        .align   16
irqPIT:
        #-----------------------------------------------------------
        # setup stack frame access via ebp
        #-----------------------------------------------------------
        enter   $0, $0

        #-----------------------------------------------------------
        # increment the 32-bit counter for timer-tick interrupts
        #-----------------------------------------------------------
        incl    %fs:N_TICKS             # increment tick-count
        cmpl    $HOURS24, %fs:N_TICKS   # past midnight?
        jl      .Lisok                  # no, don't rollover yet
        movl    $0, %fs:N_TICKS         # else reset count to 0
        movb    $1, %fs:TM_OVFL         # and set rollover flag
.Lisok:

        #-----------------------------------------------------------
        # calculate total seconds (= N_TICKS * 65536 / 1193182)
        #-----------------------------------------------------------
        mov     %fs:N_TICKS, %eax       # setup the multiplicand
        mov     $PULSES_PER_TICK, %ecx  # setup the multiplier
        mul     %ecx                    # 64 bit product is in (EDX,EAX)
        mov     $PULSES_PER_SEC, %ecx   # setup the divisor
        div     %ecx                    # quotient is left in EAX

        #--------------------------------------------------------
        # ok, now we 'round' the quotient to the nearest integer
        #--------------------------------------------------------
        # rounding-rule:
        #       if  ( remainder >= (1/2)*divisor )
        #          then increment the quotient
        #--------------------------------------------------------
        add     %edx, %edx      # EDX = twice the remainder
        sub     %ecx, %edx      # CF=1 if 2*rem < divisor
        cmc                     # CF=1 if 2*rem >= divisor
        adc     $0, %eax        # ++EAX if 2+rem >= divisor
.Lcheckticks:
        cmp     %eax, prevticks
        je      .Lskipupdate
        mov     %eax, prevticks
        incl    ticks
.Lskipupdate:
        leave
        ret

