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

SRCDIR     = src
OBJDIR     = obj
CSRCS      := $(wildcard $(SRCDIR)/*.c)
ASRCS      := $(wildcard $(SRCDIR)/*.s)
ASMSRCS    := $(wildcard $(SRCDIR)/*.asm)
COBJS      := $(patsubst $(SRCDIR)/%.c,$(OBJDIR)/%.o,$(CSRCS))
AOBJS      := $(patsubst $(SRCDIR)/%.s,$(OBJDIR)/%.o,$(ASRCS))
ASMOBJS    := $(patsubst $(SRCDIR)/%.asm,$(OBJDIR)/%.o,$(ASMSRCS))
OBJS       := $(COBJS) $(AOBJS) $(ASMOBJS)
foo        := $(shell test -d $(OBJDIR) || mkdir -p $(OBJDIR))

TARGETS     = $(PROG).flp $(PROG).sym

.PHONY: all
.SECONDARY:

all: $(TARGETS)

$(PROG).flp : $(PROG).bin $(BOOTLOADER)
	$(call update-image,$@,$<,$(FLP_USF_POS))

$(PROG).elf : $(OBJS) $(LIBKERNEL) $(LIBMINIC) $(LDSCRIPT)
	@echo LD -o $@
	@$(LD) $(LDFLAGS) --build-id=md5 -Map=$(PROG).map --cref $(OBJS) -T $(LDSCRIPT) -o $@ $(LIBKERNEL) $(LIBMINIC)
	@size -A $@

$(OBJDIR)/%.o $(OBJDIR)/%.lst : $(SRCDIR)/%.s
	@echo AS $<
	@$(AS) $(ASOPT) -almgns=$(OBJDIR)/$*.lst -o $(OBJDIR)/$*.o -c $<

$(OBJDIR)/%.o $(OBJDIR)/%.lst : $(SRCDIR)/%.asm
	@echo NASM $<
	@$(NASM) $(NASMOPT) -l $(OBJDIR)/$*.lst -o $@ $<

$(OBJDIR)/%.o : $(SRCDIR)/%.c
	@echo CC $<
	@$(CC) $(CFLAGS) -c -o $@ $<

$(PROG).o : ../inc/comgdt.inc
$(PROG).o : ../common_defs.mk

$(OBJS) : ../common_defs.mk
$(OBJDIR)/pfhandler.o : $(SRCDIR)/types.h
$(OBJDIR)/pfhandler.o : $(SRCDIR)/pgftdemo.h

.PHONY: clean
clean:
	rm -rf $(OBJDIR) *.map *.sym *.bin *.elf $(TARGETS)

