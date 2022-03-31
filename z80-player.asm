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


.define STACK_POINTER $1ff0

	.enum STACK_POINTER
start_flag db
cur_reg db

start_lo db
start_hi db
start_bank db

loop_lo db
loop_hi db
loop_bank db

rate_lo db
rate_hi db
	.ende


	.orga 0
	di
	ld sp,STACK_POINTER
	jp reset
	
	
	.orga 8
write_reg:
	push hl
	ld hl,FM1REG
	ld (cur_reg),a
	ld (hl),a
@wait:
	bit 7,(hl)
	jr nz,@wait
	inc l
	ld (hl),b
	pop hl
	ret
	
	
	
	
	.orga $18
	;trashes a
set_bank:
	exx
	ld hl,BANK
	ld (hl),a
	rrca
	ld (hl),a
	rrca
	ld (hl),a
	rrca
	ld (hl),a
	rrca
	ld (hl),a
	rrca
	ld (hl),a
	rrca
	ld (hl),a
	rrca
	ld (hl),a
	ld (hl),0
	exx
	ret
	
	
	
	
reset:
	
	
kill_sample:
	ld a,$2b
	ld b,0
	rst write_reg
	
	
	;;; idle loop. right now we are waiting for the 68k to give us a command
	ld hl,start_flag
idle_loop:
	ld a,(hl)
	or a
	jr z,idle_loop
	
	;;; got command
do_command:
	ld hl,start_flag
	ld (hl),0
	
	rlca
	jr c,kill_sample ;$80+, kill sample and disable dac mode
	
	;otherwise start the sample
	ld a,$2b ;enable dac
	ld b,$80
	rst write_reg
	ld a,$2a ;set register to dac
	ld (cur_reg),a
	ld (FM1REG),a
	
	
	ld a,(start_bank) ;bank in b
	ld b,a
	rst set_bank
	
	ld hl,(start_lo) ;address in hl
	
	ld c,0 ;rate accumulator in c
	ld a,(rate_hi) ;rate hi-byte in de
	ld e,a
	ld d,0
	
	
	
	;;; now we are ready to hammer samples into the dac
sample_loop:
	;if there is a command, do it
	ld a,(start_flag)
	or a
	jr nz,do_command
	
	;otherwise play a sample
	ld a,(hl)
	or a
	jr z,sample_end ;is the sample over?
	ld (FM1DATA),a
	
	;step the pointer
	ld a,(rate_lo)
	add a,c
	ld c,a
	adc hl,de
	jp nc,sample_loop
	
	;if needed, step the bank
	inc b
	ld a,b
	rst set_bank
	set 7,h
	
	jp sample_loop
	
	
sample_end:
	ld a,(loop_hi) ;does the sample loop?
	or a
	jr z,kill_sample ;if not, go back to idling
	
	;otherwise loop
	ld a,(loop_bank)
	ld b,a
	rst set_bank
	ld hl,(loop_lo)
	
	jp sample_loop
	
	
	