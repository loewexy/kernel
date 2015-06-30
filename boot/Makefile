#=============================================================================
#
# Makefile
#
#=============================================================================


include ../common_defs.mk

PROG        = bootload
LDSCRIPT    = ldscript
TARGETS     = $(PROG).bin

.PHONY: all
.SECONDARY:

all: $(TARGETS)

$(PROG).elf : $(PROG).o $(LDSCRIPT)
	@echo LD -o $@
	@$(LD) $(LDFLAGS) -Map=$(PROG).map --cref -T $(LDSCRIPT) $(PROG).o -o $@
	@size -A $@

$(PROG).o : ../common_defs.mk

.PHONY: clean
clean:
	rm -f *.o *.lst *.map *.sym *.bin *.elf $(TARGETS)
