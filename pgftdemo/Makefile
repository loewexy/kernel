#=============================================================================
#
# Makefile
#
#=============================================================================


include ../common_defs.mk

BOOTDIR     = ../boot
BOOTLOADER  = $(BOOTDIR)/bootload.bin
LIBKERNEL   = ../libkernel/libkernel.a
LIBMINIC    = ../libminic/libminic.a
LDSCRIPT    = ldscript
PROG        = pgftdemo

CFLAGS     += -I../libminic/inc
#CFLAGS     += -Dprintf=asm_printf

TARGETS     = $(PROG).flp $(PROG).sym
OBJS        = $(PROG).o pfhandler.o paging.o isrpfe.o irqpit.o
OBJS       += kgetc.o kgets.o
OBJS       += monitor.o chkcpuid.o

LDFLAGS    += --wrap printf --wrap sprintf --wrap strlen

.PHONY: all
.SECONDARY:

all: $(TARGETS)

$(PROG).flp : $(PROG).bin $(BOOTLOADER)
	$(call update-image,$@,$<,$(FLP_USF_POS))

$(PROG).elf : $(OBJS) $(LIBKERNEL) $(LIBMINIC) $(LDSCRIPT)
	@echo LD -o $@
	@$(LD) $(LDFLAGS) --build-id=md5 -Map=$(PROG).map --cref $(OBJS) -T $(LDSCRIPT) -o $@ $(LIBKERNEL) $(LIBMINIC)
	@size -A $@

$(PROG).o : ../inc/comgdt.inc

$(OBJS) : ../common_defs.mk
pfhandler.o : types.h
pfhandler.o : pgftdemo.h

.PHONY: clean
clean:
	rm -f *.o *.lst *.map *.sym *.bin *.elf $(TARGETS)

