#----------------------------------------------------------------
# asm_printf.s
#
# int asm_printf( char *fmt, ... );
#
# Original version based on:
# Prof. Allan Cruse, University of San Francisco
#----------------------------------------------------------------

#-----------------------------------------------------------------
# Stack Frame Layout
#-----------------------------------------------------------------
#
#                 Byte 0
#                      V
#    +-----------------+
#    |       ...       |
#    +-----------------+
#    |      arg #1     |  +12  0xc
#    +-----------------+
#    |    format ptr   |   +8  0x8
#    +-----------------+
#    |  Return Address |   +4  0x4
#    +-----------------+
#    |       EBP       |  <-- ebp
#    +-----------------+
#    |   local buffer  |  <-- ebp - BUFSIZE
#    +-----------------+
#
#-----------------------------------------------------------------

#==================================================================
# S E C T I O N   R O D A T A
#==================================================================
        .section        .rodata

        .align 4
hexuc:  .ascii "0123456789ABCDEF +-"
        .align 4
hexlc:  .ascii "0123456789abcdef +-"


#==================================================================
# S E C T I O N   T E X T
#==================================================================
        .section        .text

        .extern screen_write
        .global asm_printf
        .type   asm_printf, @function
asm_printf:
        pushl   %ebp                    # preserve frame-pointer
        movl    %esp, %ebp              # setup local stack-frame
        subl    $0x200, %esp            # create space for radix, buffer etc
        pushal                          # preserve cpu registers
        push    %es
        mov     %ds, %ax
        mov     %ax, %es

        lea     -0x200(%ebp), %edi      # buffer address into EDI
        movl    8(%ebp), %esi           # fmt parameter into ESI
        movl    $0, %ecx                # initial argument-index
        movb    %cl, -8(%ebp)           # clear format size

        cld                             # use forward processing
.Lagain:
        cmpb    $0, (%esi)              # test: null-terminator?
        je      .Lfinish                # yes, we are finished

        cmpb    $'%', (%esi)            # test: format escape?
        je      .Lescape                # yes, insert numerals

        movsb                           # else copy the character
        jmp     .Lagain                 # and go back for another

.Lfinish:
        lea     -0x200(%ebp), %esi      # buffer address into ESI
        subl    %esi, %edi              # compute output length
        movl    %edi, -12(%ebp)         # and save it on stack
        mov     %edi, %ecx
        call    screen_write
        jmp     .Lreturn                # then exit this function

.Lescape:
        movb    $0, -8(%ebp)            # reset format to zero
        movb    $0, -6(%ebp)            # reset sign character
        incl    %esi                    # skip past escape-code
        movb    $16, -7(%ebp)           # 16: index of space char in hexdigits
        cmpb    $'+', (%esi)
        jne     .Lskipplus
        movb    $17, -6(%ebp)           # 17: index of '+' char in hexdigits
        incl    %esi
.Lskipplus:
        cmpb    $'0', (%esi)            # test: zero digit
        jne     .Ldigitloop
        movb    $0, -7(%ebp)            # 0: index of zero char in hexdigits
.Ldigitloop:
        lodsb                           # and fetch escape-type
        test    %al, %al                # test: null-terminator?
        jz      .Lfinish                # yes, we are finished

        cmpb    $'0', %al               # check for digits
        jb      .Lnodigit
        cmpb    $'9', %al
        ja      .Lnodigit
        sub     $'0', %al
        movzxb  -8(%ebp), %edx
        lea     (%edx,%edx,4), %edx     # multiply edy by 5
        shl     $1, %edx                # and then by 2
        add     %al, %dl
        movb    %dl, -8(%ebp)
        jmp     .Ldigitloop

.Lnodigit:
        cmpb    $'c', %al               # wanted char format?
        je      .Ldo_char               # yes, copy single char

        cmpb    $'s', %al               # wanted string format?
        je      .Ldo_string             # yes, copy string

        movl    $hexlc, %ebx            # point EBX to lc digits table

        cmpb    $'d', %al               # wanted signed decimal format?
        movl    $-10, -4(%ebp)          # yes, use -10 as the radix
        je      .Ldo_tx                 # convert number to string

        cmpb    $'u', %al               # wanted unsigned decimal format?
        movl    $10, -4(%ebp)           # yes, use 10 as the radix
        je      .Ldo_tx                 # convert number to string

        cmpb    $'o', %al               # wanted octal format?
        movl    $8, -4(%ebp)            # yes, use 8 as the radix
        je      .Ldo_tx                 # convert number to string

        movl    $16, -4(%ebp)           # yes, use 16 as the radix
        cmpb    $'x', %al               # wanted hexadecimal format?
        je      .Ldo_tx                 # convert number to string

        movl    $hexuc, %ebx            # point EBX to uc digits table
        cmpb    $'X', %al               # wanted hexadecimal format?
        je      .Ldo_tx                 # convert number to string

        cmpb    $'%', %al               # wanted percent sign itself?
        jne     .Lerrorx                # no, then return error
        stosb                           # write single percent character
        jmp     .Lagain

.Ldo_tx:
        movl    12(%ebp,%ecx,4), %eax   # get next argument in EAX
        incl    %ecx                    # and advance argument-index

        cmpl    $0, -4(%ebp)            # is radix negative?
        jns     .Lskipsign              # no, then print as unsigned
        negl    -4(%ebp)                # convert radix
        test    %eax, %eax              # is integer argument negative?
        jns     .Lskipsign              # no, then do not convert
        neg     %eax                    # convert integer argument
        movb    $18, -6(%ebp)           # 18: index of '-' char in hexdigits
.Lskipsign:
        pushl   %ecx                    # preserve argument-index
        xorl    %ecx, %ecx              # initialize digit-counter
.Lnxdiv:
        xorl    %edx, %edx              # extend dividend to quadword
        divl    -4(%ebp)                # divide by selected radix
        push    %edx                    # push remainder onto stack
        incl    %ecx                    # and increment digit-count
        test    %eax, %eax              # test: quotient was zero?
        jnz     .Lnxdiv                 # no, another digit needed
        movb    -6(%ebp), %al           # read sign character
        test    %al, %al                # is a sign set?
        jz      .Lnxadj                 # no, then don't add a sign
        push    %eax
        inc     %cl
.Lnxadj:
        cmp     %cl, -8(%ebp)
        jbe     .Lnxdgt
        movb    -7(%ebp), %al           # read fill character
        pushl   %eax
        inc     %cl
        jmp     .Lnxadj
.Lnxdgt:
        popl    %eax                    # saved remainder into EAX
        xlat    (%ebx)                  # convert number to numeral
        stosb                           # store numeral in buffer
        loop    .Lnxdgt                 # go get the next remainder

        popl    %ecx                    # recover the argument-index
        movb    $0, -8(%ebp)
        jmp     .Lagain                 # and resume copying format

.Ldo_char:
        movl    12(%ebp,%ecx,4), %eax   # get next argument in EBX
        stosb
        incl    %ecx                    # advance argument-index
        jmp     .Lagain                 # and resume copying format

.Ldo_string:
        movl    12(%ebp,%ecx,4), %ebx   # get next argument in EBX
.Lnxch:
        movb    (%ebx), %al
        stosb                           # store character in buffer
        incl    %ebx
        test    %al, %al
        jnz     .Lnxch
        decl    %edi
        incl    %ecx                    # advance argument-index
        movb    $10, -8(%ebp)
        jmp     .Lagain                 # and resume copying format

.Lerrorx:
        movl    $-1, -12(%ebp)          # store error indicator

.Lreturn:
        pop     %es
        popal                           # restore saved registers
        movl    -12(%ebp), %eax         # copy return-value to EAX
        movl    %ebp, %esp              # discard temporary storage
        popl    %ebp                    # restore saved frame-pointer
        ret                             # return control to caller

