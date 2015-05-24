
#-----------------------------------------------------------------
    .macro  in8     port
        push    %dx
        mov     $\port, %dx
        in      %dx, %al
        pop     %dx
    .endm
#-----------------------------------------------------------------
    .macro  out8    data, port
        push    %ax
        push    %dx
        mov     $\port, %dx
        mov     $\data, %al
        out     %al, %dx
        pop     %dx
        pop     %ax
    .endm
#-----------------------------------------------------------------

