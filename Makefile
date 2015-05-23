#=============================================================================
#
# Makefile
#
#=============================================================================

SUBDIRS     = boot welcome timeoday tickdemo

.PHONY: all subdirs $(SUBDIRS)
.SECONDARY:

all: subdirs

subdirs : $(SUBDIRS)

$(SUBDIRS):
	$(MAKE) -C $@

timeoday: boot
pmtimer: boot

.PHONY: clean
clean:
	@for d in $(SUBDIRS); \
	do \
	    $(MAKE) --directory=$$d clean; \
	done

