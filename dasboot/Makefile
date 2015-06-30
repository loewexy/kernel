#=============================================================================
#
# Makefile
#
#=============================================================================


include ../common_defs.mk

PROG        = bootload
LDSCRIPT    = ldscript
OBJS        = stage0.o stage1.o
OBJS       += cmosrtc.o a20ctrl.o memchk.o extmem.o loadprog.o
TARGETS     = $(PROG).bin

.PHONY: all
.SECONDARY:

all: $(TARGETS)

$(PROG).elf : $(OBJS) $(LDSCRIPT)
	@echo LD -o $@
	@$(LD) $(LDFLAGS) -Map=$(PROG).map --cref -T $(LDSCRIPT) $(OBJS) -o $@
	@size -A $@

.PHONY: clean
clean:
	rm -f *.o *.lst *.bin *.map *.elf $(TARGETS)

