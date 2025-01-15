TOP = ..
include $(TOP)/Makefile.global

OBJ = $(TOP)/obj/boot

A_SRC = $(wildcard *.asm)
A_MOD = $(patsubst %.asm, %, $(A_SRC))
A_OBJ = $(patsubst %.asm, $(OBJ)/%.o, $(A_SRC))

.PHONY: all clean $(A_MOD)

all: $(OBJ) $(A_OBJ)

$(A_OBJ): $(OBJ)/%.o : %.asm
	$(AS) $(AS_OPTS) $(@F:.o=.asm) -o $@

$(OBJ):
	mkdir -p $(OBJ)

$(A_MOD): % : %.asm
	$(AS) $(AS_OPTS) $@.asm -o $(OBJ)/$@.o

clean:
	rm -rf $(OBJ)

