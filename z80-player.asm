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


.define STACK_POINTER $1800

	.enum STACK_POINTER
part1_reg_buf dsb $100
part1_val_buf dsb $100

part2_reg_buf dsb $100
part2_val_buf dsb $100

part1_buf_end db
part2_buf_end db
	.ende


	.orga 0
	di
	im 1
	ld sp,STACK_POINTER
	jr reset
	
	
	
	
	
	.orga $40
reset:
	
	
	
	
	ld bc,part1_reg_buf
	ld de,part2_reg_buf
	
mainloop:
	ld hl,part1_buf_end
	jr @part1_check
@part1_loop:
	ld a,(bc)
	ld (FM1REG),a
	inc b
	ld a,(bc)
	ld (FM1DATA),a
	dec b
	inc c
	nop
	nop
	nop
@part1_check:
	ld a,c
	cp (hl)
	jr nz,@part1_loop
	
	ld hl,part2_buf_end
	jr @part2_check
@part2_loop:
	ld a,(de)
	inc d
	cp $30
	jr c,@part2_long
	ld (FM2REG),a
	ld a,(de)
	ld (FM2DATA),a
@part2_return:
	dec d
	inc e
	nop
	nop
	nop
@part2_check:
	ld a,e
	cp (hl)
	jr nz,@part2_loop
	
	jr mainloop
	
	
@part2_long:
	ld (FM1REG),a
	ld a,(de)
	ld (FM1DATA),a
	jr @part2_return
	
	
	
	