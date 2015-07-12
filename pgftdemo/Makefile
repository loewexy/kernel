#=============================================================================
#
# Makefile
#
#=============================================================================


include ../common_defs.mk

BOOTDIR     = ../boot
BOOTLOADER  = $(BOOTDIR)/bootload.bin
LIBKERNEL   = ../libkernel/libkernel.a
LDSCRIPT    = ldscript
PROG        = pgftdemo

TARGETS     = $(PROG).flp $(PROG).sym
OBJS        = $(PROG).o pfhandler.o paging.o isrpfe.o irqpit.o kgetc.o kgets.o monitor.o kprintf.o

.PHONY: all
.SECONDARY:

all: $(TARGETS)

$(PROG).flp : $(PROG).bin $(BOOTLOADER)
	$(call update-image,$@,$<,$(FLP_USF_POS))

$(PROG).elf : $(OBJS) $(LIBKERNEL) $(LDSCRIPT)
	@echo LD -o $@
	@$(LD) $(LDFLAGS) --build-id=md5 -Map=$(PROG).map --cref $(OBJS) -T $(LDSCRIPT) -o $@ $(LIBKERNEL)
	@size -A $@

$(PROG).o : ../inc/comgdt.inc

$(OBJS) : ../common_defs.mk
pfhandler.o : types.h
pfhandler.o : pfhandler.h

.PHONY: clean
clean:
	rm -f *.o *.lst *.map *.sym *.bin *.elf $(TARGETS)

