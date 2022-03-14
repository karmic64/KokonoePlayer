.memorymap
defaultslot 0
slotsize $2000
slot 0 $0000
.endme

.rombankmap
bankstotal 1
banksize $2000
banks 1
.endro


.define FM1REG $4000
.define FM1DATA $4001
.define FM2REG $4002
.define FM2DATA $4003

.define BANK $6000

.define PSG $7f11


.macro waitfm
-:
	bit 7,(hl)
	jr nz,-
.endm


	.orga 0
	di
	im 1
	ld sp,$2000
	jr reset
	
	
	
	
	
	.orga $40
reset:
	
	
	
	
	
	
	
mainloop:
	
	jr mainloop
	
	