
        .equ    CRT_PORT,      0x03D4
        .equ    CRT_PAGE_HI,     0x0C
        .equ    CRT_PAGE_LO,     0x0D
        .equ    CRT_CURSOR_HI,   0x0E
        .equ    CRT_CURSOR_LO,   0x0F

        .section        .text
        .type           screen_sel_page, @function
        .globl          screen_sel_page
        .align          8
screen_sel_page:
        enter   $0, $0
        push    %eax
        push    %ebx
        push    %edx
        pushl   %ds
        pushl   %fs

        mov     $sel_bs, %bx            # address rom-bios data
        mov     %bx, %fs                #   using FS register

        and     $0x03, %eax
        push    %eax
        mov     %ax, %bx
        shl     $11, %bx                # multiply by 0x1000/2
        mov     $CRT_PORT, %dx          # CRTC i/o-port
        mov     $CRT_PAGE_HI, %al       # page offset HI
        mov     %bh, %ah                # offset 15..8
        out     %ax, %dx
        mov     $CRT_PAGE_LO, %al       # page offset LO
        mov     %bl, %ah                # offset 7..0
        out     %ax, %dx

        mov     $privDS, %ax
        mov     %ax, %ds
        pop     %eax
        mov     %al, %fs:(0x62)         # set current page
        mov     %fs:0x50(,%eax,2), %bx  # read row,col for current page

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
        pop     %ebx
        pop     %eax
        leave
        ret

