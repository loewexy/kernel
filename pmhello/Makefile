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
PROG        = pmhello

TARGETS     = $(PROG).flp

.PHONY: all
.SECONDARY:

all: $(TARGETS)

$(PROG).flp : $(PROG).bin $(BOOTLOADER)
	$(call update-image,$@,$<,$(FLP_USF_POS))

$(PROG).elf : $(PROG).o $(LIBKERNEL) $(LDSCRIPT)
	@echo LD -o $@
	@$(LD) $(LDFLAGS) --build-id=md5 -Map=$(PROG).map --cref $< -T $(LDSCRIPT) -o $@ $(LIBKERNEL)


$(PROG).o : ../inc/comgdt.inc

.PHONY: clean
clean:
	rm -f *.o *.lst *.map *.sym *.bin *.elf $(TARGETS)

