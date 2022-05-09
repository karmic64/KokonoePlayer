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
.enum 8 desc
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
t_patt_dur_index dsb 1
t_patt_base_note dsb 1

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

t_vol dsb 1 ;this is a word because volume slide needs a fractional part- most routines should only access the upper byte
t_vol_frac dsb 1
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





;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; private variables
.enum $1400 ;this may need to be increased in the future


k_temp dsb 8 ;general-purpose temporary storage
k_cur_track db
k_cur_track_ptr dw
k_cur_song_slot db
k_cur_song_slot_ptr dw


k_frame_cnt db
k_cur_frame db


k_comm_index db



k_sample_active dsb 1
k_sample_ptr dsb 3
k_sample_rate dsb 2



k_song_slots dsb ss_size*KN_SONG_SLOTS
k_tracks_real dsb t_size*KN_TRACKS


k_chn_track dsb KN_CHANNELS

k_prv_fm_track dsb 10

k_psg_prv_noise dsb 1

k_fm_prv_chn3_keyon dsb 1
k_fm_extd_chn3 dsb 1
k_fm_lfo dsb 1

.ende


.define k_tracks k_tracks_real+$80






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
	im 1
	ld sp,STACK_POINTER
	jr reset
	
	
	;read byte from banked pointer chl into a then step pointer
	.orga 8
get_byte:
	ld a,(hl)
	inc l
	ret nz
	inc h
	ret nz
	ld h,$80
	inc c
	;now we are at $10, another good rst location
	;sets bank to c
set_bank:
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
	jr set_bank_exit
	
	
	
	;write byte a to ym register b
	;(assumes hl' is $4000, bc' is the register and de' is the data)
	.orga $28
write_fm:
	ex af,af'
	ld a,b
	exx
	ld (bc),a
	
-:	bit 7,(hl)
	jr nz,-
	
	ex af,af'
	ld (de),a
	exx
	ret
	
	
	
	
	;;;;;;;;;;;;;;;;;;;;;; irq
	.orga $38
	push af
	push hl
	
	ld hl,k_frame_cnt
	inc (hl)
	
	;wait until irq is unasserted
	ld hl,$7f08
	ld a,$e1
-:	cp (hl)
	jr nc,-
	
	pop hl
	pop af
	
	ei
	ret
	
	
	
	;;;;;;
set_bank_exit:
	ld (hl),0
	pop hl
	pop af
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
	
	
	ei
	
	
	
	
	
return_main_loop:
	;;; wait for next frame
	ld ix,k_frame_cnt
	
	ld hl,0
	
	ld a,(ix+1)
-:	inc hl
	cp (ix+0)
	jr z,-
	ld (0),hl
	
	inc (ix+1)
	
	dec l
	ld a,l
	or h
	jr nz,+
	ld hl,2
	inc (hl)	
+:	
	
	
	;;; handle 68k commands
	
	ld h,>comm_buf
	ld a,(k_comm_index)
	ld l,a
	ld a,(comm_end_index)
	cp l
	jr z,@no_command
	ld b,a
	
@command_loop:
	ld ix,@command_tbl
	ld e,(hl)
	inc l
	ld d,0
	add ix,de
	ld de,@next_command
	push de
	jp (ix)
	
@command_tbl:
	jr @cmd_init
	jr @cmd_volume
	jr @cmd_seek
	jr @cmd_pause
	jr @cmd_resume
	jr @cmd_stop
	
@get_song_slot:
	ld a,(hl)
	inc l
	push hl
	call set_song_slot
	pop hl
	ret
	
@cmd_init:
	ld a,(hl)
	inc l
	ld e,(hl)
	inc l
	ld d,(hl)
	inc l
	push bc
	push hl
	call kn_init
	pop hl
	pop bc
	ret
	
@cmd_volume:
	call @get_song_slot
	ld a,(hl)
	inc l
	ld (iy+ss_volume),a
	ret
	
@cmd_seek:
	call @get_song_slot
	ld a,(hl)
	inc l
	ld (iy+ss_patt_break),a
	ret
	
@cmd_pause:
	call @get_song_slot
	res SS_FLG_ON,(iy+ss_flags)
	ret
	
@cmd_resume:
	call @get_song_slot
	bit 7,(iy+ss_song_id+1)
	ret nz
	set SS_FLG_ON,(iy+ss_flags)
	ret
	
@cmd_stop:
	call @get_song_slot
	ld (iy+ss_flags),0
	ld a,$ff
	ld (iy+ss_song_id),a
	ld (iy+ss_song_id+1),a
	ret
	
	
@next_command:
	ld a,l
	cp b
	jr nz,@command_loop
	ld (k_comm_index),a
	
@no_command:
	
	
	
	
	
	;;; play music
	call kn_play
	
	
	jp return_main_loop
	
	
	
	;;;;;;;;;;;;;;;;;;;;;;;;;; misc routines
	
step_ptr_e_ahl:
	ld d,0
step_ptr_ahl:
	ld c,a
	;add de to banked pointer chl, then set the bank
step_ptr:
	add hl,de
	jr nc,+
	inc c
	ld de,$8000
	add hl,de
	jr nc,+
	inc c
	set 7,h
+:	jp set_bank
	
	
	
	
	
	
	
	;h * e = hl
mulu_h_e:
	ld d,0
	sla h
	sbc a,a
	and e
	ld l,a
	
	.rept 7
	add hl,hl
	jr nc,+
	add hl,de
+:	.endr
	
	ret
	
	
	
	
	;de * a = ahl
mulu_de_a:
	ld c,0
	ld h,c
	ld l,h
	
	add a,a
	jr nc,+
	ld h,d
	ld l,e
+:
	
	.rept 7
	add hl,hl
	rla
	jr nc,+
	add hl,de
	adc a,c
+:	.endr
	
	ret
	
	
	;signed bc * de = dehl
muls_bc_de:
	xor a
	ld h,a
	ld l,a
	
	bit 7,d
	jr z,+
	sbc hl,bc
+:	
	or b
	jp p,+
	sbc hl,de
+:	
	
@main:
	ld a,16
-:	add hl,hl
	rl e
	rl d
	jr nc,+
	add hl,bc
	jr nc,+
	inc de
+:	dec a
	jr nz,-
	
	ret
	
	
	;bc * de = dehl
mulu_bc_de:
	ld hl,0
	jr muls_bc_de@main
	
	
	
	
	
	
	
	
	
	
	;read 68k pointer indirect from (banked ahl)+(de*4)+1
indexed_read_68k_ptr:
	ex de,hl
	add hl,hl
	add hl,hl
	inc hl
	ex de,hl
	call step_ptr_ahl
	
	;read 68k pointer from banked pointer chl, convert into chl, then set bank
read_68k_ptr:
	rst get_byte
	ld b,a
	rst get_byte
	ld d,a
	rst get_byte
	ld l,a
	ld a,d
	rlca
	rl b
	set 7,d
	ld h,d
	ld c,b
	jp set_bank
	
	
	
	
	;id in a
set_track:
	ld (k_cur_track),a
	ld de,track_ptr_tbl
load_track_from_table:
	add a,a
	ld l,a
	ld h,0
	add hl,de
	ld a,(hl)
	ld ixl,a
	inc hl
	ld a,(hl)
	ld ixh,a
	ld (k_cur_track_ptr),ix
	ret
	
	
	;id in a
set_song_slot:
	ld (k_cur_song_slot),a
	ld de,song_slot_ptr_tbl
load_song_slot_from_table:
	add a,a
	ld l,a
	ld h,0
	add hl,de
	ld a,(hl)
	ld iyl,a
	inc hl
	ld a,(hl)
	ld iyh,a
	ld (k_cur_song_slot_ptr),iy
	ret
	
	
	
	
	;id in variable
get_track_song_slot:
	ld a,(k_cur_track)
	ld de,kn_track_song_slot_ptr_tbl
	jr load_song_slot_from_table
	
	
	;id in variable
get_song_slot_track:
	ld a,(k_cur_song_slot)
	ld de,kn_song_slot_track_ptr_tbl
	jr load_track_from_table
	
	
	
	
	
	
	
	
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; init routine
	; song slot in a, song id in de (loop flag in bit 15)
kn_init:
	;;;; get track and song slot
	exx
	call set_song_slot
	call get_song_slot_track
	exx
	
	;;;; set song id in slot
	push de
	res 7,d
	ld (iy+ss_song_id),e
	ld (iy+ss_song_id+1),d
	
	;;;; get song base
	ld hl,(song_tbl_base)
	ld a,(song_tbl_base+2)
	call indexed_read_68k_ptr
	
	;;;; setup song slot
	rst get_byte ;flags
	pop de
	bit 7,d
	jr z,+
	set SS_FLG_LOOP,a
+:	ld (iy+ss_flags),a
	
	rst get_byte ;speeds
	ld (iy+ss_speed1),a
	rst get_byte
	ld (iy+ss_speed2),a
	dec a
	ld (iy+ss_speed_cnt),a
	
	rst get_byte ;pattern size
	rst get_byte
	ld (iy+ss_patt_size+1),a
	rst get_byte
	ld (iy+ss_patt_size),a
	
	rst get_byte ;sample map
	ld d,a
	rst get_byte
	ld e,a
	push bc
	push hl
	ld hl,(sample_map_tbl_base)
	ld a,(sample_map_tbl_base+2)
	call indexed_read_68k_ptr
	ld (iy+ss_sample_map),l
	ld (iy+ss_sample_map+1),h
	ld (iy+ss_sample_map+2),c
	pop hl
	pop bc
	rst set_bank
	
	rst get_byte ;song size
	ld (iy+ss_song_size),a
	
	ld (iy+ss_order),0 ;misc init
	ld a,$ff
	ld (iy+ss_volume),a
	ld (iy+ss_row),a
	ld (iy+ss_row+1),a
	ld (iy+ss_patt_break),a
	
	
	;;;; set up tracks
	rst get_byte ;channel count
	push af
	ld (k_temp),a
	
	;get the start address of the sequence (currently we point to the channel arrangement)
	push bc
	push hl
	
	;if the amount of channels is odd, realign the chn.arr. step count
	ld e,a
	ld d,0
	
	rrca
	jr nc,+
	inc e
+:	
	
	;step to sequence
	call step_ptr
	ld (k_temp+2),hl
	ld a,c
	ld (k_temp+4),a
	
	;get sequence size (song size * 4)
	ld l,(iy+ss_song_size)
	ld h,0
	add hl,hl
	add hl,hl
	ld (k_temp+5),hl
	
	pop hl ;get pointer to channel arrangement back
	pop bc
	rst set_bank
	
	
	;;; main track init loop
@track_init_loop:

	;; first, clear variables
	ld a,ixl ;adjust pointer back -$80
	sub $80
	ld e,a
	ld a,ixh
	sbc 0
	ld d,a
	ld b,t_size
	xor a
-:	ld (de),a
	inc de
	djnz -
	
	
	;; init pattern player
	ld (ix+t_flags), (1 << T_FLG_ON) | (1 << T_FLG_CUT) | (1 << T_FLG_KEYOFF) | (1 << T_FLG_FM_UPDATE)
	rst get_byte
	ld (ix+t_chn),a
	
	push bc ;get sequence base
	push hl
	ld hl,(k_temp+2)
	ld a,(k_temp+4)
	ld de,(k_temp+5)
	ld (ix+t_seq_base),l
	ld (ix+t_seq_base+1),h
	ld (ix+t_seq_base+2),a
	call step_ptr ;and step
	ld (k_temp+2),hl
	ld a,c
	ld (k_temp+4),a
	pop hl
	pop bc
	rst set_bank
	
	inc (ix+t_dur_cnt)
	
	;; init instruments/effects
	dec (ix+t_instr)
	dec (ix+t_instr+1)
	dec (ix+t_slide_target)
	ld (ix+t_pan),$c0
	inc (ix+t_arp_speed)
	ld (ix+t_vib_fine),$0f
	
	ld (ix+t_psg_noise),3
	
	;initialize fm patch to TL $7f/RR $f/ D1L $f
	;this is to avoid any init noise
	dec (ix+t_fm+fm_40)
	dec (ix+t_fm+fm_40+1)
	dec (ix+t_fm+fm_40+2)
	dec (ix+t_fm+fm_40+3)
	dec (ix+t_fm+fm_80)
	dec (ix+t_fm+fm_80+1)
	dec (ix+t_fm+fm_80+2)
	dec (ix+t_fm+fm_80+3)
	
	;depending on channel type, init volume
	ld b,$7f
	ld a,(ix+t_chn)
	cp 6+4
	jr c,+
	ld b,$0f
+:	ld (ix+t_vol),b
	
	
	
	;; next
	ld de,t_size
	add ix,de
	
	ld a,(k_temp)
	dec a
	ld (k_temp),a
	jp nz,@track_init_loop
	
	
	
	
	
	
	;;;; turn off any unused tracks
	pop bc ;pop channel count back off (in b)
	ld a,KN_SONG_SLOT_TRACKS
	sub b
	ret z
	
	ld de,t_size
	ld b,a
-:	ld (ix+t_flags),0
	add ix,de
	djnz -
	
	
	ret
	
	
	
	
	
	
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; play routine
	
kn_play:
	
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	;; handle song slots
	ld a,KN_SONG_SLOTS-1
	ld iy,k_song_slots + (ss_size*(KN_SONG_SLOTS-1))
@song_slot_loop:
	ld (k_cur_song_slot),a
	
	bit SS_FLG_ON,(iy+ss_flags)
	jp z,@@next_song_slot
	
	;;is the row over?
	
	;get row speed in (hl)
	ld d,iyh
	ld e,iyl
	ld hl,ss_speed1
	add hl,de
	bit 0,(iy+ss_row)
	jr z,+
	inc hl
+:	;if speedcnt+=1 >= speed, row is over
	ld a,(iy+ss_speed_cnt)
	inc a
	cp (hl)
	jp c,@@no_next_row
	ld (iy+ss_speed_cnt),0
	
	
	;; row is over, check for a pattern break
	ld a,(iy+ss_patt_break)
	cp $ff
	jr z,@@no_patt_break
	
	ld (iy+ss_patt_break),$ff
	jr @@song_set_order
	
@@no_patt_break:
	;; no pattern break, check for the end of the pattern
	;; when row+=1 >= patt size
	ld l,(iy+ss_row)
	ld h,(iy+ss_row+1)
	inc hl
	ld a,l
	cp (iy+ss_patt_size)
	ld a,h
	sbc (iy+ss_patt_size+1)
	jr c,@@no_next_pattern
	
	ld a,(iy+ss_order)
	inc a
	cp (iy+ss_song_size) ;song over?
	jr c,@@song_set_order
	xor a
	
@@song_set_order:
	;right now the new order number is in A
	ld (iy+ss_row),0
	ld (iy+ss_row+1),0
	
	;put the result of comparing old order - new order in the upper bit of c
	ld c,a
	ld a,(iy+ss_order)
	cp c
	ld (iy+ss_order),c ;then save it
	rr c
	
	
	;;prepare all tracks for the next pattern
	call get_song_slot_track
	ld b,KN_SONG_SLOT_TRACKS
@@track_reset_loop:
	bit T_FLG_ON,(ix+t_flags)
	jr z,@@next_track_reset
	
	;on z80, the pattern reader itself resets the pattern index
	ld (ix+t_dur_cnt),1
	
	;we need to do loop detection.
	;a loop is defined when the new order <= old order
	;this bit is set when there is a carry from old order - new order
	;or, if old order < new order
	bit 7,c
	jr nz,@@next_track_reset ;old < new, this is not a loop
	
	;if we should not loop, stop the entire song
	bit SS_FLG_LOOP,(iy+ss_flags)
	jr nz,@@yes_loop
	xor a
	ld (iy+ss_flags),a
	dec a
	ld (iy+ss_song_id),a
	ld (iy+ss_song_id+1),a
	jr @@next_song_slot
	
	
@@yes_loop:
	;dumb way to not have to save the song state on loop
	set T_FLG_CUT,(ix+t_flags)
	xor a
	ld (ix+t_slide),a
	ld (ix+t_slide+1),a
	ld (ix+t_vol_slide),a
	
	ld d,$7f
	ld a,(ix+t_chn)
	cp 6+4
	jr c,+
	ld d,$0f
+:	ld (ix+t_vol),d
	
	
	
@@next_track_reset:
	ld de,t_size
	add ix,de
	djnz @@track_reset_loop
	
	
	
	
	jr @@next_song_slot
	
	
@@no_next_pattern:
	ld (iy+ss_row),l
	ld (iy+ss_row+1),h
	jr @@next_song_slot
	
@@no_next_row:
	ld (iy+ss_speed_cnt),a
	
@@next_song_slot:
	ld de,-ss_size
	add iy,de
	
	ld a,(k_cur_song_slot)
	dec a
	jp p,@song_slot_loop
	
	
	
	
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	;; clear out used channels
	
	ld hl,k_chn_track
	ld b,KN_CHANNELS
	ld a,$ff
-:	ld (hl),a
	inc hl
	djnz -
	
	
	
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	;; main track loop
	
	xor a
	ld ix,k_tracks
@trackloop:
	ld (k_cur_track),a
	ld (k_cur_track_ptr),ix
	
	bit T_FLG_ON,(ix+t_flags)
	jp z,@@notrack
	
	call get_track_song_slot
	bit SS_FLG_ON,(iy+ss_flags)
	jp z,@@notrack
	
	
	;;;;;;;;;;;;;;;;;;;;;;;;;;;
	;; check pattern timers
	ld a,(ix+t_delay)
	or a
	jr z,@@nowaitdelay
	cp (iy+ss_speed_cnt)
	jp nz,@@nonewsongdata
	ld (ix+t_delay),0
	jr @@dosongdata
	
@@nowaitdelay:
	;if the speedcnt is 0, that means it overflowed and we should get a new row
	ld a,(iy+ss_speed_cnt)
	or a
	jp nz,@@nonewsongdata
	
	;A is 0, clear some effects on new row
	ld (ix+t_retrig),a
	ld (ix+t_cut),a
	
	
	;has the duration expired?
	dec (ix+t_dur_cnt)
	jp nz,@@nonewsongdata
	
	
	
@@dosongdata:
	;;;;;;;;;;;;;;;;;;;;;;
	;; get banked pattern pointer in chl
	; if the row is 0, get it from the sequence table
	; otherwise look at the pointer variable
	ld a,(iy+ss_row)
	or (iy+ss_row+1)
	jr nz,@@oldpatt
	
	;get from sequence table
	ld l,(ix+t_seq_base)
	ld h,(ix+t_seq_base+1)
	ld a,(ix+t_seq_base+2)
	
	ld e,(iy+ss_order)
	ld d,0
	
	call indexed_read_68k_ptr
	
	rst get_byte
	ld (ix+t_patt_dur_index),a
	rst get_byte
	ld (ix+t_patt_base_note),a
	
	jr @@gotpatt
	
@@oldpatt:
	ld l,(ix+t_patt_ptr)
	ld h,(ix+t_patt_ptr+1)
	ld c,(ix+t_patt_ptr+2)
	rst set_bank
	
@@gotpatt:
	
	
	;;;;;;;;;;;;;;;;;;;;;;;;;
	;; read pattern data
@@patt_read:
	rst get_byte
	
	;;;;;; delay
	cp $fe
	jr nz,@@@nodelay
	
	rst get_byte ;delay time
	
	;get current row speed in (hl)
	push hl
	ld d,iyh
	ld e,iyl
	ld hl,ss_speed1
	add hl,de
	bit 0,(iy+ss_row)
	jr z,+
	inc hl
+:	;if delay rate >= row speed, ignore it
	cp (hl)
	pop hl
	jr nc,@@@delaytoobig
	ld (ix+t_delay),a
	jp @@aftersongdata
	
@@@delaytoobig:
	rst get_byte
@@@nodelay:
	
	
	;;;;;; instrument change
	cp $fc
	jp c,@@@noinstr
	
	; get instrument number in de
	ld d,0
	jr z,@@@shortinstr
	rst get_byte
	ld d,a
@@@shortinstr:
	rst get_byte
	ld e,a
	
	; don't set the same instrument twice
	cp (ix+t_instr)
	jr nz,@@@setinstr
	ld a,d
	cp (ix+t_instr+1)
	jp z,@@@sameinstr
	
	
@@@setinstr:
	ld (ix+t_instr),e
	ld (ix+t_instr+1),d
	
	; get instrument pointer
	push bc
	push hl
	
	ld hl,(instrument_tbl_base)
	ld a,(instrument_tbl_base+2)
	call indexed_read_68k_ptr
	
	;read instrument properties
	rst get_byte ;type
	ld (k_temp),a
	rst get_byte ;macro count
	
	;; set up macros
	.if MACRO_SLOTS > 0
	ld iy,k_temp+1
	ld (iy+0),a
	
	;get pointer to macros in ix
	ld de,t_macros
	add ix,de
	
	xor a
@@@macroloop:
	ld (k_temp+2),a ;current macro
	
	cp (iy+0) ;if current macro >= macro count, just clear
	jr nc,@@@@clear
	;otherwise get the banked pointer
	
	rst get_byte ;discard unused address byte
	rst get_byte ;3rd byte
	ld d,a
	rst get_byte ;2nd byte
	ld e,a
	rst get_byte ;lsb
	ld (ix+mac_base),a
	ld a,e
	rla
	rl d
	set 7,e
	ld (ix+mac_base+1),e
	ld (ix+mac_base+2),d
	
	jr @@@@next
	
@@@@clear:
	xor a
	ld (ix+mac_base),a
	ld (ix+mac_base+1),a
	ld (ix+mac_base+2),a
@@@@next:
	xor a
	ld (ix+mac_index),a
	
	
	ld de,mac_size
	add ix,de
	
	ld a,(k_temp+2)
	inc a
	cp MACRO_SLOTS
	jr c,@@@macroloop
	
	ld ix,(k_cur_track_ptr)
	ld iy,(k_cur_song_slot_ptr)
	
	.endif
	
	
	;read any extra data depending on the type
	ld a,(k_temp)
	cp 2
	jr c,@@@notsampleinstr
	ld (ix+t_instr_sample_type),a
	
	push bc
	push hl
	
	jr nz,@@@melosampleinstr
	
	;TODO: mapped sample instrument
	
	jr @@@setsampleinstr
	
@@@melosampleinstr:
	;get sample id in de
	rst get_byte
	ld d,a
	rst get_byte
	ld e,a
	
	ld hl,(sample_tbl_base)
	ld a,(sample_tbl_base+2)
	call indexed_read_68k_ptr
	
@@@setsampleinstr:
	ld (ix+t_instr_sample),l
	ld (ix+t_instr_sample+1),h
	ld (ix+t_instr_sample+2),c
	
	pop hl
	pop bc
	rst set_bank
	
	jr @@@afterinstr
	
	
	
@@@notsampleinstr:
	
	or a ;fm instrument?
	jr z,@@@notfminstr
	
	;push bc
	;push hl
	;get sample id in de
	rst get_byte
	ld d,a
	rst get_byte
	ld e,a
	
	ld hl,(fm_tbl_base)
	ld a,(fm_tbl_base+2)
	call indexed_read_68k_ptr
	
	push hl
	ld d,ixh
	ld e,ixl
	ld hl,t_fm
	add hl,de
	ex de,hl
	pop hl
	
	ld b,30
-:	rst get_byte
	ld (de),a
	inc de
	djnz -
	
	set T_FLG_FM_UPDATE,(ix+t_flags)
	
	;pop hl
	;pop bc
	
@@@notfminstr:
	
	xor a
	ld (ix+t_instr_sample),a
	ld (ix+t_instr_sample+1),a
	ld (ix+t_instr_sample+2),a
	ld (ix+t_instr_sample_type),a
	
	
	
@@@afterinstr:
	pop hl
	pop bc
	rst set_bank
	
@@@sameinstr:
	rst get_byte
@@@noinstr:
	
	
	;;;;;;;;;;; volume
	cp $fb
	jr nz,@@@novol
	rst get_byte
	ld (ix+t_vol),a
	rst get_byte
@@@novol:
	
	
	;;;;;;;;;;;;; effects
	
	;; 20xx psg noise
	cp EFF_NOISE
	jr nz,+
	rst get_byte
	ld (ix+t_psg_noise),a
	rst get_byte
+:	
	
	;; 19xx global AR
	cp EFF_AR
	jr nz,+
	
	rst get_byte
	push bc
	ld c,a
	ld de,t_fm+fm_50
	add ix,de
	
	ld b,4
-:	ld a,(ix+0)
	and $e0
	or c
	ld (ix+0),a
	inc ix
	djnz -
	
	pop bc
	ld ix,(k_cur_track_ptr)
	set T_FLG_FM_UPDATE,(ix+t_flags)
	
	rst get_byte
+:	
	
	;; 1Axx-1Dxx operator AR
	ld de,t_fm+fm_50+3
	add ix,de
	ld b,EFF_AR4
-:	cp b
	jr nz,+
	
	rst get_byte
	ld e,a
	ld a,(ix+0)
	and $e0
	or e
	ld (ix+0),a
	set T_FLG_FM_UPDATE,(ix+t_flags)
	
	rst get_byte
	
+:	dec ix
	dec b
	ld d,a
	ld a,b
	cp EFF_AR1
	ld a,d
	jr nc,-
	
	ld ix,(k_cur_track_ptr)
	
	
	;; 17xx dac mode
	cp EFF_DAC
	jr nz,+
	rst get_byte
	ld (ix+t_dac_mode),a
	rst get_byte
+:	
	
	
	;; 16xy mult
	cp EFF_MUL
	jr nz,+
	
	rst get_byte
	
	push af
	push hl
	rrca
	rrca
	rrca
	rrca
	and $0f
	ld l,a
	ld h,0
	ld de,t_fm+fm_30
	add hl,de
	ex de,hl
	add ix,de
	pop hl
	pop af
	and $0f
	ld b,a
	
	ld a,(ix+0)
	and $70
	or b
	ld (ix+0),a
	
	ld ix,(k_cur_track_ptr)
	set T_FLG_FM_UPDATE,(ix+t_flags)
	
	rst get_byte
+:	
	
	;; 1Axx-1Dxx operator TL
	ld de,t_fm+fm_40+3
	add ix,de
	ld b,EFF_TL4
-:	cp b
	jr nz,+
	
	rst get_byte
	ld (ix+0),a
	;set T_FLG_FM_UPDATE,(ix+t_flags) ;tl is ALWAYS updated
	
	rst get_byte
	
+:	dec ix
	dec b
	ld d,a
	ld a,b
	cp EFF_TL1
	ld a,d
	jr nc,-
	
	ld ix,(k_cur_track_ptr)
	
	
	
	;; 11xx feedback
	cp EFF_FB
	jr nz,+
	
	rst get_byte
	rlca
	rlca
	rlca
	ld d,a
	
	ld a,(ix+t_fm+fm_b0)
	and $c7
	or d
	ld (ix+t_fm+fm_b0),a
	set T_FLG_FM_UPDATE,(ix+t_flags)
	
	rst get_byte
+:	
	
	;; 10xx lfo
	cp EFF_LFO
	jr nz,+
	rst get_byte
	ld (k_fm_lfo),a
	set T_FLG_FM_UPDATE,(ix+t_flags)
	rst get_byte
+:	
	
	
	;;;;;;
	
	;; EExx sync
	cp EFF_SYNC
	jr nz,+
	rst get_byte
	ld (sync_flag),a
	rst get_byte
+:	
	;; ECxx cut
	cp EFF_CUT
	jr nz,+
	rst get_byte
	ld (ix+t_cut),a
	rst get_byte
+:	
	;; EBxx sample bank
	cp EFF_SMPLBANK
	jr nz,+
	rst get_byte
	ld (ix+t_smpl_bank),a
	rst get_byte
+:	
	;; EAxx legato
	cp EFF_LEGATO
	jr nz,+
	rst get_byte
	ld (ix+t_legato),a
	rst get_byte
+:	
	;; E5xx finetune
	cp EFF_FINETUNE
	jr nz,+
	rst get_byte
	ld (ix+t_finetune),a
	rst get_byte
+:	
	;; E4xx fine vib depth
	cp EFF_VIBDEPTH
	jr nz,+
	rst get_byte
	ld (ix+t_vib_fine),a
	rst get_byte
+:	
	;; E3xx vib mode
	cp EFF_VIBMODE
	jr nz,+
	rst get_byte
	ld (ix+t_vib_mode),a
	rst get_byte
+:	
	;; E0xx arp speed
	cp EFF_ARPTICK
	jr nz,+
	rst get_byte
	ld (ix+t_arp_speed),a
	rst get_byte
+:	
	
	
	;;;;;
	
	;; Cxx retrig
	cp EFF_RETRIG
	jr nz,+
	rst get_byte
	ld (ix+t_retrig),a
	ld (ix+t_retrig_cnt),0
	rst get_byte
+:	
	
	;; Bxx/Dxx pattern break
	cp EFF_PATTBREAK
	jr nz,@@@nopattbreak
	
	rst get_byte
	cp $ff
	jr nz,+
	ld a,(iy+ss_order)
	inc a
+:	cp (iy+ss_song_size)
	jr nc,+
	
	ld (iy+ss_patt_break),a
+:
	rst get_byte
@@@nopattbreak:
	
	
	;; Axy volume slide
	cp EFF_VOLSLIDE
	jr nz,+
	rst get_byte
	ld (ix+t_vol_slide),a
	rst get_byte
+:	
	;; Fxx speed 2
	cp EFF_SPEED2
	jr nz,+
	rst get_byte
	ld (iy+ss_speed2),a
	rst get_byte
+:	
	;; 9xx speed 1
	cp EFF_SPEED1
	jr nz,+
	rst get_byte
	ld (iy+ss_speed1),a
	rst get_byte
+:	
	;; 8xx panning
	cp EFF_PANNING
	jr nz,+
	rst get_byte
	ld (ix+t_pan),a
	rst get_byte
+:	
	;; 4xy vibrato
	cp EFF_VIBRATO
	jr nz,+
	rst get_byte
	ld (ix+t_vib),a
	rst get_byte
+:	
	;; 0xy arpeggio
	cp EFF_ARP
	jr nz,+
	rst get_byte
	ld (ix+t_arp),a
	rst get_byte
+:	
	
	;; get pitch slide effect to act on it later
	cp EFF_PORTAUP
	jr c,@@@notenopitcheff
	
	ld (k_temp),a ;effect code
	
	rst get_byte ;param
	ld (k_temp+1),a
	
	rst get_byte
	jr @@@afternotepitcheff
	
@@@notenopitcheff:
	
	ex af,af'
	xor a
	ld (k_temp),a
	ex af,af'
	
@@@afternotepitcheff:
	
	
	
	;;;;;;;;;;;;;;;;;;;;;; note column
	
@@notecol:
	;; get duration
	push af
	cp $a0
	jr nc,@@@recalldur
	or a
	jp p,@@@normaldur
	
	rst get_byte
	ld (ix+t_dur_save),a
	jr @@@setdur
	
@@@recalldur:
	ld a,(ix+t_dur_save)
	jr @@@setdur
	
@@@normaldur:
	push bc
	push hl
	
	rlca
	rlca
	rlca
	and 3
	ld e,a
	ld d,0
	
	ld l,(ix+t_patt_dur_index)
	ld h,0
	add hl,hl
	add hl,hl
	add hl,de
	ex de,hl
	
	ld hl,(duration_tbl_base)
	ld a,(duration_tbl_base+2)
	call step_ptr_ahl
	
	ld a,(hl)
	
	pop hl
	pop bc
	rst set_bank
	
@@@setdur:
	ld (ix+t_dur_cnt),a
	
	
	
	ld a,(k_temp+1) ;save pitch effect param in d
	ld d,a
	
	pop af
	
	
	;; get note
	and $1f
	cp $1e
	jr c,@@@nonoteoff
	jr nz,@@@blanknote
	
	set T_FLG_KEYOFF,(ix+t_flags)
	
	xor a
	ld (ix+t_slide),a
	ld (ix+t_slide+1),a
	dec a
	ld (ix+t_slide_target),a
	
	jp @@aftersongdata
	
	
@@@nonoteoff:
	cp $1d
	jr nz,@@@nolongnote
	rst get_byte
	jr @@@gotnote
@@@nolongnote:
	add (ix+t_patt_base_note)
@@@gotnote:
	push bc
	push hl
	
	ld e,a ;save note in e
	
	ld a,(k_temp)
	cp EFF_TONEPORTA ;if there will be a toneporta, just init it
	jr z,@@@inittoneporta
	
	;if there will be another slide, always reinit the note
	or a
	jr nz,@@@noretarget
	
	;if there is already a targeted slide, change the target
	ld a,(ix+t_slide_target)
	cp $ff
	jr z,@@@noretarget
	ld l,(ix+t_slide)
	ld h,(ix+t_slide+1)
	bit 7,h
	jr z,@@@inittargetslide
	cpl
	ld h,a
	ld a,l
	cpl
	ld l,a
	inc hl
	jr @@@inittargetslide
	
	;init note as normal
@@@noretarget:
	ld a,e
	ld (ix+t_note),a
	call get_note_pitch
	ld (ix+t_pitch),l
	ld (ix+t_pitch+1),h
	
	bit SS_FLG_CONT_VIB,(iy+ss_flags)
	jr nz,+
	ld (ix+t_vib_phase),0
+:	
	;if legato is on, just change the pitch
	ld a,(ix+t_legato)
	or a
	jr nz,+
	ld a,(ix+t_flags)
	res T_FLG_KEYOFF,a
	res T_FLG_CUT,a
	set T_FLG_NOTE_RESET,a
	ld (ix+t_flags),a
+:	
	
	
	jr +
@@@blanknote:
	
	push bc
	push hl
+:
	
	
	;any other pitch effects?
	;(row note is in e, param is in d)
	ld a,(k_temp)
	or a
	jr z,@@@afternote
	cp EFF_PORTADOWN
	jr z,@@@effportadown
	jr c,@@@effportaup
	
@@@effnoteslide:
	;speed in hl
	ld a,d
	and $f0
	rrca
	rrca
	ld l,a
	ld h,0
	;target note in e
	ld a,d
	and $0f
	ld b,a
	ld a,(k_temp)
	cp EFF_NOTEDOWN
	ld a,b
	jr nz,+
	neg
+:	add (ix+t_note)
	jr +
	
@@@inittoneporta:
	ld l,d
	ld h,0
	
	;speed in hl, target note in e
@@@inittargetslide:
	ld a,e
	ld (ix+t_slide_target),a
+:	
	push hl
	call get_note_pitch
	pop de
	
	ld a,(ix+t_pitch)
	cp l
	ld a,(ix+t_pitch+1)
	sbc h
	
	;if pitch < target pitch, don't negate slide
	jr c,+
	ld a,e
	cpl
	ld e,a
	ld a,d
	cpl
	ld d,a
	inc de
+:	
	jr @@@setslide
	
	
	;regular portamento (speed is in d).
	;we need to negate the speed if portamento is down XOR this is a psg channel
@@@effportadown:
	ld e,1
	jr +
@@@effportaup:
	ld e,0
	
+:	ld a,(ix+t_chn)
	cp 10
	ccf
	rla
	xor e
	
	ld e,d
	ld d,0
	
	rrca
	jr nc,+
	ld a,e
	cpl
	ld e,a
	ld a,d
	cpl
	ld d,a
	inc de
+:
	
	ld (ix+t_slide_target),$ff
	
@@@setslide:
	ld (ix+t_slide),e
	ld (ix+t_slide+1),d
	
	
@@@afternote:
	
	pop hl
	pop bc
	
	
@@aftersongdata:
	ld (ix+t_patt_ptr),l
	ld (ix+t_patt_ptr+1),h
	ld (ix+t_patt_ptr+2),c
	
	
	
@@nonewsongdata:
	
	
	
	
	
	;;;;;;;;;;;;;;;;;;;;;;
	;; cut: if cut <= speedcnt then keyoff
	ld a,(ix+t_cut)
	or a
	jr z,@@nocut
	cp (iy+ss_speed_cnt)
	jr z,+
	jr nc,@@nocut
+:	
	set T_FLG_KEYOFF,(ix+t_flags)
	ld (ix+t_cut),0
@@nocut:
	
	
	;;;;;;;;;;;;;;;;;;;;;;
	;; retrig
	ld a,(ix+t_retrig)
	or a
	jr z,@@noretrig
	
	cp (ix+t_retrig_cnt)
	jr nz,@@stepretrig
	
	ld (ix+t_retrig_cnt),1
	set T_FLG_NOTE_RESET,(ix+t_flags)
	
	jr @@notereset
	
@@stepretrig:
	inc (ix+t_retrig_cnt)
	
@@noretrig:
	
	
	
	;;;;;;;;;;;;;;;;;;;;;;;;;;;
	;; handle note resets
	bit T_FLG_NOTE_RESET,(ix+t_flags)
	jr z,@@nonotereset
	
@@notereset:
	;reset the macro volume to its default
	ld b,$7f
	ld a,(ix+t_chn)
	cp 6+4
	jr c,+
	ld b,$0f
+:	ld (ix+t_macro_vol),b
	
	;disable macro arp
	ld (ix+t_macro_arp),$ff
	
	;restart all macros
	.if MACRO_SLOTS > 0
	
	ld d,ixh
	ld e,ixl
	ld hl,t_macros+mac_index
	add hl,de
	
	ld b,MACRO_SLOTS
	ld de,mac_size
	xor a
-:	ld (hl),a
	add hl,de
	djnz -
	
	.endif
	
	
@@nonotereset:
	
	
	
	
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	;; handle macros
	.if MACRO_SLOTS > 0
	ld (ix+t_macro_arp),$ff
	
	ld iy,t_macros
	ld d,ixh
	ld e,ixl
	add iy,de
	
	ld a,MACRO_SLOTS
@@macro_loop:
	ld (k_temp+5),a
	
	ld l,(iy+mac_base)
	ld h,(iy+mac_base+1)
	ld c,(iy+mac_base+2)
	
	ld a,l
	or h
	or c
	jp z,@@next_macro
	
	;get macro parameters
	rst set_bank
	rst get_byte ;macro type
	ld (k_temp),a
	rst get_byte ;macro length
	ld (k_temp+1),a
	ld d,a
	rst get_byte ;loop point
	ld (k_temp+2),a
	rst get_byte ;release point
	ld (k_temp+3),a
	
	;get macro value
	ld e,(iy+mac_index)
	ld a,e
	cp d ;is the macro over?
	jr nz,@@@got_index
	ld a,(k_temp+2) ;does it loop?
	cp $ff
	jp z,@@end_macro
	ld e,a
@@@got_index:
	ld a,e
	inc a
	ld (iy+mac_index),a
	ld d,0
	call step_ptr
	ld a,(hl)
	ld (k_temp+4),a
	
	;dispatch based on macro type
	ld a,(k_temp)
	cp $20
	jp c,@@@not_fm_op
	
	set T_FLG_FM_UPDATE,(ix+t_flags)
	
	;add op number to ix
	ld c,a
	and 3
	ld e,a
	ld d,0
	add ix,de
	
	;dispatch
	ld hl,@@@fm_op_tbl
	ld a,c
	sub $20
	and $fc
	rrca
	ld e,a
	add hl,de
	ld de,@@@after_fm_op
	push de
	ld a,(k_temp+4)
	jp (hl)
	
@@@fm_op_tbl:
	jr @@@fm_op_tl
	jr @@@fm_op_ar
	jr @@@fm_op_d1r
	jr @@@fm_op_d2r
	jr @@@fm_op_rr
	jr @@@fm_op_d1l
	jr @@@fm_op_rs
	jr @@@fm_op_mul
	jr @@@fm_op_dt
	jr @@@fm_op_am
	jr @@@fm_op_ssg_eg
	
	
@@@fm_op_tl:
	cpl
	and $7f
	ld (ix+t_fm+fm_40),a
	ret
	
@@@fm_op_ar:
	and $1f
	ld b,a
	ld a,(ix+t_fm+fm_50)
	and $c0
	or b
	ld (ix+t_fm+fm_50),a
	ret
	
@@@fm_op_d1r:
	and $1f
	ld b,a
	ld a,(ix+t_fm+fm_60)
	and $80
	or b
	ld (ix+t_fm+fm_60),a
	ret
	
@@@fm_op_d2r:
	ld (ix+t_fm+fm_70),a
	ret
	
@@@fm_op_rr:
	and $0f
	ld b,a
	ld a,(ix+t_fm+fm_80)
	and $f0
	or b
	ld (ix+t_fm+fm_80),a
	ret
	
@@@fm_op_d1l:
	and $0f
	rlca
	rlca
	rlca
	rlca
	ld b,a
	ld a,(ix+t_fm+fm_80)
	and $0f
	or b
	ld (ix+t_fm+fm_80),a
	ret
	
@@@fm_op_rs:
	and 3
	rrca
	rrca
	ld b,a
	ld a,(ix+t_fm+fm_50)
	and $1f
	or b
	ld (ix+t_fm+fm_50),a
	ret
	
@@@fm_op_mul:
	and $0f
	ld b,a
	ld a,(ix+t_fm+fm_30)
	and $70
	or b
	ld (ix+t_fm+fm_30),a
	ret
	
@@@fm_op_dt:
	ld hl,@@@fm_dt_map
	ld e,a
	ld d,0
	add hl,de
	ld a,(ix+t_fm+fm_30)
	and $0f
	or (hl)
	ld (ix+t_fm+fm_30),a
	ret
	
@@@fm_op_am:
	and 1
	rrca
	ld b,a
	ld a,(ix+t_fm+fm_60)
	and $1f
	or b
	ld (ix+t_fm+fm_60),a
	ret
	
@@@fm_op_ssg_eg:
	ld (ix+t_fm+fm_90),a	
	ret
	
@@@fm_dt_map:
	.db 7<<4, 6<<4, 5<<4, 0<<4, 1<<4, 2<<4, 3<<4, 4<<4	
	
@@@after_fm_op:
	ld ix,(k_cur_track_ptr)
	jp @@next_macro
	
	
@@@not_fm_op:
	cp 4
	jr c,+
	set T_FLG_FM_UPDATE,(ix+t_flags)
+:	
	
	;dispatch
	ld l,a
	ld h,0
	ld de,@@@macro_tbl
	add hl,hl
	add hl,de
	ld de,@@next_macro
	push de
	ld a,(k_temp+4)
	jp (hl)
	
@@@macro_tbl:
	jr @@@vol
	jr @@@arp
	jr @@@arp_fixed
	jr @@@noise
	
	jr @@@fm_alg
	jr @@@fm_fb
	jr @@@fm_fms
	jr @@@fm_ams
	
	
@@@vol:
	ld (ix+t_macro_vol),a
	ret
	
@@@arp:
	add (ix+t_note)
	ld (ix+t_macro_arp),a
	ret
	
@@@arp_fixed:
	add 5*12
	ld (ix+t_macro_arp),a
	ret
	
@@@noise:
	ld (ix+t_psg_noise),a
	ret
	
	
@@@fm_alg:
	and 7
	ld b,a
	ld a,(ix+t_fm+fm_b0)
	and $38
	or b
	ld (ix+t_fm+fm_b0),a
	ret
	
@@@fm_fb:
	rlca
	rlca
	rlca
	ld b,a
	ld a,(ix+t_fm+fm_b0)
	and 7
	or b
	ld (ix+t_fm+fm_b0),a
	ret
	
@@@fm_fms:
	and 7
	ld b,a
	ld a,(ix+t_fm+fm_b4)
	and $30
	or b
	ld (ix+t_fm+fm_b4),a
	ret
	
@@@fm_ams:
	and 3
	rlca
	rlca
	rlca
	rlca
	ld b,a
	ld a,(ix+t_fm+fm_b4)
	and 7
	or b
	ld (ix+t_fm+fm_b4),a
	ret
	
	
	;macro is over
@@end_macro:
	ld a,(k_temp) ;on fixed arps, disable the macro arp
	cp 2
	jr nz,+
	ld (ix+t_macro_arp),$ff
+:
	
	
@@next_macro:
	ld de,mac_size
	add iy,de
	ld a,(k_temp+5)
	dec a
	jp nz,@@macro_loop
	
	
	
	ld iy,(k_cur_song_slot_ptr)
	.endif
	
	
	
	
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	;; pitch slide
.define C_FNUM 644
	bit SS_FLG_PT_SLIDE,(iy+ss_flags)
	jr z,+
	ld a,(iy+ss_speed_cnt)
	or a
	jp z,@@noslide
	
+:
	;slide add value in de
	ld e,(ix+t_slide)
	ld d,(ix+t_slide+1)
	
	ld a,e
	or d
	jp z,@@noslide
	
@@doslide:
	;output pitch in hl
	ld l,(ix+t_pitch)
	ld h,(ix+t_pitch+1)
	
	ld a,(ix+t_chn)
	cp 10
	jr c,@@@fm
	
@@@psg:
	add hl,de
	jr @@afterslide


@@@fm:
	;get octave in b and fnum in hl
	ld a,h
	and $f8
	ld b,a
	ld a,h
	and 7
	ld h,a
	
	add hl,de
	
	ld a,l
	cp <C_FNUM
	ld a,h
	sbc >C_FNUM
	jr c,@@@down
	ld a,l
	cp <(C_FNUM*2)
	ld a,h
	sbc >(C_FNUM*2)
	jr c,@@afterslidefm
	
@@@up:
	ld a,b ;if we are already on octave 7 don't go up
	cp $38
	jr nc,@@@upclamp
	srl h
	rr l
	add 8
	jr @@afterslidefm2
	
@@@upclamp:
	ld a,h ;don't allow fnum to go above $7ff
	cp 8
	jr c,@@afterslidefm
	ld hl,$3fff
	jr @@afterslide
	
@@@downclamp:
	bit 7,h ;fnum can't go below 0
	jr z,@@afterslidefm
	ld hl,0
	jr @@afterslide
	
@@@down:
	ld a,b ;don't let octave go below 0
	or a
	jr z,@@@downclamp
	add hl,hl
	sub 8
	ld b,a
	
@@afterslidefm:
	ld a,b
@@afterslidefm2:
	or h
	ld h,a
	
	
@@afterslide:
	;; if the slide is targeted, check if we hit the note
	ld a,(ix+t_slide_target)
	cp $ff
	jr z,@@setslide
	ex de,hl
	call get_note_pitch
	
	;compare target - pitch
	ex de,hl
	ld a,e
	cp l
	ld a,d
	sbc h
	
	bit 7,(ix+t_slide+1)
	jr nz,@@@sub
	
@@@add:
	;when adding, the note is hit when target < pitch
	jr c,@@@hit
	jr @@setslide
	
@@@sub:
	;when subtracting the note is hit when target >= pitch
	jr c,@@setslide
	
@@@hit:
	ld a,(ix+t_slide_target)
	ld (ix+t_note),a
	
	ld (ix+t_slide_target),$ff
	
	ex de,hl ;make the target the pitch
	
	xor a
	ld (ix+t_slide),a
	ld (ix+t_slide+1),a
	
	
@@setslide:
	ld (ix+t_pitch),l
	ld (ix+t_pitch+1),h
	
@@noslide:
	
	
	
	
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	;; arp
	ld a,(ix+t_arp)
	or a
	jr z,@@noarp
	
	bit SS_FLG_PT_ARP,(iy+ss_flags)
	jr z,@@normalarp
	ld a,(iy+ss_speed_cnt)
	or a
	jr nz,@@normalarp
	;a is 0
	ld b,a
	jr @@setarp
	
@@normalarp:
	ld a,(ix+t_arp_cnt)
	inc a
	cp (ix+t_arp_speed)
	jr c,@@setarpcnt
	
	xor a
	ld b,(ix+t_arp_phase)
	inc b
	ex af,af'
	ld a,b
	cp 3
	jr c,+
	xor a
+:	ld b,a
	ex af,af'
	
@@setarp:
	ld (ix+t_arp_phase),b
@@setarpcnt:
	ld (ix+t_arp_cnt),a
@@noarp:
	
	
	
	
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	;; vibrato
	ld a,(ix+t_vib)
	rrca
	rrca
	rrca
	rrca
	and $0f
	add (ix+t_vib_phase)
	ld (ix+t_vib_phase),a
	
	
	
	
	
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	;; volume slide
@@volslide:
	ld a,(ix+t_vol_slide)
	or a
	jr z,@@novolslide
	
	;lower 2 bits are the new fractional part
	add a,(ix+t_vol_frac)
	ld b,a
	and 3
	ld (ix+t_vol_frac),a
	
	;get the max volume in c
	ld c,$80
	ld a,(ix+t_chn)
	cp 10
	jr c,+
	ld c,$10
+:	
	
	;upper 6 bits are the signed non-fractional add value
	ld a,b
	sra a
	sra a
	ld b,a
	add (ix+t_vol)
	
	bit 7,b
	jr nz,@@@sub
	
@@@add:
	;adding. when volume is > max, set it to max
	cp c
	jr c,@@@set
	ld a,c
	dec a
	ld (ix+t_vol_frac),3
	jr @@@set
	
@@@sub:
	;subtracting. when volume underflows, set it to 0
	or a
	jp p,@@@set
	xor a
	ld (ix+t_vol_frac),a
	
@@@set:
	ld (ix+t_vol),a
	
@@novolslide:
	
	
	
	
	
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	;; tell what channel we're on
	
	;if the track is cut, don't set it
	bit T_FLG_CUT,(ix+t_flags)
	jr nz,@@nosetchn
	
	;if a psg channel is keyed off, don't set it
	ld a,(ix+t_chn)
	cp 10
	jr c,@@setchn
	bit T_FLG_KEYOFF,(ix+t_flags)
	jr nz,@@nosetchn
	
	
@@setchn:
	ld hl,k_chn_track
	ld e,a
	ld d,0
	add hl,de
	ld a,(k_cur_track)
	ld (hl),a
	
@@nosetchn:
	
	
	
	
@@notrack:
	ld de,t_size
	add ix,de
	ld a,(k_cur_track)
	inc a
	cp KN_TRACKS
	jp c,@trackloop
	
	
	
	
	
	
	
	
	
	
	
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	;; fm output
	
	;set up part registers
	ld b,>FM1REG
	ld d,b
	ld h,b
	ld c,<FM1REG
	ld l,c
	ld e,<FM1DATA
	exx
	
	
	;lfo
	ld b,$22
	ld a,(k_fm_lfo)
	rst write_fm
	
	
	
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;; extd.chn3 out
	
	ld b,$27
	
	;;; first see if we use it at all
	
	;if all extd.chn3 tracks are unoccupied, don't
	ld hl,k_chn_track+6
	ld a,(hl)
	inc hl
	and (hl)
	inc hl
	and (hl)
	inc hl
	and (hl)
	jp m,@no_fm_3_out
	
	;if the std.chn3 track is higher than any extd.chn3 track, do std.chn3
	ld a,(k_chn_track+2)
	or a
	jp m,@do_fm_3_out
	ld hl,k_chn_track+6
	cp (hl)
	jp nc,@no_fm_3_out
	inc hl
	cp (hl)
	jp nc,@no_fm_3_out
	inc hl
	cp (hl)
	jp nc,@no_fm_3_out
	inc hl
	cp (hl)
	jp nc,@no_fm_3_out
	
@do_fm_3_out:
	;ok, turn on extd.chn3
	ld a,$40
	rst write_fm
	
	ld a,$fe
	ld (k_chn_track+2),a
	inc a
	ld (k_fm_extd_chn3),a
	ld (k_prv_fm_track+2),a
	
	
	ld a,3 ;operator count
@fm_3_loop:
	ld (k_temp),a
	ld e,a
	ld d,0
	
	;get operator index
	or a ;operator -> register order
	jr z,+
	cp 3
	jr z,+
	xor 3
+:	ld b,a
	add a,a
	add a,a
	add a,2
	ld (k_temp+1),a
	;get keyon register or mask
	ld a,$08
	inc b
-:	add a,a
	djnz -
	ld (k_temp+2),a
	
	;check if track is on
	ld hl,k_chn_track+6
	add hl,de
	ld a,(hl)
	or a
	ld hl,k_prv_fm_track+6 ;this operation does not affect sign flag
	add hl,de
	jp p,@@go
	
@@kill:
	ld c,$ff ;set channel as killed
	ld (hl),c
	
	;set TL to $7f
	ld a,(k_temp+1)
	ld d,a
	or $40
	ld b,a
	ld a,c
	rst write_fm
	
	;set RR to $0f
	ld a,d
	or $80
	ld b,a
	ld a,c
	rst write_fm
	
	;keyoff
	ld b,$28
	ld a,(k_temp+2)
	cpl
	ld hl,k_fm_prv_chn3_keyon
	and (hl)
	ld (hl),a
	rst write_fm
	jp @@next
	
	
@@go:
	push hl
	call set_track
	call get_track_song_slot
	pop hl
	
	;; if the track of the channel has changed and there is no note reset yet, kill the channel
	ld a,(k_cur_track)
	cp (hl)
	jr z,+
	
	bit T_FLG_NOTE_RESET,(ix+t_flags)
	jr z,@@kill
	
	set T_FLG_FM_UPDATE,(ix+t_flags)
	ld (hl),a
+:	
	
	
	;; if the note will be reset, keyoff first
	bit T_FLG_NOTE_RESET,(ix+t_flags)
	jr z,+
	ld b,$28
	ld hl,k_fm_prv_chn3_keyon
	ld a,(k_temp+2)
	cpl
	and (hl)
	ld (hl),a
	rst write_fm
+:	
	
	
	
	;; write fm patch for this operator
	bit T_FLG_FM_UPDATE,(ix+t_flags)
	jr z,@@no_patch
	res T_FLG_FM_UPDATE,(ix+t_flags)
	
	;get pointer to fm patch + operator in hl
	ld a,(k_temp)
	ld l,a
	ld h,0
	ld d,ixh
	ld e,ixl
	add hl,de
	ld de,t_fm
	add hl,de
	ld de,4
	
	;get register base in b
	ld a,(k_temp+1)
	or $30
	ld b,a
	ld c,$10
	
	;mul/dt
	ld a,(hl)
	rst write_fm
	add hl,de
	add hl,de
	ld a,b
	add c
	add c
	
	;everything that isn't TL
-:	ld b,a
	ld a,(hl)
	rst write_fm
	add hl,de
	ld a,b
	add c
	cp $a0
	jr c,-
	
	
@@no_patch:
	
	;; only write global fm params for the highest operator
	ld hl,k_fm_extd_chn3
	ld a,(hl)
	or a
	jp p,+
	
	ld (hl),0
	
	ld b,$b2
	ld a,(ix+t_fm+fm_b0)
	rst write_fm
	
	ld b,$b6
	ld a,(ix+t_fm+fm_b4)
	or (ix+t_pan)
	rst write_fm
	
+:	
	
	;; always write TL, since it could be changed at any moment by t_vol
	ld h,(ix+t_vol)
	ld e,(ix+t_macro_vol)
	inc e
	call mulu_h_e
	ex de,hl
	ld a,(iy+ss_volume)
	call mulu_de_a
	sla h
	rla
	
	ld hl,k_temp
	ld e,(hl)
	ld d,0
	add ix,de
	
	ld e,$7f
	xor e
	ld d,a
	
	ld a,(k_temp+1)
	or $40
	ld b,a
	
	ld a,(ix+t_fm+fm_40)
	add d
	jp p,+
	ld a,e
+:	rst write_fm
	
	ld ix,(k_cur_track_ptr)
	
	
	
	;; write frequency
	call get_effected_pitch
	ex de,hl
	
	ld hl,fm_chn3_freq_reg_tbl
	ld a,(k_temp)
	ld c,a
	ld b,0
	add hl,bc
	ld b,(hl)
	ld a,d
	rst write_fm
	ld a,b
	sub 4
	ld b,a
	ld a,e
	rst write_fm
	
	
	
	;; write key state
	ld hl,k_fm_prv_chn3_keyon
	ld a,(k_temp+2)
	bit T_FLG_KEYOFF,(ix+t_flags)
	jr nz,@@keyedoff
	
	or (hl)
	jr @@setkey
	
@@keyedoff:
	cpl
	and (hl)
@@setkey:
	ld (hl),a
	ld b,$28
	rst write_fm
	
	
	
@@next:
	ld a,(k_temp)
	dec a
	jp p,@fm_3_loop
	
	
	
	
	
	jr @fm_normal_out
	
@no_fm_3_out:
	
	;turn off extd.chn3
	xor a
	rst write_fm
	
	
@fm_normal_out:
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	;; psg output
	
	ld a,3 ;channel index
@psg_loop:
	ld (k_temp),a
	
	rrca ;psg register channel index
	rrca
	rrca
	ld (k_temp+1),a
	
	;;; get track
	ld a,(k_temp)
	ld e,a
	ld d,0
	ld hl,k_chn_track+10
	add hl,de
	
	ld a,(hl)
	or a
	jp p,@@ok
@@kill:
	ld a,(k_temp+1)
	or $9f
	ld (PSG),a
	jp @@next
	
@@ok:
	call set_track
	call get_track_song_slot
	
	;; get volume
	ld a,(ix+t_vol)
	rlca
	rlca
	rlca
	rlca
	or (ix+t_macro_vol)
	ld e,a
	ld hl,(psg_volume_tbl_base)
	ld a,(psg_volume_tbl_base+2)
	call step_ptr_e_ahl
	
	ld e,(hl)
	ld a,(iy+ss_volume)
	and $f0
	or e
	ld e,a
	ld hl,(psg_volume_tbl_base)
	ld a,(psg_volume_tbl_base+2)
	call step_ptr_e_ahl
	
	ld a,(hl)
	cpl
	and $0f
	ld b,a
	ld a,(k_temp+1)
	or b
	or $90
	ld (PSG),a
	
	
	;;; check noise channel
	ld a,(k_temp)
	cp 3
	jr nz,@@not_noise
	
	;; set up noise register write value
	ld a,$e0
	ld e,(ix+t_psg_noise)
	
	bit 0,e ;white noise?
	jr z,+
	or 4
+:	
	bit 1,e ;locked mode?
	jr nz,@@noise_ext
	
	;locked, get noise note
	push af
	
	call get_effected_note
	add a,a
	inc a
	ld e,a
	ld hl,(note_octave_tbl_base)
	ld a,(note_octave_tbl_base+2)
	call step_ptr_e_ahl
	
	;too high?
	pop af
	ld e,a
	
	ld a,(hl)
	cp 3
	jr c,+
	ld a,2
+:
	cpl
	dec a
	and 3
	or e
	
	jr @@set_noise
	
@@noise_ext:
	or 3
	
@@set_noise:
	ld hl,k_psg_prv_noise
	cp (hl)
	jr z,+
	ld (hl),a
	ld (PSG),a
+:	
	
	;; do we need to write period?
	cpl
	and 3
	jr nz,@@next
	
	ld a,$40 ;set channel write index to tone2
	ld (k_temp+1),a
	ld a,$ff ;disable tone2 output
	ld (k_chn_track+10+2),a
	
	;;; write period
@@not_noise:
	call get_effected_pitch
	ld a,h ;clamp > $3ff
	cp 4
	jr c,+
	ld hl,$3ff
+:		
	ld a,(k_temp+1)
	ld b,a
	ld a,l
	and $0f
	or b
	or $80
	ld (PSG),a
	.rept 4
		srl h
		rr l
	.endr
	ld a,l
	ld (PSG),a
	
	
	
@@next:
	ld a,(k_temp)
	dec a
	jp p,@psg_loop
	
	
	
	
	
	
	
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	;; acknowledge all note resets
	ld ix,k_tracks
	ld de,t_size
	ld b,KN_TRACKS
-:	res T_FLG_NOTE_RESET,(ix+t_flags)
	add ix,de
	djnz -
	
	
	
	
	
	ret
	
	
	
	
	
	
	
	
	
	
	;note in a, returns pitch in hl
get_note_pitch:
	push bc
	push de
	ld l,a
	ld h,0
	add hl,hl
	ex de,hl
	
	ld a,(ix+t_chn)
	cp 10
	jr nc,@psg
	
	
@fm:	ld hl,(note_octave_tbl_base)
	ld a,(note_octave_tbl_base+2)
	call step_ptr_ahl
	
	rst get_byte ;octave
	ld b,a
	
	ld l,(hl) ;note
	ld h,0
	ld de,fm_fnum_tbl
	add hl,hl
	add hl,de
	
	;get fnum in de
	ld e,(hl)
	inc hl
	ld d,(hl)
	
	bit 7,b ;octave negative?
	jr nz,@@low
	cp 8 ;octave too high?
	jr nc,@@high
	
	;normal, just set the octave
	rlca
	rlca
	rlca
@@set:	
	or d
@@set2:
	ld h,a
	ld l,e
	
	jr @exit
	
	
@@low:
	srl d
	rr e
	inc a
	jr nz,@@low
@@exexit:
	ex de,hl
	jr @exit
	
	
@@high:
	sub 7
	ld b,a
	
	ld a,d
-:	sla e
	rla
	cp 8 ;if the fnum is >= $800, too bad
	jr nc,@@too_high
	djnz -
	
	or $38
	ld d,a
	jr @@exexit
	
	
@@too_high:
	ld hl,$3fff
	jr @exit
	
	
	
@psg:	ld hl,(psg_period_tbl_base)
	ld a,(psg_period_tbl_base+2)
	call step_ptr_ahl
	
	rst get_byte
	ld d,a
	ld e,(hl)
	ex de,hl
	
@exit:
	pop de
	pop bc
	ret
	
	
	
	
	
	
	
	
	; returns note in a
get_effected_note:
	push bc
	
	;if the macro is arpeggiating, use that as the base note
	ld a,$ff
	ld b,(ix+t_macro_arp)
	cp b
	jr nz,+
	;otherwise use the pattern note
	ld b,(ix+t_note)
+:
	
	;pattern arp effect?
	ld a,(ix+t_arp_phase)
	or a
	jr z,@got
	ld c,a
	ld a,(ix+t_arp)
	dec c
	jr nz,@got2
	rrca
	rrca
	rrca
	rrca
@got2:
	and $0f
@got:
	add a,b
	
	pop bc
	ret
	
	
	
	
	
	
	
	
	
	; returns pitch in hl
get_effected_pitch:
	push bc
	push de
	
	;;;;; get total finetune in hl
	;;;;; every 256 finetune units is a semitone up
	
	ld a,(ix+t_finetune)
	ld l,a
	rlca
	sbc a,a
	ld h,a
	bit SS_FLG_LINEAR_PITCH,(iy+ss_flags)
	jr z,+
	add hl,hl
+:	
	
	;;; if vibrato is on, add it to the finetune
	ld a,(ix+t_vib)
	or a
	jr z,@novib
	
	push hl
	
	ld a,(ix+t_vib_phase)
	and $3f
	add a,a
	ld e,a
	ld hl,(vib_tbl_base)
	ld a,(vib_tbl_base+2)
	call step_ptr_e_ahl
	rst get_byte
	ld d,a
	ld e,(hl)
	
	;; check vibrato mode
	ld a,(ix+t_vib_mode)
	or a
	jr z,@scalevib
	dec a
	jr nz,@vibdown
	;mode 1, only up
	bit 7,d
	jr z,@scalevib
	jr @novib2
	
	;mode 2, only down
@vibdown:
	bit 7,d
	jr z,@novib2
	
	
	;; scale vibrato based on depths
@scalevib:
	ld a,d
	or e
	jr z,@novib2
	
	push de
	
	ld l,(ix+t_vib_fine)
	ld h,0
	.rept 4
		add hl,hl
	.endr
	ld a,(ix+t_vib)
	and $0f
	or l
	ld l,a
	add hl,hl
	ex de,hl
	
	ld hl,(vib_scale_tbl_base)
	ld a,(vib_scale_tbl_base+2)
	call step_ptr_ahl
	rst get_byte
	ld b,a
	ld c,(hl)
	pop de
	call muls_bc_de
	ld d,e
	ld e,h
	
	bit SS_FLG_LINEAR_PITCH,(iy+ss_flags)
	jr nz,+
	.rept 3
		sra d
		rr e
	.endr
+:
	
	
	pop hl
	add hl,de
	jr @novib
	
@novib2:
	pop hl
	
@novib:
	
	
	;;;;; get base pitch in hl
	;;;;; (and move finetune to de)
	ex de,hl
	
	;first, check if we use the current pitch or the arpeggio
	ld a,(ix+t_slide) ;if sliding, always use current pitch
	or (ix+t_slide+1)
	jr nz,@curpitch
	ld a,(ix+t_macro_arp) ;if the macro is arpeggiating, use arpeggio
	inc a
	jr nz,@pitcharp
	ld a,(ix+t_arp) ;if the pattern arp effect is inactive use the current pitch
	or a
	jr z,@curpitch
	
@pitcharp:
	;get arpeggio note pitch
	call get_effected_note
	call get_note_pitch
	jr @gotpitch
	
@curpitch:
	ld l,(ix+t_pitch)
	ld h,(ix+t_pitch+1)
	
@gotpitch:
	
	
	;;;;; apply finetune to pitch
	
	ld a,(ix+t_chn)
	cp 10
	bit SS_FLG_LINEAR_PITCH,(iy+ss_flags)
	jr z,@no_linear
	
@linear:
	;;; linear: pitch is in hl, semitone difference is in d, finetune is in e
	jr nc,@@psg
	
@@fm:
	;; apply finetune to fm
	;TODO
	jr @exit
	
	
@@psg:
	;; apply finetune to psg
	
	; if needed, fix semitone
	ld a,d
	or a
	jr z,+
	
	push de
	
	push hl
	neg
	add a,5*12
	ld l,a
	ld h,0
	add hl,hl
	ex de,hl
	ld hl,(semitune_tbl_base)
	ld a,(semitune_tbl_base+2)
	call step_ptr_ahl
	rst get_byte
	ld b,a
	ld c,(hl)
	pop de
	call mulu_bc_de
	ld l,h
	ld h,e
	ld a,d
	.rept 3
		rrca
		rr h
		rr l
	.endr
	
	pop de
	
+:	
	; do any finetuning
	ld a,e
	or a
	jr z,@exit
	
	push hl
	ld d,0
	ex de,hl
	add hl,hl
	ex de,hl
	ld hl,(psg_finetune_tbl_base)
	ld a,(psg_finetune_tbl_base+2)
	call step_ptr_ahl
	rst get_byte
	ld b,a
	ld c,(hl)
	pop de
	call mulu_bc_de
	ex de,hl
	
	jr @exit
	
	
	
	
	
@no_linear:
	;;; register: pitch is in hl, register add value is in de
	jr nc,@@psg
	
@@fm:
	;; apply finetune to fm
	;TODO
	jr @exit
	
	
@@psg:
	;; apply finetune to psg
	xor a
	sbc hl,de
	
	
@exit:
	pop de
	pop bc
	ret
	
	
	
	
	
	
	
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; data
	
track_ptr_tbl:
	.redefine idx 0
	.rept KN_TRACKS
		.dw t_size*idx + k_tracks
		.redefine idx idx+1
	.endr
	
song_slot_ptr_tbl:
	.redefine idx 0
	.rept KN_SONG_SLOTS
		.dw ss_size*idx + k_song_slots
		.redefine idx idx+1
	.endr
	
	

kn_track_song_slot_ptr_tbl:
	.redefine idx 0
	.rept KN_SONG_SLOTS
		.dsw KN_SONG_SLOT_TRACKS, ss_size*idx + k_song_slots
		.redefine idx idx+1
	.endr

kn_song_slot_track_ptr_tbl:
	.redefine idx 0
	.rept KN_SONG_SLOTS
		.dw t_size*idx*KN_SONG_SLOT_TRACKS + k_tracks
		.redefine idx idx+1
	.endr
	
kn_song_slot_size_tbl:
	.dsb KN_SONG_SLOTS,KN_SONG_SLOT_TRACKS
	
	
	
	
fm_chn3_freq_reg_tbl:
	.db $ad,$ac,$ae,$a6
	
fm_fnum_tbl:
	.dw 644,681,722,765,810,858,910,964,1021,1081,1146,1214
	
	
	
	
	
	
	
	
	
	