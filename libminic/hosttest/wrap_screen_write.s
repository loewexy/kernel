#-------------------------------------------------------------------
# FUNCTION:   wrap_screen_write
#
# PURPOSE:    Provide a stub for the kernel screen_write function
#             and redirect the call to the write system call
#
# PARAMETERS: (via register)
#             ECX - buffer size
#             ESI - buffer address
#
# RETURN:     none
#
#-------------------------------------------------------------------


        .equ    FD_STDOUT,    1 # stdout file descriptor


#==================================================================
# S E C T I O N   T E X T
#==================================================================
        .section        .text

        .extern write
        .global __wrap_screen_write
        .type   __wrap_screen_write, @function
__wrap_screen_write:
        pushl   %ebp
        movl    %esp, %ebp

        push    %ecx
        push    %esi
        pushl   $FD_STDOUT
        call    write

        movl    %ebp, %esp
        popl    %ebp
        ret

