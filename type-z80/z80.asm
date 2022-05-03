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



;;;;;;;;;;;;;;;;; player-related constants

.include "KN-MODULE-CONSTANTS.asm"

	
.define KN_CHANNELS 14

.define KN_SONG_SLOT_TRACKS 13

.define KN_TRACKS KN_SONG_SLOTS*KN_SONG_SLOT_TRACKS



;;;;;;;;;;;;;;;; ram structures

	;;; macro
.enum 0
mac_base dsb 3
mac_index db
mac_size .db
.ende


	;;; fm patch
.enum 0
fm_30 dsb 4
fm_40 dsb 4
fm_50 dsb 4
fm_60 dsb 4
fm_70 dsb 4
fm_80 dsb 4
fm_90 dsb 4
fm_b0 db
fm_b4 db
fm_size .db
.ende


	;;; track
.enum 7 desc
T_FLG_ON db
T_FLG_CUT db
T_FLG_KEYOFF db
T_FLG_NOTE_RESET db
T_FLG_FM_UPDATE db
.ende


	;;; this is indexed from -$80 to allow the full (ix+$xx) addressing mode range
.enum -$80
t_flags dsb 1
t_chn dsb 1

t_seq_base dsb 3
t_patt_ptr dsb 3

t_dur_cnt dsb 1
t_dur_save dsb 1

t_delay dsb 1
t_legato dsb 1
t_cut dsb 1
t_smpl_bank dsb 1
t_retrig dsb 1
t_retrig_cnt dsb 1
t_note dsb 1

;;;
t_instr dsw 1

t_vol dsw 1 ;this is a word because volume slide needs a fractional part- most routines should only access the upper byte
t_vol_slide dsb 1
t_pan dsb 1

t_pitch dsw 1
t_slide dsw 1
t_slide_target dsb 1
t_finetune dsb 1

t_arp dsb 1
t_arp_speed dsb 1
t_arp_cnt dsb 1
t_arp_phase dsb 1

t_vib dsb 1
t_vib_phase dsb 1
t_vib_fine dsb 1
t_vib_mode dsb 1


;;;
t_fm dsb fm_size

t_macros dsb mac_size*MACRO_SLOTS

t_macro_vol dsb 1
t_macro_arp dsb 1

t_psg_noise dsb 1

t_dac_mode dsb 1

	;0: no sample
	;$02xxxxxx: sample map, xxxxxx is the pointer (TODO: NOT IMPLEMENTED)
	;$03xxxxxx: pitchable single sample, xxxxxx is the pointer
t_instr_sample dsb 3
t_instr_sample_type db



t_end_offs .db
.ende

.define t_size t_end_offs+$80




	;;; song slot
.define SS_FLG_ON 7
.define SS_FLG_LOOP 6

.define SS_FLG_LINEAR_PITCH 3
.define SS_FLG_CONT_VIB 2
.define SS_FLG_PT_SLIDE 1
.define SS_FLG_PT_ARP 0


.enum 0
ss_flags dsb 1
ss_volume dsb 1

ss_song_id dsw 1
	
ss_order dsb 1
ss_patt_break dsb 1 ;$ff - no skip
ss_song_size dsb 1

ss_speed_cnt dsb 1
ss_speed1 dsb 1
ss_speed2 dsb 1

ss_row dsw 1
ss_patt_size dsw 1

ss_sample_map dsb 3

ss_size .db
.ende




;;;;;;;;;;;;;;; effect enum
.enum $c0
EFF_PORTAUP db
EFF_PORTADOWN db
EFF_NOTEUP db
EFF_NOTEDOWN db
EFF_TONEPORTA db
EFF_ARP db
EFF_VIBRATO db
EFF_PANNING db
EFF_SPEED1 db
EFF_SPEED2 db
EFF_VOLSLIDE db
EFF_PATTBREAK db
EFF_RETRIG db

EFF_ARPTICK db
EFF_VIBMODE db
EFF_VIBDEPTH db
EFF_FINETUNE db
EFF_LEGATO db
EFF_SMPLBANK db
EFF_CUT db
EFF_SYNC db

EFF_LFO db
EFF_FB db
EFF_TL1 db
EFF_TL2 db
EFF_TL3 db
EFF_TL4 db
EFF_MUL db
EFF_DAC db
EFF_AR1 db
EFF_AR2 db
EFF_AR3 db
EFF_AR4 db
EFF_AR db

EFF_NOISE db

EFF_SIZE .db
.ende


.define MAX_EFFECT EFF_SIZE-1




;;;;;;;;;;;;;;;; 68k-z80 communication variables

.define STACK_POINTER $1ed0
.enum STACK_POINTER
comm_end_index db
sync_flag db

;68k bus pointers
duration_tbl_base dsb 3
song_tbl_base dsb 3
instrument_tbl_base dsb 3
fm_tbl_base dsb 3
sample_map_tbl_base dsb 3
sample_tbl_base dsb 3

note_octave_tbl_base dsb 3
psg_period_tbl_base dsb 3
psg_volume_tbl_base dsb 3
vib_tbl_base dsb 3
fm_finetune_tbl_base dsb 3
psg_finetune_tbl_base dsb 3
semitune_tbl_base dsb 3
vib_scale_tbl_base dsb 3

.ende

.define comm_buf $1f00



;;;;;;;;;;;;;;;;; reset handler/rst routines/irq handler


	;reset stub
	.orga 0
	di
	ld sp,STACK_POINTER
	jp reset
	
	
	;read byte from banked pointer chl into a then step pointer
	.orga 8
getbyte:
	ld a,(hl)
	inc l
	ret nz
	inc h
	ret nz
	ld h,$80
	inc c
	;now we are at $10, another good rst location
	;sets bank to c
setbank:
	push af
	push hl
	ld hl,BANK
	ld a,c
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
	pop hl
	pop af
	ret
	
	
	
	;;;;;;;;;;;;;;;;;;;;;; irq
	.orga $38
	push af
	push bc
	push de
	push hl
	
	ex af,af'
	exx
	push af
	push bc
	push de
	push hl
	
	push ix
	push iy
	;;;;;;;;;;;;;
	
	
	ld hl,$1fff
	inc (hl)
	
	
	;;;;;;;;;;;;
	pop iy
	pop ix
	
	pop hl
	pop de
	pop bc
	pop af
	
	ex af,af'
	exx
	pop hl
	pop de
	pop bc
	pop af
	
	ei
	ret
	
	
	;;;;;;;;;;;;;;;;;;;;;;;;; reset
	
reset:
	
	;kill psg
	ld hl,PSG
	ld (hl),$9f
	ld (hl),$bf
	ld (hl),$df
	ld (hl),$ff
	
	
	;music ram was already zeroed out by the 68k, so we only need to init nonzero vars
	
	ld a,$ff
	ld b,10
	ld hl,k_prv_fm_track
-:	ld (hl),a
	inc hl
	djnz -
	
	
	ld iy,k_song_slots
	ld b,KN_SONG_SLOTS
	ld de,ss_size
-:	ld (iy+ss_song_id),a
	ld (iy+ss_song_id+1),a
	ld (iy+ss_patt_break),a
	add iy,de
	djnz -
	
	
	ld a,2
	ld (k_fm_prv_chn3_keyon),a
	
	ld a,8
	ld (k_fm_lfo),a
	
	
	im 1
	ei
	
	
	
	
	
-:
	jr -
	
	
	
	;;;;;;;;;;;;;;;;;;;;;;;;;; misc routines
	
	;add de to banked pointer chl
stepptr:
	add hl,de
	jr nc,+
	inc c
	ld de,$8000
	add hl,de
	jr nc,+
	inc c
	set 7,h
+:	jp setbank
	
	
	
	
	;bc * de = dehl
mulu:
	ld hl,0
	jr muls@mulbpos+1
	
	;signed bc * de = dehl
muls:
  ld hl,0

  bit 7,d
  jr z,@muldpos
  sbc hl,bc
@muldpos:

  or b
  jp p,@mulbpos
  sbc hl,de
@mulbpos:

  .rept 16
  add hl,hl
  rl e
  rl d
  jr nc,+
  add hl,bc
  jr nc,+
  inc de
+:
  .endr
  
  ret
	
	
	
	
	;convert 68k pointer bdl to banked pointer chl
ptrconv:
	ld h,d
	sla d
	rl b
	set 7,h
	ld c,b
	ret
	
	
	
	
	
	
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; private variables
.enum $0c00 ;this may need to be increased in the future

k_song_slots dsb ss_size*KN_SONG_SLOTS
k_tracks dsb t_size*KN_TRACKS


k_chn_track dsb KN_CHANNELS

k_prv_fm_track dsb 10

k_psg_prv_noise dsb 1

k_fm_prv_chn3_keyon dsb 1
k_fm_extd_chn3 dsb 1
k_fm_lfo dsb 1

.ende
	
	
	
	
	
	