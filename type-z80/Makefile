
### inputs

KN_68K ?= $(KN_TYPE_DIR)68k.asm
KN_Z80 ?= $(KN_TYPE_DIR)z80.asm
KN_Z80_LN ?= $(KN_TYPE_DIR)z80.ln


### outputs

KN_OUT_68K ?= $(KN_TYPE_DIR)68k.elf
KN_OUT_Z80 ?= $(KN_TYPE_DIR)z80.o
KN_OUT_Z80_LN ?= $(KN_TYPE_DIR)z80.bin


# for external use
KN_OUT := $(KN_OUT_68K)



### phony targets

.PHONY: kn-type-default kn-type-clean

kn-type-default:
	@echo "Please don't run make directly on this Makefile."
	@echo "Refer to the documentation for how to properly integrate it into your project."
	@exit 1

kn-type-clean:
	-$(RM) $(KN_OUT_68K) $(KN_OUT_Z80) $(KN_OUT_Z80_LN) $(KN_Z80_LN)




$(KN_OUT_Z80): $(KN_Z80) $(KN_OUT_MODULE_CONSTANTS)
	$(KN_WLAZ80) $(KN_WLAZ80FLAGS) -o $@ $<

# wlalink doesn't support include paths, so dynamically generate link file
$(KN_OUT_Z80_LN): $(KN_OUT_Z80)
	echo [objects] > $(KN_Z80_LN) && \
		echo $(KN_OUT_Z80) >> $(KN_Z80_LN) && \
		$(KN_WLALINK) $(KN_WLALINKFLAGS) $(KN_Z80_LN) $@

$(KN_OUT_68K): $(KN_68K) $(KN_OUT_Z80_LN) $(KN_OUT_COMPILED_MODULE) $(KN_OUT_GENERATED_DATA)
	$(KN_VASM) -Felf $(KN_VASMFLAGS) -o $@ $<


