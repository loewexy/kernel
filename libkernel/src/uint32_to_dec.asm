
;-----------------------------------------------------------------------------
; Section TEXT
;-----------------------------------------------------------------------------
SECTION .text


;-------------------------------------------------------------------
; FUNCTION:   uint32_to_dec
;
; PURPOSE:    Convert an unsigned 32-bit integer into its decimal
;             ASCII representation
;
; PARAMETERS: (via register)
;             EAX - value to output as 32-bit unsigned integer
;             EDI - pointer to output string
;             CL  - number of decimal digits
;             CH -  1 -> leading zeros, 0 -> fill with spaces
;
; RETURN:     none
;
;-------------------------------------------------------------------
       global uint32_to_dec:function
uint32_to_dec:
       push    ebp
       mov     ebp,esp
       pusha

       movzx   edx,cl            ; using the number of decimal digits to output,
       lea     esi,[edx-1]       ;  load offset relative to buffer pointer in esi
       mov     ebp,esi
       mov     dx,'0'
       mov     cl,' '            ; default fill character
       test    ch,ch             ; check whether fill-with-zero flag is zero
       cmovnz  cx,dx             ;  if not, load '0' as fill character
       test    eax,eax           ; check whether number is zero
       jnz     .loop_start       ;  if not, convert to string
       mov     byte [edi+esi],dl ; otherwise, just write a single 0 into buffer
       dec     esi               ;  and adjust the buffer pointer
       jmp     .fill_loop
.loop_start:
       mov     ebx,10            ; use decimal divisor
.div_loop:
       test    eax,eax           ; check whether dividend is already zero
       je      .fill_loop        ;  and if true skip division
       xor     edx,edx           ; clear upper 32-bit of dividend
       div     ebx               ; perform division by ebx = 10
       add     dl,'0'            ;  and convert division remainder to BCD digit
       mov     [edi+esi],dl      ; write digit into buffer from right to left
       dec     esi               ; decrement loop counter
       jns     .div_loop         ;  down to zero, exit loop if negative

       test    eax,eax           ; check whether the number fit into the buffer
       jz      .func_end         ;  i.e. whether it is now zero, then continue
       mov     cl,'#'            ;  otherwise use overflow character
       mov     esi,ebp           ;  and restore original offset to end of buffer
.fill_loop:
       mov     [edi+esi],cl
       dec     esi
       jns     .fill_loop

.func_end:
       ; restore registers from stack
       popa
       mov     esp,ebp
       pop     ebp
       ret

