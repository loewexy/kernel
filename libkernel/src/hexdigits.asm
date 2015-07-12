;-------------------------------------------------------------------
; Section DATA
;-------------------------------------------------------------------
SECTION .data

GLOBAL hex_digits
GLOBAL hex_digits_uc
GLOBAL hex_digits_lc

align 4
hex_digits_uc:
hex_digits:    db "0123456789ABCDEF 0"

align 4
hex_digits_lc: db "0123456789abcdef 0"

