
.PHONY: default clean
default: test-rom.gen
clean: kn-clean
	-rm -f test-rom.gen


KN_DIR := ../
KN_SONG_SLOTS := 2
KN_MODULES := ../test-mods/*

include ../Makefile


test-rom.gen: test-rom.asm font.rom exceptions.asm $(KN_68K_PLAYER) $(KN_DEPS_68K_PLAYER)
	$(KN_VASM) -Fbin $(KN_VASMFLAGS) -o $@ $<
