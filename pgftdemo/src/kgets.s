
#==================================================================
# S E C T I O N   T E X T
#==================================================================
        .section        .text

        .type   kgets, @function
        .global kgets
        .extern kgetc
kgets:
        enter   $0, $0
        push    %ecx

        xor     %ecx, %ecx
        test    %esi, %esi
        jz      .Lexit
.Lloop:
        call    kgetc
        mov     %al, (%esi,%ecx,1)
        add     $1, %cl
        sbb     $0, %cl
        cmp     $'\n', %al
        je      .Lexit
        cmp     $'\r', %al
        jne     .Lloop
.Lexit:
        mov     %ecx, %eax      # return number of characters
        pop     %ecx
        leave
        ret


