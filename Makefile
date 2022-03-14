ifdef COMSPEC
DOTEXE := .exe
else
DOTEXE :=
endif


CFLAGS := -s -Ofast -Wall -Wextra -Wpedantic



.PHONY: default library test-rom

default:
	@echo You must specify a rule.

library: 68k-player.elf

test-rom: test-rom.gen







z80-player.bin: z80-player.asm z80-player.ln
	wla-z80 -o z80-player.o z80-player.asm
	wlalink -b z80-player.ln z80-player.bin

68k-player.elf: 68k-player.asm z80-player.bin
	vasmm68k_mot -Felf -spaces -opt-speed -m68000 -o 68k-player.elf 68k-player.asm



test-rom.gen: test-rom.asm 68k-player.asm z80-player.bin
	vasmm68k_mot -Fbin -spaces -opt-speed -m68000 -o test-rom.gen test-rom.asm