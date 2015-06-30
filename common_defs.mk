#=============================================================================
#
# Makefile - Common Definitions
#
#=============================================================================


CC          = gcc
AS          = as
LD          = ld
AR          = ar
AROPT       = rcsv
NASM        = nasm
NASMOPT     = -g -f elf -F dwarf
CFLAGS      = -m32 -Wall -Werror -Wextra -g -O1 -std=gnu99
LDFLAGS     = -melf_i386 --warn-common --fatal-warnings -n
PS2PDF      = ps2pdf
A2PS        = a2ps
AOPT        = --line-numbers=1
DDOPT       = conv=notrunc status=noxfer

FLP_TOC_POS  := 2878
FLP_USF_POS  :=   66
FLP_ELF_POS  :=  322


define update-image
    @if [ ! -f $1 ]; then \
        mkdosfs -C $1 1440 > /dev/null 2>&1 ; \
    fi;
    @echo DD $1
    @if [ -f $(BOOTLOADER) ]; then \
        dd $(DDOPT) if=$(BOOTLOADER) of=$1 ; \
        dd $(DDOPT) if=$2 of=$1 seek=$3 ; \
    else \
        echo "Error: file" $(BOOTLOADER) "does not exist" ; \
        rm -f $1 ; \
    fi;
endef


%.bin : %.elf
	objcopy -O binary $< $@

%.sym : %.elf
	objcopy --only-keep-debug $< $@

%.o %.lst : %.s
	@echo AS $<
	@$(AS) --32 -I../inc -almgns=$*.lst -o $*.o -c $<

%.bin %.lst : %.asm
	@echo NASM $<
	@$(NASM) $(NASMOPT) -l $*.lst -o $@ $<

