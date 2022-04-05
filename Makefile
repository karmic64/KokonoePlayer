ifdef COMSPEC
DOTEXE := .exe
else
DOTEXE :=
endif


CFLAGS := -s -Ofast -Wall -Wextra
LIBS := -lz -lm


MODS_DIR := mods



68K_PLAYER_DEPS := 68k-player.asm z80-player.bin GENERATED-DATA.asm COMPILED-MODULE.asm
VASM_FLAGS := -spaces -opt-speed -m68000



.PHONY: default library test-rom

default:
	@echo You must specify a rule.

library: 68k-player.elf

test-rom: test-rom.gen





%$(DOTEXE): %.c
	$(CC) $(CFLAGS) -o $@ $< $(LIBS)


GENERATED-DATA.asm: generate-data$(DOTEXE)
	./generate-data$(DOTEXE)

COMPILED-MODULE.asm: convert$(DOTEXE) $(MODS_DIR)/*
	./convert$(DOTEXE) $(MODS_DIR)/*




z80-player.bin: z80-player.asm z80-player.ln
	wla-z80 -o z80-player.o z80-player.asm
	wlalink -b z80-player.ln z80-player.bin

68k-player.elf: $(68K_PLAYER_DEPS)
	vasmm68k_mot -Felf $(VASM_FLAGS) -o 68k-player.elf 68k-player.asm



test-rom.gen: test-rom.asm exceptions.asm font.rom $(68K_PLAYER_DEPS)
	vasmm68k_mot -Fbin $(VASM_FLAGS) -o test-rom.gen test-rom.asm