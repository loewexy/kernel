#=============================================================================
#
# Makefile
#
#=============================================================================

SUBDIRS     = boot libkernel libminic
SUBDIRS    += pmhello pgftdemo
SUBDIRS    += dasboot demoapps tools elfexec

.PHONY: all subdirs $(SUBDIRS)
.SECONDARY:

all: subdirs

subdirs : $(SUBDIRS)

$(SUBDIRS):
	$(MAKE) -C $@

elfexec:     dasboot
$(SUBDIRS):  common_defs.mk

.PHONY: clean
clean:
	@for d in $(SUBDIRS); \
	do \
	    $(MAKE) --directory=$$d clean; \
	done

