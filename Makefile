
### check user variables

ifndef KN_DIR
$(warning KN_DIR not defined. Defaulting to the current working directory.)
KN_DIR := ./
endif
ifndef KN_TYPE
$(warning KN_TYPE not defined. Defaulting to 68k.)
KN_TYPE := 68k
KN_TYPE_DIR := $(KN_DIR)type-$(KN_TYPE)/
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
KN_VASMFLAGS ?= -I$(KN_DIR) -I$(KN_TYPE_DIR) -spaces -opt-speed -m68000 -DKN_SONG_SLOTS=$(KN_SONG_SLOTS)
KN_WLAZ80FLAGS ?= -I $(KN_DIR) -I $(KN_TYPE_DIR)
KN_WLALINKFLAGS ?= -b


### generic inputs

KN_CONVERT ?= $(KN_DIR)convert.c
KN_GENERATE_DATA ?= $(KN_DIR)generate-data.c

KN_H ?= $(KN_DIR)kn.h


### generic outputs

KN_OUT_CONVERT ?= $(KN_DIR)kn-convert$(DOTEXE)
KN_OUT_GENERATE_DATA ?= $(KN_DIR)kn-generate-data$(DOTEXE)

KN_OUT_COMPILED_MODULE ?= $(KN_DIR)KN-COMPILED-MODULE.asm
KN_OUT_GENERATED_DATA ?= $(KN_DIR)KN-GENERATED-DATA.asm



### phony targets

.PHONY: kn-default kn-clean

kn-default:
	@echo "Please don't run make directly on this Makefile."
	@echo "Refer to the documentation for how to properly integrate it into your project."
	@exit 1

kn-clean: kn-type-clean
	-$(RM) $(KN_OUT_CONVERT) $(KN_OUT_GENERATE_DATA) \
		 $(KN_OUT_COMPILED_MODULE) $(KN_OUT_GENERATED_DATA)


### per-type stuff

include $(KN_TYPE_DIR)Makefile

ifndef KN_OUT
$(error KN_OUT not defined. This is a bug in KokonoePlayer)
endif


### generic rules

$(KN_DIR)kn-%$(DOTEXE): $(KN_DIR)%.c
	$(KN_CC) $(KN_CFLAGS) -o $@ $< $(KN_CLIBS)

$(KN_OUT_COMPILED_MODULE): $(KN_OUT_CONVERT) $(KN_MODULES)
	$(KN_OUT_CONVERT) $@ $(KN_MODULES)

$(KN_OUT_GENERATED_DATA): $(KN_OUT_GENERATE_DATA)
	$(KN_OUT_GENERATE_DATA) $@




