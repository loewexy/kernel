


#------------------------------------------------------------------
#   32(%ebp)    bitmask to highlight registers
#   28(%ebp)    add column number
#   24(%ebp)    get normal/highlight colors
#   20(%ebp)    number of stack entries
#   16(%ebp)    address of previous values buffer
#               if zero, values are not compared against previous
#               value and highlighted in case they are different
#   12(%ebp)    address of stack element names
#    8(%ebp)    address of stack bottom entry
#------------------------------------------------------------------
        .section        .data
        .global stkname
stkname:.ascii  "-->  +4  +8 +12 +16 +20 +24 +28 +32 +36 +40 "
        .equ    STK_NUM, ( . - stkname )/4    # number of array entries
        .globl  STK_NUM
        .global tssname
tssname:.ascii  "EIP EFL EAX ECX EDX EBX ESP EBP ESI EDI "
        .ascii  " ES  CS  SS  DS  FS  GS "
        .global TSS_NUM
        .equ    TSS_NUM, ( . - tssname )/4    # number of array entries
        #----------------------------------------------------------
dbgname:.ascii  "CNT INS TSS DR0 DR1 DR2 DR6 DR7 "
        .globl  dbgname
        .equ    DBG_NUM, ( . - dbgname )/4    # number of array entries
        .globl  DBG_NUM
intname:.ascii  " GS  FS  ES  DS "
        .globl  intname
regname:.ascii  "EDI ESI EBP ESP EBX EDX ECX EAX "
        .globl  regname
        .equ    REG_NUM, ( . - regname )/4    # number of array entries
        .globl  REG_NUM
        .ascii  "INT "
        .ascii  "ERR "
        .ascii  "EIP  CS "
eflname:.ascii  "EFL "
        .ascii  "ESP  SS "
        .equ    INT_NUM, ( . - intname )/4    # number of array entries
        .globl  INT_NUM
stackbuf:
        .ascii  " nnn xxxxxxxx "              # buffer for hex display
        .equ    BUF_LEN, . - stackbuf         # length of outbup buffer
#------------------------------------------------------------------
        .section        .text
        .type           print_stacktrace, @function
        .globl          print_stacktrace
        .align          8
print_stacktrace:
        enter   $0, $0
        pushal
        pushl   %es

        #----------------------------------------------------------
        # ok, here we display our stack-frame (with labels)
        #----------------------------------------------------------
        mov     $sel_es, %ax            # address video memory
        mov     %ax, %es                #   with ES register

        cld                             # do forward processing
        xor     %ecx, %ecx              # stack entry counter starts from 0
nxreg:
        #----------------------------------------------------------
        # store next field-label in the info-buffer
        #----------------------------------------------------------
        mov     12(%ebp), %edx          # address of stack element names
        mov     (%edx, %ecx, 4), %ebx   # fetch register label
        mov     %ebx, stackbuf+1        # store register label

        #----------------------------------------------------------
        # store next field-value in the info-buffer
        #----------------------------------------------------------
        lea     stackbuf+5, %edi        # point to output field
        mov     8(%ebp), %edx           # address of stack bottom entry
        mov     %ss:(%edx, %ecx, 4), %eax
        mov     20(%ebp), %edx          # number of stack entries
        sub     %ecx, %edx              # calculate remaining entries
        cmpl    eflname, %ebx           # is it the EFLAGS entry?
        je      write_flags             # yes, then write flags
        call    int32_to_hex            # otherwise, store value as hex
        jmp     skip_flags

write_flags:
        movw    $0x2020, (%edi)         # write two space chars
        add     $2, %edi                # and skip these two chars
        call    get_flags_str

skip_flags:
        #----------------------------------------------------------
        # compute screen-location for this element
        #----------------------------------------------------------
        mov     $23, %eax               # bottom item line-number
        sub     %ecx, %eax              # minus the item's number
        # edi <- 80 cols * 2 Bytes * rows
        # edi <- 160 * eax = 5 * 32 * eax
        lea     (%eax, %eax, 4), %edi   # edi <- 5 * eax
        shl     $4, %edi                # edi <- 16 * edi
        add     28(%ebp), %edi          # add column number
        shl     $1, %edi                # edi <- 2 * edi
        call    screen_get_page
        shl     $12, %eax
        add     %eax, %edi              # vram-offset into EDI

        mov     24(%ebp), %eax          # get normal/highlight colors
        mov     8(%ebp), %ebx           # address of stack bottom entry
        # load register contents from stack (use stack segment for access)
        mov     %ss:(%ebx, %ecx, 4), %edx

        #----------------------------------------------------------
        # check whether the current register needs to be highlighted
        #----------------------------------------------------------
        mov     16(%ebp), %ebx          # address of previous values buffer
        btl     %ecx, 32(%ebp)
        jnc     checkprev
        shr     $8, %eax                # get alternative highlight color
        test    %ebx, %ebx              # check if buffer address is zero
        jz      transfer                #   if zero, output stacktrace
        jmp     regstore                #   else, store value

checkprev:
        #----------------------------------------------------------
        # check whether address of array with previously stored values is
        # zero
        #----------------------------------------------------------
        test    %ebx, %ebx              # check if address is zero
        jz      transfer                #   if zero, skip highlighting
        #----------------------------------------------------------
        # compare register value on stack (EDX) with previously stored
        # value stored in array pointed to by EBX
        #----------------------------------------------------------
        cmp     (%ebx,%ecx,4), %edx     # compare previous with current value
        je      transfer                #   if equal, skip highlighting
        xchg    %al, %ah                # exchange normal with highlight color
regstore:
        mov     %edx, (%ebx,%ecx,4)     # store register value in array

transfer:
        #----------------------------------------------------------
        # output stacktrace onto the screen
        #----------------------------------------------------------
        push    %ecx                    # save stack entry counter
        mov     $BUF_LEN, %ecx          # setup message length
        lea     stackbuf, %esi          # point to info buffer
nxchx:  lodsb                           # fetch message character
        stosw                           # store char and color
        loop    nxchx                   # transfer entire string
        pop     %ecx                    # restore stack entry counter

        inc     %ecx                    # increment stack entry counter
        cmp     20(%ebp), %ecx          # number of stack entries reached?
        jl      nxreg                   # no, show next register

        popl    %es
        popal
        leave
        ret

#------------------------------------------------------------------
        .section        .data
eflstr: .ascii  "oOsSzZaApPcC"
eflmsk: .byte   11, 7, 6, 4, 2, 0, -1
#------------------------------------------------------------------
        .section        .text
        .type           get_flags_str, @function
        .globl          get_flags_str
        .align          8
get_flags_str:
        pushal

        xor     %ebx, %ebx
.Lloop:
        movsx   eflmsk(%ebx), %ecx
        test    %ecx, %ecx
        js      .Lexit
        lea     eflstr(,%ebx,2), %esi
        bt      %ecx, %eax
        adc     $0, %esi
        mov     (%esi), %dl
        mov     %dl, (%edi,%ebx)
        inc     %ebx
        jmp     .Lloop

.Lexit:
        popal
        ret

