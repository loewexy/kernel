
        .equ    BS_VIDEO_PAGE, 0x62
        .equ    BS_VIDEO_CURSOR, 0x50
        .equ    CRT_PORT, 0x03D4
        .equ    CRT_CURSOR_HI, 0x0E
        .equ    CRT_CURSOR_LO, 0x0F

        .section        .text
        .type           screen_set_cursor, @function
        .globl          screen_set_cursor
        .align          8
screen_set_cursor:
        enter   $0, $0
        push    %eax
        push    %ebx
        push    %ecx
        push    %edx
        pushl   %ds
        pushl   %fs

        mov     $sel_bs, %ax            # address rom-bios data
        mov     %ax, %fs                #   using FS register
        mov     $privDS, %ax
        mov     %ax, %ds
        movzxb  %fs:(0x62), %ebx        # get current page
        mov     %dx, %fs:0x50(,%ebx,2)  # write row,col for current page

        shl     $11, %bx                # bx = bx * 2048
        mov     $80, %al
        mul     %dh
        add     %dl, %al
        adc     $0, %ah
        add     %ax, %bx

        mov     $CRT_PORT, %dx          # CRTC i/o-port
        mov     $CRT_CURSOR_HI, %al     # cursor-offset HI
        mov     %bh, %ah                # offset 15..8
        out     %ax, %dx
        mov     $CRT_CURSOR_LO, %al     # cursor-offset LO
        mov     %bl, %ah                # offset 7..0
        out     %ax, %dx

        popl    %fs
        popl    %ds
        pop     %edx
        pop     %ecx
        pop     %ebx
        pop     %eax
        leave
        ret

