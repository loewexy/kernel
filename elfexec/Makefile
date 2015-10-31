#=============================================================================
#
# Makefile
#
#=============================================================================


include ../common_defs.mk

BOOTDIR     = ../dasboot
BOOTLOADER  = $(BOOTDIR)/bootload.bin
LIBKERNEL   = ../libkernel/libkernel.a
LDSCRIPT    = ldscript
PROG        = elfexec
DEMOAPPS    = ../demoapps/demoapp
RAMDISK     = ../tools/ramdisk

TARGETS     = $(PROG).flp

.PHONY: all
.SECONDARY:
.DELETE_ON_ERROR:

all: $(TARGETS)

$(PROG).flp : $(PROG).bin $(BOOTLOADER) $(DEMOAPP)
	$(call update-image,$@,$<,$(FLP_USF_POS))
	@$(RAMDISK) $@ $(FLP_TOC_POS) $(FLP_ELF_POS) $(DEMOAPPS)

$(PROG).elf : $(PROG).o $(LIBKERNEL) $(LDSCRIPT)
	@echo LD -o $@
	@$(LD) $(LDFLAGS) --build-id=md5 -Map=$(PROG).map --cref $< -T $(LDSCRIPT) -o $@ $(LIBKERNEL)
	@size -Bx $@

$(PROG).o : ../inc/comgdt.inc
$(PROG).o : ../common_defs.mk

.PHONY: clean
clean:
	rm -f *.o *.lst *.map *.sym *.bin *.elf $(TARGETS)

