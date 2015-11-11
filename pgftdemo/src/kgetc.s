
#==================================================================
# S E C T I O N   T E X T
#==================================================================
        .section        .text

        .type   kgetc, @function
        .global kgetc
        .extern screen_write
kgetc:
        enter   $4, $0
        push    %ecx
        push    %edx
        push    %esi

        lea     -4(%ebp), %esi          # allocate buffer on stack
        mov     $1, %ecx                # buffer length
        # now await input from the remote PC
.Lloop:
        mov     $0x3f8+5, %dx           # Line Status i/o-port
        #hlt
        in      %dx, %al                # poll the Line Status
        test    $0x01, %al              # received data ready?
        jz      .Lloop                  # no, continue polling

        mov     $0x3f8+0, %dx           # UART Data i/o-port
        in      %dx, %al                # input the new data
        cmp     $'z', %al
        ja      .Lskipchar
        cmp     $'\r', %al              # check for CR
        je      .Lwrite
        cmp     $'\n', %al
        je      .Lwrite
        cmp     $' ', %al
        jb      .Lskipchar
.Lwrite:
        mov     %al, (%esi)
        call    screen_write
.Lskipchar:

        pop     %esi
        pop     %edx
        pop     %ecx
        leave
        ret

