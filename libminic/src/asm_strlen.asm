;-----------------------------------------------------------------------------
;  asm_strlen.asm - calculate the length of a string
;-----------------------------------------------------------------------------
;
; DHBW Ravensburg - Campus Friedrichshafen
;
; Vorlesung Systemnahe Programmierung (SNP)
;
;----------------------------------------------------------------------------
;
; Architecture:  x86-32
; Language:      NASM Assembly Language
;
; Author:        Ralf Reutemann
;
;----------------------------------------------------------------------------


;-------------------------------------------------------------------
; SECTION TEXT
;-------------------------------------------------------------------
SECTION .text

GLOBAL asm_strlen:function
asm_strlen:
        enter   0, 0
        push    ecx
        push    edi

        mov     edi, [ebp+8]      ; load string address
        xor     ecx, ecx          ; initialise loop counter
        not     ecx               ; set all bits to 1, i.e. -1 as signed integer
        xor     al, al            ; clear al because we seach for the \0 byte
        cld                       ; clear direction flag in order to search forward
        repne   scasb             ; finally, ecx = -strlen-2
        ;---------------------------------------------------------------------------
        ; alternative calculation 1
        ; neg   ecx               ; neg ecx = -(-strlen-2) = strlen+2
        ; dec   ecx
        ; dec   ecx
        ; mov   eax, ecx          ; eax = ecx-2 = strlen+2-2 = strlen
        ;---------------------------------------------------------------------------
        ; alternative calculation 2
        ; neg   ecx               ; neg ecx = -(-strlen-2) = strlen+2
        ; lea   eax, [ecx-2]      ; eax = ecx-2 = strlen+2-2 = strlen
        ;---------------------------------------------------------------------------
        not     ecx               ; not ecx = abs(-strlen-2)-1 = strlen+1
        lea     eax, [ecx-1]      ; eax = ecx-1 = strlen+1-1 = strlen

        pop     edi
        pop     ecx
        leave
        ret

