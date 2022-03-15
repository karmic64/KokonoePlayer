This will eventually be a DefleMask/FurnaceTracker-compatible music routine for the Sega Genesis, right now there is only some documents and junk code.

You need [WLA-DX](https://www.villehelin.com/wla.html) to assemble the Z80 part and [vasm](http://sun.hasenbraten.de/vasm/) (m68k cpu, mot syntax) to assemble the 68k part.

## Notice on compatibility

Old (and possibly new) DefleMask modules ARE NOT supported. If the conversion fails, and you get a message that the version is not 24, try resaving your module with v0.12.1 (the last free version).

At the time of writing, the latest Furnace module version was 65. If the people responsible ever introduce any breaking changes, please contact me.

## Disclaimer

All the modules in this repository are used for testing purposes only, and are taken unmodified from the trackers' demo song libraries. They are not mine.

The `DMF_SPECS.txt` document contains the official DefleMask module specifications. It is publicly available and written by Delek, and put here for reference purposes only.