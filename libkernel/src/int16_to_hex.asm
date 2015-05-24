;-------------------------------------------------------------------
; FUNCTION:   int16_to_hex
;
; PURPOSE:    Convert a 16-bit unsigned integer into its hexadecimal
;             ASCII representation
;
; PARAMETERS: (via register)
;             EAX - value to output as 16-bit unsigned integer
;             EDI - pointer to output string
;
; RETURN:     EAX - pointer to the character following the last
;                   character in the string
;
;-------------------------------------------------------------------
SECTION .data
EXTERN hex_digits

SECTION .text
GLOBAL int16_to_hex

int16_to_hex:
        push    ebx             ; save used registers on stack
        push    ecx
        push    edx

        mov     ecx,4           ; iterate over 4 hex digits
.loop:
        mov     ebx,eax
        and     ebx,0xf
        mov     dl,[hex_digits+ebx]
        mov     [edi+ecx-1],dl
        shr     eax,4
        dec     ecx
        jnz     .loop

        lea     eax,[edi+4]

        pop     edx             ; restore registers from stack
        pop     ecx
        pop     ebx
        ret

