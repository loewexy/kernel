#=============================================================================
#
# Makefile
#
#=============================================================================


include ../common_defs.mk

BOOTDIR     = ../boot
BOOTLOADER  = $(BOOTDIR)/bootload.bin
LDSCRIPT    = ../ldscript_bin
PROG        = timeoday

TARGETS     = $(PROG).flp

.PHONY: all
.SECONDARY:

all: $(TARGETS)

$(PROG).flp : $(PROG).bin $(BOOTLOADER)
	$(call update-image,$@,$<,$(FLP_USF_POS))

# Note: program is directly linked into binary output format
#       without intermediate generation of an ELF output file
$(PROG).bin : $(PROG).o $(LDSCRIPT)
	@echo LD -o $@
	@$(LD) $(LDFLAGS) $< -T $(LDSCRIPT) -o $@


.PHONY: clean
clean:
	rm -f *.o *.lst *.bin $(TARGETS)

