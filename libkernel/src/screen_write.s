
        .equ    UART_BASE, 0x03F8       # base i/o-port for UART

        .extern screen_scrollup
        .extern screen_get_pos
        .extern screen_set_cursor

        .section        .text
        .type           screen_write, @function
        .globl          screen_write
        .align          8
screen_write:
        enter   $4, $0
        pushal
        pushl   %es

        # point ES:EDI to screen-position
        mov     $sel_es, %ax            # address video memory
        mov     %ax, %es                #   with ES register

        call    screen_get_pos          # get row,col in DX
        mov     $80, %al                # cells-per-row
        mul     %dh                     # times row-number
        add     %dl, %al                # plus column-number
        adc     $0, %ah                 # as 16-bit value
        movzx   %ax, %ebx               # extend to dword
        call    screen_get_page
        shl     $12, %eax               # calculate page offset
        movl    %eax, -4(%ebp)          # and store on stack
        lea     (%eax,%ebx,2), %edi     # vram-offset into EDI

        # loop to write character-codes to the screen
        cld
        mov     $0x07, %ah              # normal text attribute
nxmchr: lodsb                           # fetch next character

        cmp     $'\b', %al              # backpsace?
        jne     no_bs
        test    %dl, %dl
        jz      advok
        push    %edx
        # write character to UART
        mov     $UART_BASE+0, %dx       # UART Data i/o-port
        out     %al, %dx                # send character
        pop     %edx
        dec     %dl
        mov     $' ', %al
        sub     $2, %edi
        stosw
        jmp     advok
no_bs:
        push    %edx
        # write character to UART
        mov     $UART_BASE+0, %dx       # UART Data i/o-port
        out     %al, %dx                # send character
        pop     %edx
        cmp     $'\n', %al              # newline?
        je      do_nl                   #   yes, do CR/LF
        cmp     $'\r', %al              # carriage return?
        je      do_cr                   #   yes, do CR

do_wr:  stosw                           # write to the display
        inc     %dl                     # advance column-number
        cmp     $80, %dl                # end-of-row reached?
        jb      advok                   # no, column is ok
do_nl:  inc     %dh                     # else advance row-number
do_cr:  mov     $0, %dl                 # with zero column-number
        cmp     $23, %dh                # bottom-of-screen reached?
        jb      adjpos                  #   no, row is ok
        dec     %dh                     # else reduce row-number
        # scrollup screen by one row
        call    screen_scrollup
adjpos:
        # adjust vram offset after CR/LF
        mov     $80, %al                # cells-per-row
        mul     %dh                     # times row-number
        add     %dl, %al                # plus column-number
        adc     $0, %ah                 # as 16-bit value
        movzx   %ax, %eax               # extend to dword
        lea     (,%eax,2), %edi         # vram-offset into EDI
        add     -4(%ebp), %edi          # add page offset
        mov     $0x07, %ah              # normal text attribute
advok:
        loop    nxmchr                  # again for full string

        # adjust hardware cursor-location
        call    screen_set_cursor

        popl    %es
        popal
        leave
        ret

