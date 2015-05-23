#=============================================================================
#
# Makefile
#
#=============================================================================


include ../common_defs.mk

LDSCRIPT    = ../ldscript_bin
PROG        = tickdemo

TARGETS     = $(PROG).flp

.PHONY: all
.SECONDARY:

all: $(TARGETS)

$(PROG).flp : $(PROG).bin
	if [ ! -f $@ ]; then \
	    mkdosfs -C $@ 1440 ; \
	fi;
	dd status=noxfer conv=notrunc if=$< of=$@

# Note: program is directly linked into binary output format
#       without intermediate generation of an ELF output file
$(PROG).bin : $(PROG).o $(LDSCRIPT)
	@echo LD -o $@
	@$(LD) $(LDFLAGS) $< -T $(LDSCRIPT) -o $@

.PHONY: clean
clean:
	rm -f *.o *.lst *.bin $(TARGETS)

