;-------------------------------------------------------------------
; FUNCTION:   uint16_to_dec
;
; PURPOSE:    Convert a 16-bit unsigned integer into its decimal
;             ASCII representation
;
; PARAMETERS: (via register)
;             EAX - value to output as 32-bit unsigned integer
;             EDI - pointer to output string
;
; RETURN:     Pointer to character following output string
;
;-------------------------------------------------------------------
SECTION .text
GLOBAL uint16_to_dec:function

uint16_to_dec:
        push    ebx
        push    ecx
        push    edx

        mov     ecx,5             ; iterate over 5 decimal digits
        test    eax,eax           ; check whether number is zero
        jnz     .loop_start       ; if not, convert to string
        mov     byte [edi+ecx-1],'0' ; otherwise, just write a single 0 into buffer
        jmp     .func_end
.loop_start:
        mov     ebx,10            ; use decimal divisor
.loop:
        test    ax,ax             ; check whether dividend is already zero
        je      .skip_div         ; and skip division
        xor     dx,dx             ; clear upper 16-bit of dividend
        div     bx                ; otherwise, perform division by bx = 10
        add     dl,'0'            ; and convert division remainder to BCD digit
        jmp     .write_digit
.skip_div:
        mov     dl,' '
.write_digit:
        mov     [edi+ecx-1],dl    ; write digit into buffer from right to left
        loop    .loop

.func_end:
        lea     eax,[edi+5]
        ; restore registers from stack
        pop     edx
        pop     ecx
        pop     ebx
        ret


