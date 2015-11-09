;  cpuid64.asm - print cpu vendor and brand information

%include "syscall.inc"

;-----------------------------------------------------------------------------
; CONSTANTS
;-----------------------------------------------------------------------------

%define SECS_PER_DAY (60*60*24) ; seconds per day
%define SECS_PER_HOUR   (60*60) ; seconds per hour
%define SECS_PER_MIN         60 ; seconds per minute


;-------------------------------------------------------------------
; Section DATA
;-------------------------------------------------------------------
SECTION .data

msg_str             db "CPUINFO:"
                    db `\r\n`
msg_str_len         equ $-msg_str

prompt_str          db "CPU vendor is: "
prompt_str_len      equ $-prompt_str

vendor_str          times 12 db " "
                    db `\r\n`
vendor_str_len      equ $-vendor_str

type_str            times 3*16 db " "
                    db `\r\n`
type_str_len        equ $-type_str

time_str            db "00:00:00 GMT "
ticks_str           db "0000000000"
                    db `\r\n`
time_str_len        equ $-time_str

;-------------------------------------------------------------------
; Section BSS
;-------------------------------------------------------------------
SECTION .bss

ticks               resd 1


;-------------------------------------------------------------------
; Section TEXT
;-------------------------------------------------------------------
SECTION .text

GLOBAL _start                  ; make label available to linker

_start:                        ; standard entry point for ld
        nop                    ; gdb parking place

        SYSCALL_4 SYS_WRITE, FD_STDOUT, msg_str, msg_str_len

        SYSCALL_4 SYS_WRITE, FD_STDOUT, prompt_str, prompt_str_len

        ;-------------------------------------------------------------------
        ; Using CPUID standard function 0 in order to load a 12-character
        ; string into the EBX, EDX, and ECX registers identifying the
        ; processor vendor
        ;-------------------------------------------------------------------
        xor     eax,eax    ; eax=0: return vendor identification string
        cpuid

        ;-------------------------------------------------------------------
        ; Copy the 12-byte vendor string, 3 registers a 4 bytes, into the
        ; string buffer
        ;-------------------------------------------------------------------
        mov     edi,vendor_str
        mov     dword [edi],ebx
        mov     dword [edi+4],edx
        mov     dword [edi+8],ecx

        SYSCALL_4 SYS_WRITE, FD_STDOUT, vendor_str, vendor_str_len

        ;-------------------------------------------------------------------
        ; Using CPUID extended function 0x8000002..4 to load the processor 
        ; brand string into the EAX, EBX, ECX, and EDX registers
        ;-------------------------------------------------------------------
        mov     esi,0x80000002
        mov     edi,type_str
.loop:
        mov     eax,esi
        cpuid

        mov     dword [edi],eax
        mov     dword [edi+4],ebx
        mov     dword [edi+8],ecx
        mov     dword [edi+12],edx
        inc     esi
        add     edi,byte 16     ; move pointer by 16 = 4*4 bytes
        cmp     esi,0x80000004  ; has upper extended function been reached?
        jbe     .loop

        SYSCALL_4 SYS_WRITE, FD_STDOUT, type_str, type_str_len

        call    print_time_of_day


        SYSCALL_2 SYS_EXIT, 0

       ;-----------------------------------------------------------
       ; END OF PROGRAM
       ;-----------------------------------------------------------


print_time_of_day:
        ;-----------------------------------------------------------
        ; get time in seconds
        ;-----------------------------------------------------------
        mov     ebx,ticks       ; arg1, pointer to buffer
        mov     eax,SYS_TIME    ; time system call
        int     0x80            ; interrupt 80 hex, call kernel
        ; the system call returns in register eax the number of seconds
        ; since the Unix Epoch (01.01.1970 00:00:00 UTC).

        mov     edi,ticks_str
        call    uint32_to_dec

        ; eax contains the number of seconds since the Epoche
        xor     edx,edx
        mov     ebx,SECS_PER_DAY
        div     ebx
        ; edx contains the number of seconds of the current day

        ; calculate the number of hours
        mov     eax,edx
        xor     edx,edx
        mov     ebx,SECS_PER_HOUR
        div     ebx
        mov     edi,time_str
        call    int_to_dec

        ; calculate the number of minutes
        mov     eax,edx
        xor     edx,edx
        mov     ebx,SECS_PER_MIN
        div     ebx
        mov     edi,time_str+3
        call    int_to_dec

        ; calculate the number of seconds
        mov     eax,edx
        mov     edi,time_str+6
        call    int_to_dec

        ;-----------------------------------------------------------
        ; convert and print decimal string
        ;-----------------------------------------------------------
        mov     edx,time_str_len ; arg3, length of string to print
        mov     ecx,time_str    ; arg2, pointer to buffer
        mov     ebx,FD_STDOUT   ; arg1, where to write, screen
        mov     eax,SYS_WRITE   ; write system call
        int     0x80            ; interrupt 80 hex, call kernel

        ret


; eax: input value
int_to_dec:
        push    eax             ; save used registers on stack
        push    ebx
        push    edx

        mov     ebx,10
        xor     edx,edx         ; clear edx of dx:ax pair
        div     bx              ; div dx:ax by bx
        add     al,'0'          ; convert to BCD digit,
        mov     byte [edi],al   ; store in string

        add     dl,'0'
        mov     byte [edi+1],dl

        pop     edx             ; restore registers from stack
        pop     ebx
        pop     eax
        ret



;-------------------------------------------------------------------
; FUNCTION:   uint32_to_dec
;
; PURPOSE:    Convert a 32-bit unsigned integer into its decimal
;             ASCII representation
;
; PARAMETERS: (via register)
;             EAX - value to output as 32-bit unsigned integer
;             EDI - pointer to output string
;
; RETURN:     none 
;
;-------------------------------------------------------------------
uint32_to_dec:
        push    eax             ; save used registers on stack
        push    ebx
        push    ecx
        push    edx

        mov     ecx,10            ; iterate over 10 decimal digits
        test    eax,eax           ; check whether number is zero
        jnz     .loop_start       ; if not, convert to string
        mov     byte [edi+ecx-1],'0' ; otherwise, just write a single 0 into buffer
        jmp     .func_end
.loop_start:
        mov     ebx,10            ; use decimal divisor
.loop:
        test    eax,eax           ; check whether dividend is already zero
        je      .skip_div         ; and skip division
        xor     edx,edx           ; clear upper 16-bit of dividend
        div     ebx               ; otherwise, perform division by bx = 10
        add     dl,'0'            ; and convert division remainder to BCD digit
        jmp     .write_digit
.skip_div:
        mov     dl,' '
.write_digit:
        mov     [edi+ecx-1],dl    ; write digit into buffer from right to left
        loop    .loop

.func_end:
        ; restore registers from stack
        pop     edx
        pop     ecx
        pop     ebx
        pop     eax
        ret


