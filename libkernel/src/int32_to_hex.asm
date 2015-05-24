;-------------------------------------------------------------------
; FUNCTION:   int32_to_hex
;
; PURPOSE:    Convert a 32-bit unsigned integer into its hexadecimal
;             ASCII representation
;
; PARAMETERS: (via register)
;             EAX - value to output as 32-bit unsigned integer
;             EDI - pointer to output string
;
; RETURN:     none
;
;-------------------------------------------------------------------
SECTION .data
EXTERN hex_digits

SECTION .text
GLOBAL int32_to_hex

int32_to_hex:
        push    ebx             ; save used registers on stack
        push    ecx
        push    edx

        mov     ecx,8           ; iterate over 8 hex digits
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
        ret

