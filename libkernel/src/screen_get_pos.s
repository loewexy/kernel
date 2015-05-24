
        .section        .text
        .type           screen_get_pos, @function
        .globl          screen_get_pos
screen_get_pos:
        enter   $0, $0
        push    %ebx
        pushl   %fs

        mov     $sel_bs, %bx            # address rom-bios data
        mov     %bx, %fs                #   using FS register
        mov     %fs:(0x62), %bl         # get current page
        movzx   %bl, %ebx               # extend to 32-bit for address index
        mov     %fs:0x50(,%ebx,2), %dx  # get row,col for current page

        popl    %fs
        pop     %ebx
        leave
        ret

