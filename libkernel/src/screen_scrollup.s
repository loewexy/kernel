
        .section        .text
        .type           screen_scrollup, @function
        .globl          screen_scrollup
        .extern         screen_get_page
        .align          8
screen_scrollup:
        enter   $0, $0
        push    %eax
        push    %ecx
        push    %edi
        push    %esi
        push    %es

        #----------------------------------------------------------
        # setup access to CGA video memory using the ES segment
        #----------------------------------------------------------
        mov     $sel_cga, %ax
        mov     %ax, %es

        call    screen_get_page
        shl     $12, %eax

        cld                             # do forward processing
        mov     %eax, %edi
        lea     160(%edi), %esi
        mov     $80*23, %ecx
        rep     movsw   %es:(%esi), %es:(%edi)
        # overwrite bottom line with spaces
        mov     $0x0720, %ax
        mov     $80, %ecx
        rep     stosw

        pop     %es
        pop     %esi
        pop     %edi
        pop     %ecx
        pop     %eax
        leave
        ret

