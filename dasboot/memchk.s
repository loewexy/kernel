
        .section        .text
        .code16
        .type           check_memory_avail, @function
        .global         check_memory_avail
        .align  8
check_memory_avail:
        enter   $0, $0
        pusha

        #----------------------------------------------------------
        # invoke ROM-BIOS service to obtain memory-size (in KB)
        #----------------------------------------------------------
        xor     %ax, %ax
        int     $0x12        # get ram size below 1MB into AX
        jc      .Lerr
        test    %ax, %ax
        jz      .Lerr
        mov     %ax, (%di)

        xor     %cx, %cx
        xor     %dx, %dx
        mov     $0xe801, %ax
        int     $0x15        # request upper memory size
        jc      .Lerr
        cmp     $0x86, %ah   # unsupported function?
        je      .Lerr
        cmp     $0x80, %ah   # invalid command?
        je      .Lerr
        #----------------------------------------------------------
        # result is either in CX/DX or AX/BX
        #----------------------------------------------------------
        jcxz    .Luseax      # was the CX result invalid?
        mov     %cx, %ax     #   no, then copy into AX/BX
        mov     %dx, %bx
.Luseax:
        #----------------------------------------------------------
        # AX = number of contiguous Kb, 1M to 16M
        # BX = contiguous 64Kb pages above 16M
        #----------------------------------------------------------
        mov     %ax, 2(%di)
        mov     %bx, 4(%di)
.Lerr:
        popa
        leave
        ret

