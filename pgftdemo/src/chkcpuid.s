
#==================================================================
# S E C T I O N   D A T A
#==================================================================
        .section        .data

        .align  4
        .global cpuid_features
cpuid_features:
        .long   0

        .global cpuid_avail
cpuid_avail:
        .byte   -1

        .global cpuid_sse42_avail
cpuid_sse42_avail:
        .byte   -1


#==================================================================
# S E C T I O N   T E X T
#==================================================================
        .section        .text


#-------------------------------------------------------------------
# FUNCTION:   check_cpuid
#
# PURPOSE:    check whether cpuid instruction is available and, if
#             so, excute cpuid function #1 in order to check for
#             SSE4.2 feature
#
# PARAMETERS: None
#
# RETURN:     AL - 0 = no cpuid instruction
#                  1 = cpuid instruction available
#             AH - 0 = no SSE4.2
#                  1 = SSE4.2 feature available
#
#-------------------------------------------------------------------
        .type   check_cpuid, @function
        .global check_cpuid
check_cpuid:
        enter   $0, $0
        push    %ecx
        push    %edx

        mov     cpuid_avail, %al
        test    %al, %al
        jns     .Lskipcpuid

        pushfl                  # push EFLAGS to stack
        pop     %eax            # store EFLAGS in EAX
        mov     %eax, %edx      # save in EDX for later testing
        xor     $(1<<21), %eax  # toggle bit 21
        push    %eax            # push to stack
        popfl                   # save changed EAX to EFLAGS

        pushfl                  # push EFLAGS to stack
        pop     %eax            # store EFLAGS in EAX
        cmp     %edx, %eax      # see if bit 21 has changed, if so
        setne   %al             # set AL to 1 -> CPUID supported
        mov     %al, cpuid_avail
        je      .Lskipcpuid     # no change, then skip cpuid

        mov     $0x01, %eax     # cpuid function 1
        cpuid
        mov     %ecx, cpuid_features
        bt      $20, %ecx       # check SSE4.2 feature bit
        setc    %ah
        mov     %ah, cpuid_sse42_avail
        mov     cpuid_avail, %al
        and     $0xffff, %eax

.Lskipcpuid:
        pop     %edx
        pop     %ecx
        leave
        ret

