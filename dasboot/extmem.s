
        .equ    TOC_SECT, 2878          # ramdisk TOC disk sector
        .equ    TOC_ADDR, 0x000500      # address of ramdisk TOC
        .equ    BUF_ADDR, 0x040000      # address of disk buffer
        .equ    BUF_SIZE, 0x010000      # buffer size (64 kB)
        .equ    EXT_ADDR, 0x100000      # extended memory address

        .section        .data
        .align  4
extsec: .word   0
seccnt: .word   0

        .section        .text
        .code16
        .type           load_extmem, @function
        .global         load_extmem
        .align  8
load_extmem:
        enter   $0, $0
        pusha

        cli

        #----------------------------------------------------------
        # "Unreal Mode"
        #----------------------------------------------------------

        #----------------------------------------------------------
        # enable protected mode
        #----------------------------------------------------------
        mov     %cr0, %eax              # get machine status
        bts     $0, %eax                # set PE-bit's image
        mov     %eax, %cr0              # turn on the PE-bit

        #----------------------------------------------------------
        # load new GDT and IDT for protected mode
        #----------------------------------------------------------
        lgdtl   regGDT

        push    %ds
        push    %es
        mov     $0x08, %bx              # select descriptor 1
        mov     %bx, %ds
        mov     %bx, %es

        #----------------------------------------------------------
        # disable protected mode
        #----------------------------------------------------------
        mov     %cr0, %eax              # get machine's status
        btr     $0, %eax                # clear PE-bit's image
        mov     %eax, %cr0              # turn off protection
        pop     %es
        pop     %ds

        #----------------------------------------------------------
        # read final two sectors from floppy disk in order to check
        # whether a ramdisk table of contents is present there
        #----------------------------------------------------------
        mov     $TOC_ADDR, %esi         # TOC linear address
        movw    $0, loadloc             # TOC segment offset
        movw    $TOC_ADDR>>4, loadloc+2 # TOC segment address
        pushw   $TOC_SECT
        call    read_one_sector
        pushw   $TOC_SECT+1
        call    read_one_sector
        cmpl    $0x444d4152, (%esi)     # check 'RAMD'
        jne     .Lend
        cmpl    $0x204b5349, 4(%esi)    # check 'ISK '
        jne     .Lend
        movw    20(%esi), %dx           # read start sector
        movl    12(%esi), %ebx          # read size in bytes
        dec     %ebx                    # and convert size
        shr     $9, %ebx                # into number of sectors
        inc     %ebx
        movw    %bx, extsec
        movw    $0, seccnt

        mov     $EXT_ADDR, %edi
.Loutloop:
        #----------------------------------------------------------
        # read block of sectors (max 64 kB) into buffer
        #----------------------------------------------------------
        movw    $0, loadloc             # buffer segment offset
        movw    $BUF_ADDR>>4, loadloc+2 # buffer segment address
        mov     $BUF_SIZE>>9, %cx       # default number of sectors to read
        cmp     %cx, %bx                # check agaist number of sector left
        cmovb   %bx, %cx                # cx = (bx < cx) ? bx : cx
        sub     %cx, %bx                # adjust number of remaing sectors
        addw    %cx, seccnt
        #----------------------------------------------------------
        # read sectors from floppy disk into buffer one single
        # sector at a time
        #----------------------------------------------------------
.Lreadloop:
        push    %dx                     # put parameter on stack
        call    read_one_sector
        inc     %dx
        loop    .Lreadloop

        mov     $BUF_SIZE/4, %ecx
        mov     $BUF_ADDR, %esi
.Lcopy32:
        #rep movsl   (%esi), (%edi)      <- does not work! check %es
        mov     (%esi), %eax
        mov     %eax, (%edi)
        add     $4, %esi
        add     $4, %edi
        loop    .Lcopy32

        cmp     $0, %bx
        ja      .Loutloop
.Lend:
        sti

        popa
        leave
        ret

