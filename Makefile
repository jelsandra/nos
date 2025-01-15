TOP = .
include $(TOP)/Makefile.global

SUBDIRS = boot
SUBDIRS += kernel
SUBDIRS += conf

TARGETS = all cleanall

OBJ = $(TOP)/obj
IMAGE = $(TOP)/OS.img
EMUL = qemu-system-x86_64 -display sdl -fda
EDBG = -gdb stdio
DEBUG = bochs
DBGOPTS=-f $(TOP)/debug.bsrc
#DEBUG = gdb
#DBGOPTS = --eval-command="set architecture i8086" --eval-command="set step-mode on" --eval-command="target remote | $(EMUL) $(IMAGE) $(EDBG)"

FSTAT = stat -c %s $(OBJ)
$(IMAGE): KSIZE = $(shell stat -c %s obj/kernel/kernel.o 2>/dev/null)
$(IMAGE): ISIZE = $(shell stat -c %s obj/kernel/init.o 2>/dev/null)
$(IMAGE): DSIZE = $(shell stat -c %s obj/conf/disk.o 2>/dev/null)
$(IMAGE): FSIZE = $(shell stat -c %s obj/conf/fat12.o 2>/dev/null)
$(IMAGE): ASIZE = $(shell stat -c %s obj/kernel/alloc.o 2>/dev/null)
$(IMAGE): PSIZE = $(shell stat -c %s obj/conf/prompt.o 2>/dev/null)
$(IMAGE): AS_OPTS += -d INIT_size=$(ISIZE) -d KERNEL_size=$(KSIZE) -d DISK_size=$(DSIZE) -d FAT12_size=$(FSIZE) -d ALLOC_size=$(ASIZE) -d PROMPT_size=$(PSIZE) -w-number-overflow

$(TARGETS): $(OBJ)
	for dir in $(SUBDIRS); do \
		(cd $$dir && $(MAKE) $@); \
	done
	touch image.s

$(IMAGE): image.s
	@if [ ! -d $(OBJ) ]; then echo "Please run \"$(MAKE) all\" first."; exit 1; fi
	$(AS) $(AS_OPTS) image.s -o $(IMAGE)

$(OBJ):
	mkdir $(OBJ)

test: $(IMAGE)
	$(EMUL) $(IMAGE)

debug: $(IMAGE)
	$(DEBUG) $(DBGOPTS)

.PHONY: clean
clean:
	rm -rf $(OBJ) *.img

