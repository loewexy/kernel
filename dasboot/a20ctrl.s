
        .section        .text
        .code16
        .type           a20_enable, @function
        .global         a20_enable
        .align  8
a20_enable:
        enter   $0, $0

        xor     %bx, %bx
        call    a20_is_enabled
        mov     %al, %bl
        test    %al, %al
        jnz     .La20_enabled

        mov     $0x2401, %ax
        int     $0x15                   # enable A20 using BIOS

        call    a20_is_enabled
        shl     $1, %al
        or      %al, %bl
        test    %al, %al
        jnz     .La20_enabled

        in      $0x92, %al              # System Control Port
        or      $0x02, %al              # set bit #1 (Fast_A20)
        and     $0xfe, %al              # mask-out bit #0
        out     %al, $0x92              # output port settings

        call    a20_is_enabled
        shl     $2, %al
        or      %al, %bl
.La20_enabled:
        mov     %bx, %ax
        leave
        ret


#------------------------------------------------------------------
        .type           a20_is_enabled, @function
        .global         a20_is_enabled
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

