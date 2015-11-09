//-----------------------------------------------------------------
//      linuxapp.s
//
//      This is a simple Linux application-program, written in the
//      GNU assembly language, for execution by an ia32 processor. 
//
//        to assemble:  $ as --32 linuxapp.s -o linuxapp.o
//        and to link:  $ ld -melf_i386 linuxapp.o -o linuxapp
//        and execute:  $ ./linuxapp
//
//      NOTE: Our classroom systems now produce x86_64 executables
//      by default, unless we override with command-line switches.
//
//      programmer: ALLAN CRUSE
//      written on: 15 OCT 2008
//-----------------------------------------------------------------


        # manifest constants
        .equ    sys_EXIT, 1             # ID-number for 'exit'
        .equ    sys_WRITE, 4            # ID-number for 'write'
        .equ    dev_STDOUT, 1           # ID-number for STDOUT


        .section        .data
msg1:   .ascii  "\n Hello, world! \n\n" # contents of message
len1:   .int    . - msg1                # count of characters

msg2:   .ascii  "Another message\n"     # contents of message
len2:   .int    . - msg2                # count of characters


        .section        .text
_start: 
        # display message 1
        mov     $sys_WRITE, %eax        # system-call ID-number
        mov     $dev_STDOUT, %ebx       # device-file ID-number
        lea     msg1, %ecx              # address of the string
        mov     len1, %edx              # length of the message
        int     $0x80                   # invoke kernel service

        # display message 2
        mov     $sys_WRITE, %eax        # system-call ID-number
        mov     $dev_STDOUT, %ebx       # device-file ID-number
        lea     msg2, %ecx              # address of the string
        mov     len2, %edx              # length of the message
        int     $0x80                   # invoke kernel service

        # terminate application
        mov     $sys_EXIT, %eax         # system-call ID-number
        mov     $0, %ebx                # program's exit-status
        int     $0x80                   # invoke kernel service

        .global _start                  # make entry-point visible
        .end                            # nothing more to assemble

