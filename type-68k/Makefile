
### inputs

KN_68K_PLAYER ?= $(KN_TYPE_DIR)68k.asm
KN_Z80_PLAYER ?= $(KN_TYPE_DIR)z80.asm
KN_Z80_PLAYER_LN ?= $(KN_TYPE_DIR)z80.ln


### outputs

KN_OUT_68K_PLAYER ?= $(KN_TYPE_DIR)68k.elf
KN_OUT_Z80_PLAYER ?= $(KN_TYPE_DIR)z80.o
KN_OUT_Z80_PLAYER_LN ?= $(KN_TYPE_DIR)z80.bin

KN_DEPS_68K_PLAYER ?= $(KN_68K_PLAYER) $(KN_OUT_Z80_PLAYER_LN) $(KN_OUT_COMPILED_MODULE) $(KN_OUT_GENERATED_DATA)


# for external use
KN_OUT := $(KN_OUT_68K_PLAYER)
KN_DEPS := $(KN_DEPS_68K_PLAYER)



### phony targets

.PHONY: kn-type-default kn-type-clean

kn-type-default:
	@echo "Please don't run make directly on this Makefile."
	@echo "Refer to the documentation for how to properly integrate it into your project."
	@exit 1

kn-type-clean:
	-$(RM) $(KN_OUT_68K_PLAYER) $(KN_OUT_Z80_PLAYER) $(KN_OUT_Z80_PLAYER_LN) $(KN_Z80_PLAYER_LN)




$(KN_OUT_Z80_PLAYER): $(KN_Z80_PLAYER)
	$(KN_WLAZ80) $(KN_WLAZ80FLAGS) -o $@ $<

# wlalink doesn't support include paths, so dynamically generate link file
$(KN_OUT_Z80_PLAYER_LN): $(KN_OUT_Z80_PLAYER)
	echo [objects] > $(KN_Z80_PLAYER_LN) && \
		echo $(KN_OUT_Z80_PLAYER) >> $(KN_Z80_PLAYER_LN) && \
		$(KN_WLALINK) $(KN_WLALINKFLAGS) $(KN_Z80_PLAYER_LN) $@

$(KN_OUT_68K_PLAYER): $(KN_DEPS_68K_PLAYER)
	$(KN_VASM) -Felf $(KN_VASMFLAGS) -o $@ $<


