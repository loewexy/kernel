
#------------------------------------------------------------------
# KBDUS means US Keyboard Layout. This is a scancode table
# used to layout a standard US keyboard. I have left some
# comments in to give you an idea of what key is what, even
# though I set it's array index to 0. You can change that to
# whatever you want using a macro, if you wish!
#------------------------------------------------------------------
        .section        .data
        .global         kbdus
        .align          8
kbdus:  .byte 0,  27, '1', '2', '3', '4', '5', '6', '7', '8'
        .byte '9', '0', '-', '='
        .byte '\b'     # Backspace
        .byte '\t'     # Tab
        .byte 'q', 'w', 'e', 'r', 't', 'y', 'u', 'i', 'o', 'p', '[', ']'
        .byte '\n'     # 28 - Enter key
        .byte 0        # 29 - Control
        .byte 'a', 's', 'd', 'f', 'g', 'h', 'j', 'k', 'l', ';'
        .byte '\'', '`'
        .byte 0        # Left shift
        .byte '\\', 'z', 'x', 'c', 'v', 'b', 'n'
        .byte 'm', ',', '.', '/'
        .byte 0        # 54 - Right shift
        .byte '*'      # 55
        .byte 0        # 56 - Alt
        .byte ' '      # 57 - Space bar
        .byte 0        # 58 - Caps lock
        .byte 0        # 59 - F1 key ... >
        .byte 0, 0, 0, 0, 0, 0, 0, 0
        .byte 0        # 68 - F10
        .byte 128      # 69 - Num lock
        .byte 128      # 70 - Scroll Lock
        .byte 128      # 71 - Home key
        .byte 0        # 72 - Up Arrow
        .byte 130      # 73 - Page Up
        .byte '-'      # 74
        .byte 0        # 75 - Left Arrow
        .byte 0        # 76
        .byte 0        # 77 - Right Arrow
        .byte '+'      # 78
        .byte 0        # 79 - End key
        .byte 0        # 80 - Down Arrow
        .byte 129      # 81 - Page Down
        .byte 0        # 82 - Insert Key
        .byte 0        # 83 - Delete Key
        .byte 0, 0, 0  # 84, 85, 86
        .byte 128      # 87 - F11 Key
        .byte 128      # 88 - F12 Key
        # All other keys are undefined
        .space 128 - (.-kbdus), 128
        .equ    KBDUS_LEN, (.-kbdus)

