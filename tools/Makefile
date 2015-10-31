#=============================================================================
#
# Makefile
#
#=============================================================================

.PHONY: all

CC          = gcc
LD          = ld
CFLAGS      = -Wall -g -O2 -std=gnu99 #-m32

TARGETS     = ramdisk

all: $(TARGETS)

.PHONY: clean
clean:
	rm -f *.o *.ps $(TARGETS)

