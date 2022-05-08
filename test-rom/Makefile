
.PHONY: default clean
default: test-rom.gen
clean: kn-clean
	-rm -f test-rom.elf test-rom.gen


KN_DIR := ../
KN_TYPE := 68k
KN_SONG_SLOTS := 2
KN_MODULES := ../test-mods/*

include $(KN_DIR)Makefile


LD := m68k-linux-gnu-ld

test-rom.elf: test-rom.asm font.rom exceptions.asm
	$(KN_VASM) -Felf $(KN_VASMFLAGS) -o $@ $<

test-rom.gen: link.ld test-rom.elf $(KN_OUT)
	$(LD) -M -T link.ld --oformat binary -o $@ test-rom.elf $(KN_OUT)
