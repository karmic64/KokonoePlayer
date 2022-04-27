
### check user variables

ifndef KN_DIR
$(warning KN_DIR not defined. Defaulting to the current working directory.)
KN_DIR := ./
endif
ifndef KN_SONG_SLOTS
$(warning KN_SONG_SLOTS not defined. Defaulting to 1.)
KN_SONG_SLOTS := 1
endif
ifndef KN_MODULES
$(error KN_MODULES not defined)
endif


### build tools

ifdef COMSPEC
KN_DOTEXE ?= .exe
else
KN_DOTEXE ?=
endif

KN_CC ?= gcc
KN_VASM ?= vasmm68k_mot
KN_WLAZ80 ?= wla-z80
KN_WLALINK ?= wlalink

KN_CFLAGS ?= -s -Ofast -Wall -Wextra
KN_CLIBS ?= -lz -lm
KN_VASMFLAGS ?= -I$(KN_DIR) -spaces -opt-speed -m68000 -DKN_SONG_SLOTS=$(KN_SONG_SLOTS)
KN_WLAZ80FLAGS ?= -I $(KN_DIR)
KN_WLALINKFLAGS ?= -b


### inputs

KN_CONVERT ?= $(KN_DIR)convert.c
KN_GENERATE_DATA ?= $(KN_DIR)generate-data.c

KN_68K_PLAYER ?= $(KN_DIR)68k-player.asm
KN_Z80_PLAYER ?= $(KN_DIR)z80-player.asm
KN_Z80_PLAYER_LN ?= $(KN_DIR)z80-player.ln

KN_H ?= $(KN_DIR)kn.h


### outputs

KN_OUT_CONVERT ?= $(KN_DIR)kn-convert$(DOTEXE)
KN_OUT_GENERATE_DATA ?= $(KN_DIR)kn-generate-data$(DOTEXE)

KN_OUT_COMPILED_MODULE ?= $(KN_DIR)KN-COMPILED-MODULE.asm
KN_OUT_GENERATED_DATA ?= $(KN_DIR)KN-GENERATED-DATA.asm

KN_OUT_68K_PLAYER ?= $(KN_DIR)68k-player.elf
KN_OUT_Z80_PLAYER ?= $(KN_DIR)z80-player.o
KN_OUT_Z80_PLAYER_LN ?= $(KN_DIR)z80-player.bin

KN_DEPS_68K_PLAYER ?= $(KN_68K_PLAYER) $(KN_OUT_Z80_PLAYER_LN) $(KN_OUT_COMPILED_MODULE) $(KN_OUT_GENERATED_DATA)


# for external use
KN_OUT := $(KN_OUT_68K_PLAYER)
KN_DEPS = $(KN_DEPS_68K_PLAYER)


### phony targets

.PHONY: kn-default kn-clean

kn-default:
	@echo "Please don't run make directly on this Makefile."
	@echo "Refer to the documentation for how to properly integrate it into your project."
	@exit 1

kn-clean:
	-rm -f $(KN_OUT_CONVERT) $(KN_OUT_GENERATE_DATA) \
		 $(KN_OUT_COMPILED_MODULE) $(KN_OUT_GENERATED_DATA) \
		 $(KN_OUT_68K_PLAYER) $(KN_OUT_Z80_PLAYER) $(KN_OUT_Z80_PLAYER_LN)


### rules

$(KN_DIR)kn-%$(DOTEXE): $(KN_DIR)%.c
	$(KN_CC) $(KN_CFLAGS) -o $@ $< $(KN_CLIBS)

$(KN_OUT_COMPILED_MODULE): $(KN_OUT_CONVERT) $(KN_MODULES)
	$(KN_OUT_CONVERT) $@ $(KN_MODULES)

$(KN_OUT_GENERATED_DATA): $(KN_OUT_GENERATE_DATA)
	$(KN_OUT_GENERATE_DATA) $@

$(KN_OUT_Z80_PLAYER): $(KN_Z80_PLAYER)
	$(KN_WLAZ80) $(KN_WLAZ80FLAGS) -o $@ $<

# changing the directory is required, wlalink doesn't support include paths
# TODO: since we change the directory first, KN_WLALINK is not relative to the same place as the other KN_ build tool variables
$(KN_OUT_Z80_PLAYER_LN): $(KN_Z80_PLAYER_LN) $(KN_OUT_Z80_PLAYER)
	cd $(KN_DIR) && $(KN_WLALINK) $(KN_WLALINKFLAGS) $(subst $(KN_DIR),,$<) $(subst $(KN_DIR),,$@)

$(KN_OUT_68K_PLAYER): $(KN_DEPS_68K_PLAYER)
	$(KN_VASM) -Felf $(KN_VASMFLAGS) -o $@ $<


