
        .equ    CRT_PORT, 0x03D4
        .equ    CRT_PAGE_HI, 0x0C
        .equ    CRT_PAGE_LO, 0x0D

        .section        .text
        .type           screen_get_page, @function
        .globl          screen_get_page
        .align          8
screen_get_page:
        enter   $0, $0
        push    %edx

        xor     %eax, %eax
        mov     $CRT_PORT, %dx          # CRTC i/o-port
        mov     $CRT_PAGE_HI, %al       # page offset HI
        out     %al, %dx
        nop
        nop
        inc     %dx
        in      %dx, %al
        mov     %al, %ah

        mov     $CRT_PORT, %dx          # CRTC i/o-port
        mov     $CRT_PAGE_LO, %al       # page offset LO
        out     %al, %dx
        nop
        nop
        inc     %dx
        in      %dx, %al
        shr     $11, %eax               # divide offset by 0x1000/2

        pushl   %fs

        mov     $sel_bs, %ax            # address rom-bios data
        mov     %ax, %fs                #   using FS register
        movzxb  %fs:(0x62), %eax        # get current page

        popl    %fs

        pop     %edx
        leave
        ret

