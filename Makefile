#=============================================================================
#
# Makefile
#
#=============================================================================

SUBDIRS     = boot libkernel libminic
SUBDIRS    += pmhello pgftdemo

.PHONY: all subdirs $(SUBDIRS)
.SECONDARY:

all: subdirs

subdirs : $(SUBDIRS)

$(SUBDIRS):
	$(MAKE) -C $@

pmtimer: boot

.PHONY: clean
clean:
	@for d in $(SUBDIRS); \
	do \
	    $(MAKE) --directory=$$d clean; \
	done

