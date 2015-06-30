#=============================================================================
#
# Makefile
#
#=============================================================================

CC          = gcc
AS          = as
LD          = ld
NASM        = nasm
NASMOPT     = -g -f elf -F dwarf -I./syscall/
CFLAGS      = -Wall -Werror -g -O1 -std=c99
GLDFLAGS    = -melf_i386 --warn-common --fatal-warnings
PS2PDF      = ps2pdf
A2PS        = a2ps
AOPT        = --line-numbers=1

TARGETS = linuxapp demoapp


.PHONY: all
.SECONDARY:

all: $(TARGETS)

linuxapp : linuxapp.o
	$(LD) -melf_i386 -o $@ $<

demoapp : demoapp.o
	$(LD) -melf_i386 -o $@ $<

%.o %.lst : %.s
	@echo AS $<
	@$(AS) --32 -g -almgns=$*.lst -o $*.o -c $<

%.o %.lst : %.asm
	@echo NASM $<
	@$(NASM) $(NASMOPT) -l $*.lst -o $@ $<

%.pdf : %.ps
	$(PS2PDF) $< $@

%.ps : %.asm
	$(A2PS) $< $(AOPT) -o $@

%.ps : %.lst
	$(A2PS) -1rl110 -o $@ $<

.PHONY: clean
clean:
	rm -f *.o *.lst *.ps *.pdf $(TARGETS)

