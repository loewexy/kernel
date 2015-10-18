#=============================================================================
#
# Makefile
#
#=============================================================================

LIBMINIC    = ../libminic.a

CC          = gcc
LD          = ld
NASM        = nasm
NASMOPT     = -g -f elf -F dwarf
AS          = as
ASOPT       = -g --32 -I../inc
CFLAGS      = -Wall -g -m32 -Og -std=gnu99
CFLAGS     += -fno-omit-frame-pointer -fno-stack-protector -fno-inline -fno-builtin
CFLAGS     += -I../inc
CFLAGS     += -Wl,--wrap,screen_write

TARGETS     = printf_test


.PHONY: all

all: $(TARGETS)

printf_test : printf_test.o $(LIBMINIC) wrap_screen_write.o
	@echo CC $<
	@$(CC) $(CFLAGS) -o $@ $^

printf_test.o : Makefile

%.o : %.c
	@echo CC $<
	@$(CC) $(CFLAGS) -o $*.o -c $<

%.o %.lst : %.asm
	@echo NASM $<
	@$(NASM) $(NASMOPT) -l $*.lst -o $@ $<

%.o %.lst : %.s
	@echo AS $<
	@$(AS) $(ASOPT) -almgns=$*.lst -o $*.o -c $<


.PHONY: clean
clean:
	rm -f *.o *.lst $(TARGETS)

