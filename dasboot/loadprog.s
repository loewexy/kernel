
        .section        .text
        .code16
        .type           load_prog, @function
        .global         load_prog
        .align  8
load_prog:
        enter   $0, $0
        push    %bx
        push    %cx
        push    %dx
        push    %di

        #----------------------------------------------------------
        # read sectors from floppy disk into memory one single
        # sector at a time
        #----------------------------------------------------------
        les     progloc, %di            # point ES:DI to program location
        mov     %es, %ax
        movw    %ax, loadloc+2
        pushw   $66                     # put parameter on stack
        call    read_one_sector

        #----------------------------------------------------------
        # check for our application signature
        #----------------------------------------------------------
        mov     %es:8(%di), %ax         # load segment start address
        cmpw    $0x4844, %es:(%di)      # check signature word 1 = 'DH'
        jne     .Linvsig                #   no, invalid signature
        cmpw    $0x5742, %es:2(%di)     # check signature word 2 = 'BW'
        jne     .Linvsig                #   no, invalid signature

        push    %ax
        #----------------------------------------------------------
        # print program load message
        #----------------------------------------------------------
        pushw   $ldmsg_len              # message length
        pushw   $ldmsg                  # message offset
        call    showmsg

        #----------------------------------------------------------
        # print program name stored in signature
        #----------------------------------------------------------
        push    %ds
        mov     %es, %cx                # ES points to program location
        mov     %cx, %ds                #   and DS now as well
        pushw   %es:20(%di)             # message length
        lea     24(%di), %bx            # message offset
        push    %bx
        call    showmsg
        pop     %ds                     # restore DS from stack

        #----------------------------------------------------------
        # print CR/LF string
        #----------------------------------------------------------
        pushw   $2                      # message length
        pushw   $crlf                   # message offset
        call    showmsg

        mov     %es:16(%di), %edx       # load end of data section
        add     $0x20000, %edx
        dec     %edx
        and     $0xffffffe0, %edx
        shr     $9, %edx
        #inc     %dx

        mov     $67, %bx
.Lreadloop:
        pushw   $1                      # message length
        pushw   $dot                    # message offset
        call    showmsg
        push    %bx                     # put parameter on stack
        call    read_one_sector
        inc     %bx
        cmp     %dx, %bx
        jbe     .Lreadloop

        pushw   $crlf_len               # message length
        pushw   $crlf                   # message offset
        call    showmsg
        pop     %ax
        jmp     .Lexit
.Linvsig:
        pushw   $sigmsg_len             # message length
        pushw   $sigmsg                 # message offset
        call    showmsg
        xor     %ax, %ax
.Lexit:
        pop     %di
        pop     %dx
        pop     %cx
        pop     %bx
        leave
        ret


        .section    .data
        .align      4
#------------------------------------------------------------------
progloc:        .word   0x0000, 0x1000          # offset, segment
#------------------------------------------------------------------
ldmsg:          .ascii  "Loading "
                .equ    ldmsg_len, (.-ldmsg)
sigmsg:         .ascii  "Signature error"
crlf:           .ascii  "\r\n\r\n"
                .equ    crlf_len, (.-crlf)
                .equ    sigmsg_len, (.-sigmsg)
dot:            .ascii   "."
#------------------------------------------------------------------

