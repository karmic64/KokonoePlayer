# KokonoePlayer

KokonoePlayer is a DefleMask/Furnace-compatible music routine for the Sega Genesis/Mega Drive. It supports almost all effects, both regular and extended channel 3 mode, samples, and a decent chunk of the Furnace compatibility flags. The main player logic runs on the 68000, with the Z80 being entirely relegated to sample playback. It was especially designed for games, and thus supports multiple "song slots" to allow simultaneous music and sound effects.

Unlike practically all existing Genesis sound drivers out there, this is not just a VGM player, it's a real player with real sequenced music data. This means the player will take more CPU time than a VGM player, but it can save a lot of space in your ROM. If CPU time is an issue, a Z80-only variant with decreased sample quality is planned, but not ready yet.

## Prerequisites

To use KokonoePlayer, you need the following:
* A Unix environment with `make` installed. If you're on Windows, [msys2](https://www.msys2.org/) is a good option.
* A native C compiler (preferably `gcc`), to compile the module converter and data generator.
* [vasm](http://sun.hasenbraten.de/vasm/), to assemble the 68000 part. When running `make`, use `SYNTAX=mot CPU=m68k`. The output executable should be named `vasmm68k_mot`.
* [WLA-DX](https://www.villehelin.com/wla.html), to assemble the Z80 part.
* A 68000 ELF-compatible linker, to link the KokonoePlayer output file into your ROM.

## Integrating KokonoePlayer into your build process

This section assumes you are using `make` to build your project.

First off, add the following to the top of your `Makefile`:
```make
KN_DIR := ...
KN_SONG_SLOTS := ...
KN_MODULES := ...

include $(KN_DIR)Makefile
```
Replace the `KN_DIR` value with the path to the root of the KokonoePlayer sources, **with** a trailing slash. Replace the `KN_SONG_SLOTS` value with the amount of song slots you wish to use. Replace the `KN_MODULES` value with the path to every module you wish to use.

If you are using C, find any rule that compiles individual source files into output files. Add the option `-I $(KN_DIR)`, allowing the compiler to locate the `kn.h` header file.

If you have a phony clean target, add `kn-clean` as a dependency.

Now find the rule in your `Makefile` that links the final ROM. Add `$(KN_OUT)` both as a dependency and an input file. Now, the next time you build your ROM, the KokonoePlayer .elf file will be built and linked with it.

## Using the KokonoePlayer functions

### In assembly language

KokonoePlayer has been designed to interface with C, thus the routines use the standard `gcc` C calling convention. For example, take the following function prototype:
```c
unsigned kn_func(void * the_pointer, unsigned the_int, unsigned short the_short)
```

You push the parameters on the stack in **reverse order**, `jsr` to the relevant label, then pull the parameters off. For the above function:
```m68k
	; push them on...
	pea the_short
	pea the_int
	pea the_pointer
	; call the function...
	jsr kn_func
	; then pull them off.
	lea 12(sp),sp
```
Parameters are ALWAYS pushed as longs, even if the actual sizes are smaller!

The routines themselves are guaranteed to preserve the values of `d2-d7/a2-a7`, but `d0-d1/a0-a1` are scratch registers and you should not rely on their values being preserved. Return values are passed in `d0`.

### In C

Simply `#include <kn.h>`, then call the functions as you would any other. Make sure you set `$(KN_DIR)` as a header file directory in your `Makefile`!

### Thread-safety precautions

KokonoePlayer functions are **not** thread-safe. You must ensure that only one is ever called at a time.

To request the Z80 bus (e.g. for DMA), it is OK to simply write directly to the bus request register. However, do not call `kn_reset` or `kn_play` while the Z80 bus must be held, because they will release the bus.

## KokonoePlayer function reference

### kn_reset
```c
void kn_reset();
```
Resets the player variables to a known state, and uploads the Z80 code. You **must** call this in your initial reset code, before `kn_play` ever has a chance to execute.

### kn_init
```c
void kn_init(unsigned song_slot, unsigned song_id);
```
Initializes song `song_id` playback in the song slot `song_slot`. Song IDs are assigned incrementally starting from 0, in the order you gave when assigning the value of `KN_MODULES`.

The song ID parameter also determines whether a song should loop or not. OR the parameter with `KN_NO_LOOP` if not, or `KN_LOOP` if so.

Higher-numbered song slots are higher priority. For example, you could have 4 song slots, 0 for music, 1 and 2 for sound effects, and 3 for music cues that overtake all other sound (for example, the extra life jingle in Sonic).

### kn_play
```c
void kn_play();
```
Run this routine once per VBlank to play music.

### kn_volume
```c
void kn_volume(unsigned song_slot, unsigned volume);
```
Sets the global volume of song slot `song_slot` to `volume`. The value ranges from $00 (dead silent) to $ff (full blast). The value is reset to $ff whenever `kn_init` is called.

### kn_seek
```c
void kn_seek(unsigned song_slot, unsigned order);
```
Seeks playback of song slot `song_slot` to order `order`.

### kn_pause
```c
void kn_pause(unsigned song_slot);
```
Pauses playback of song slot `song_slot`.

### kn_resume
```c
void kn_resume(unsigned song_slot);
```
Resumes playback of song slot `song_slot`, if it was paused by `kn_pause`.

### kn_stop
```c
void kn_stop(unsigned song_slot);
```
Stops playback of song slot `song_slot`.

### kn_sync
```c
unsigned kn_sync();
```
Returns the current sync flag value, and then resets it to 0. The sync value is set by effect `EExx`, which has no inbuilt effect but you can use it to sync ingame events to the music.

## Notice on compatibility

Old (and possibly new) DefleMask modules ARE NOT supported. If the conversion of a module fails, and you get a message that the version is not 24, try resaving your module with v0.12.1 (the last free version).

At the time of writing, the latest Furnace module version was 83. If the people responsible ever introduce any breaking changes, please contact me.

The following effects are not supported:
* `7xy`, tremolo
* `EFxx`, "global fine tune"

Only the following Furnace compatibility flags are supported:
* Register/linear pitch mode
* Continuous vibrato mode
* Protracker-style slides
* Protracker-style vibrato

## Disclaimer

All the modules in this repository are used for testing purposes only, and are taken unmodified from the trackers' demo song libraries. They are not mine.

The `DMF_SPECS.txt` document contains the official DefleMask module specifications. It is publicly available and written by Delek, and put here for reference purposes only.