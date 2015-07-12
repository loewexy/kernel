;-------------------------------------------------------------------
; FUNCTION:   int_to_hex
;
; PURPOSE:    Convert a 32-bit unsigned integer into its hexadecimal
;             ASCII representation
;
; PARAMETERS: (via register)
;             EAX - value to output as 32-bit unsigned integer
;             EDI - pointer to output string
;             ECX - number of digits
;
; RETURN:     none
;
;-------------------------------------------------------------------
SECTION .data
EXTERN hex_digits

SECTION .text
GLOBAL int_to_hex

int_to_hex:
        enter   0,0
        push    ebx             ; save used registers on stack
        push    ecx
        push    edx

.loop:
        mov     ebx,eax
        and     ebx,0xf
        mov     dl,[hex_digits+ebx]
        mov     [edi+ecx-1],dl
        ror     eax,4
        dec     ecx
        jnz     .loop

        pop     edx             ; restore registers from stack
        pop     ecx
        pop     ebx
        leave
        ret

