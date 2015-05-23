#=============================================================================
#
# Makefile
#
#=============================================================================


include ../common_defs.mk
PROG        = bootload

TARGETS = $(PROG).bin

.PHONY: all
.SECONDARY:

all: $(TARGETS)

$(PROG).bin : $(PROG).elf
	objcopy -O binary $< $@

$(PROG).elf : $(PROG).o ldscript
	@echo LD -o $@
	@$(LD) $(LDFLAGS) $< -T ldscript -o $@

%.o %.lst : %.s
	@echo AS $<
	@$(AS) --32 -almgns=$*.lst -o $*.o -c $<

%.bin %.lst : %.asm
	@echo NASM $<
	@$(NASM) $(NASMOPT) -l $*.lst -o $@ $<


.PHONY: clean
clean:
	rm -f *.o *.lst *.elf $(TARGETS)

