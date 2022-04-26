Z80 = $a00000
Z80BUSREQ = $a11100
Z80RESET = $a11200

PSG = $c00011


	include "COMPILED-MODULE.asm"


AMT_TRACKS = 14

AMT_CHANNELS = 14

AMT_SONG_SLOTS = 1


	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	;; RAM structure definitions
	
	; macro
	clrso
mac_base so.l 1
mac_index so.b 1
	so.b 1
mac_size = __SO
	
	
	
	;fm patch
	clrso
fm_30 so.b 4
fm_40 so.b 4
fm_50 so.b 4
fm_60 so.b 4
fm_70 so.b 4
fm_80 so.b 4
fm_90 so.b 4
fm_b0 so.b 1
fm_b4 so.b 1
fm_size = __SO
	
	
	; track
T_FLG_ON = 7
T_FLG_CUT = 6
T_FLG_KEYOFF = 5
T_FLG_NOTE_RESET = 4
T_FLG_FM_UPDATE = 3
	
	
	clrso
t_flags so.b 1
t_chn so.b 1

t_seq_base so.l 1
t_patt_index so.w 1

t_dur_cnt so.b 1
t_dur_save so.b 1

t_delay so.b 1
t_legato so.b 1
t_cut so.b 1
t_smpl_bank so.b 1
t_retrig so.b 1
t_retrig_cnt so.b 1
t_note so.b 1
	so.b 1

;;;
t_instr so.w 1

t_vol so.w 1 ;this is a word because volume slide needs a fractional part- most routines should only access the upper byte
t_vol_slide so.b 1
t_pan so.b 1

t_pitch so.w 1
t_slide so.w 1
t_slide_target so.b 1
t_finetune so.b 1

t_arp so.b 1
t_arp_speed so.b 1
t_arp_cnt so.b 1
t_arp_phase so.b 1

t_vib so.b 1
t_vib_phase so.b 1
t_vib_fine so.b 1
t_vib_mode so.b 1


;;;
t_fm so.b fm_size

t_macros so.b mac_size*MACRO_SLOTS

t_macro_vol so.b 1
t_macro_arp so.b 1

t_psg_noise so.b 1

t_dac_mode so.b 1

	;0: no sample
	;$02xxxxxx: sample map, xxxxxx is the pointer (TODO: NOT IMPLEMENTED)
	;$03xxxxxx: pitchable single sample, xxxxxx is the pointer
t_instr_sample so.l 1


t_size = __SO
	
	
	
	;song slot
	;anything song-global goes here, like speed and pattern breaks
	
SS_FLG_ON = 7
SS_FLG_LOOP = 6

SS_FLG_LINEAR_PITCH = 3
SS_FLG_CONT_VIB = 2
SS_FLG_PT_SLIDE = 1
SS_FLG_PT_ARP = 0

	
	
	clrso
ss_flags so.b 1
ss_volume so.b 1 ;TODO: not implemented
	
ss_order so.b 1
ss_patt_break so.b 1 ;$ff - no skip
ss_song_size so.b 1

ss_row so.b 1
ss_patt_size so.b 1

ss_speed_cnt so.b 1
ss_speed1 so.b 1
ss_speed2 so.b 1

ss_sample_map so.l 1

ss_size = __SO
	
	
	;all vars
	clrso
	
k_song_slots so.b ss_size*AMT_SONG_SLOTS

k_tracks so.b t_size*AMT_TRACKS



k_chn_track so.b AMT_CHANNELS

k_prv_fm_track so.b 10

k_psg_prv_noise so.b 1

k_fm_prv_chn3_keyon so.b 1
k_fm_extd_chn3 so.b 1
k_fm_lfo so.b 1


k_sync so.b 1

KN_VAR_SIZE = __SO

	public KN_VAR_SIZE
	
	
	
	; z80-side variables
z80_base = Z80 + $1ff0

	clrso
z80_start_flag so.b 1
z80_cur_reg so.b 1

z80_start_lo so.b 1
z80_start_hi so.b 1
z80_start_bank so.b 1

z80_loop_lo so.b 1
z80_loop_hi so.b 1
z80_loop_bank so.b 1

z80_rate_lo so.b 1
z80_rate_hi so.b 1
	


	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	;; effect enum
	setso $c0
EFF_PORTAUP so.b 1
EFF_PORTADOWN so.b 1
EFF_NOTEUP so.b 1
EFF_NOTEDOWN so.b 1
EFF_TONEPORTA so.b 1
EFF_ARP so.b 1
EFF_VIBRATO so.b 1
EFF_PANNING so.b 1
EFF_SPEED1 so.b 1
EFF_SPEED2 so.b 1
EFF_VOLSLIDE so.b 1
EFF_PATTBREAK so.b 1
EFF_RETRIG so.b 1

EFF_ARPTICK so.b 1
EFF_VIBMODE so.b 1
EFF_VIBDEPTH so.b 1
EFF_FINETUNE so.b 1
EFF_LEGATO so.b 1
EFF_SMPLBANK so.b 1
EFF_CUT so.b 1
EFF_SYNC so.b 1 ;TODO: write sync access routine

EFF_LFO so.b 1
EFF_FB so.b 1
EFF_TL1 so.b 1
EFF_TL2 so.b 1
EFF_TL3 so.b 1
EFF_TL4 so.b 1
EFF_MUL so.b 1
EFF_DAC so.b 1
EFF_AR1 so.b 1
EFF_AR2 so.b 1
EFF_AR3 so.b 1
EFF_AR4 so.b 1
EFF_AR so.b 1

EFF_NOISE so.b 1

MAX_EFFECT = __SO - 1




	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	;;
	;; Note on calling conventions:
	;;	GCC expects the parameters to be pushed in REVERSE order, and then manually popped off once the subroutine exits.
	;;	Registers d0-d1/a0-a1 are safe to clobber, all others must be saved.
	;;	Any return value is returned in d0.
	
	
	db "KokonoePlayer-68k v0.50 coded by karmic"
	align 1
	
	
	
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	;; Reset routine
kn_reset::
	cargs #(6+5+1)*4,.arg_music_base.l
	
	movem.l d2-d7/a2-a6,-(sp)
	
	;;;;; copy code over to z80
	lea Z80,a0
	lea Z80BUSREQ,a1
	lea $100(a1),a2
	
	moveq #0,d0
	move.w #$0100,d1
	
	move.w d0,(a2) ;reset on
	move.w d1,(a1) ;busreq on
	move.w d1,(a2) ;reset off
	
	lea PSG,a3
	move.b #$9f,(a3)
	move.b #$bf,(a3)
	move.b #$df,(a3)
	move.b #$ff,(a3)
	
.waitready:
	btst.b #0,(a1)
	bne .waitready
	
	lea z80_blob,a3
	move.w #z80_blob_end-z80_blob-1,d7
.z80copy:
	move.b (a3)+,(a0)+
	dbra d7,.z80copy
	move.w #$2000-(z80_blob_end-z80_blob)-1,d7
.z80clear:
	move.b d0,(a0)+
	dbra d7,.z80clear
	
	move.w d0,(a2) ;reset on
	move.w d0,(a1) ;busreq off

	moveq #$7f,d7
.waitreset:
	dbra d7,.waitreset
	move.w d1,(a2) ;reset off
	
	
	;;;;;; clear music ram
	movea.l .arg_music_base(sp),a6
	movea.l a6,a5
	
	move.w #KN_VAR_SIZE/4 - 1, d7
.clearram:
	move.l d0,(a5)+
	dbra d7,.clearram
	
	
	moveq #-1,d0
	lea k_prv_fm_track(a6),a5
	move.l d0,(a5)+
	move.l d0,(a5)+
	move.w d0,(a5)+
	
	
	
	move.b #2,k_fm_prv_chn3_keyon(a6)
	
	;default value obtained by poking in a vgm log
	move.b #8,k_fm_lfo(a6)
	
	
	movem.l (sp)+,d2-d7/a2-a6
	rts
	
	
	
	
	
	
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	;; Init routine
kn_init::
	cargs #(6+5+1)*4, .arg_music_base.l, .arg_song_id.l, .arg_loop.l
	
	movem.l d2-d7/a2-a6,-(sp)
	
	movea.l .arg_music_base(sp),a6
	move.l .arg_song_id(sp),d0
	
	;;; get song base
	lea kn_song_tbl,a0
	lsl.l #2,d0
	movea.l (a0,d0),a0
	
	
	;;; get song slot id
	moveq #0,d0
	move.b (a0)+,d0
	
	;;; get amount of tracks in song slot in d4
	lea kn_song_slot_size_tbl,a1
	moveq #0,d4
	move.b (a1,d0),d4
	
	;;; get song slot pointer
	lsl.l #1,d0
	lea song_slot_index_tbl,a1
	move.w (a1,d0),d1
	lea (a6,d1.w),a4
	
	;;; get track pointer
	lea kn_song_slot_track_index_tbl,a1
	move.w (a1,d0),d1
	lea (a6,d1.w),a5
	
	
	;;; set up song slot
	move.b (a0)+,d0
	tst.l .arg_loop(a7)
	beq .noloop
	bset #SS_FLG_LOOP,d0
.noloop
	move.b d0,ss_flags(a4)
	st ss_volume(a4)
	
	move.b (a0)+,ss_patt_size(a4)
	
	move.b (a0)+,ss_speed1(a4)
	move.b (a0)+,d0
	move.b d0,ss_speed2(a4)
	subq.b #1,d0
	move.b d0,ss_speed_cnt(a4)
	addq.l #1,a0
	
	move.w (a0)+,d0
	lsl.w #2,d0
	lea kn_sample_map_tbl,a1
	move.l (a1,d0.w),ss_sample_map(a4)
	
	moveq #0,d5 ;song size in d5
	move.b (a0)+,d5
	move.b d5,ss_song_size(a4)
	
	clr.b ss_order(a4)
	st ss_row(a4)
	st ss_patt_break(a4)
	
	
	;;; set up tracks
	moveq #0,d7 ;channel count in d7
	move.b (a0)+,d7
	
	movea.l a0,a1 ;channel arrangement table in a1
	
	adda.l d7,a0 ;track sequence pointer in a0
	btst #0,d7 ;if the amount of channels is odd, realign the pointer
	beq .evenchans
	addq.l #1,a0
.evenchans
	
	move.l d7,d6 ;adjust channel count for dbra (in d6)
	subq.l #1,d6
	
	lsl.l #2,d5 ;song size -> sequence size in bytes

	;; initialize any tracks that are used in the song
	
.track:
	
	movea.l a5,a3 ;clear variables
	move.l #t_size-1,d0
	moveq #0,d1
.trackclear:
	move.b d1,(a3)+
	dbra d0,.trackclear
	
	;init pattern player
	move.b #(1 << T_FLG_ON) | (1 << T_FLG_CUT) | (1 << T_FLG_KEYOFF) | (1 << T_FLG_FM_UPDATE),t_flags(a5)
	move.b (a1)+,d0
	move.b d0,t_chn(a5)
	move.l a0,t_seq_base(a5)
	addq.b #1,t_dur_cnt(a5)
	addq.w #2,t_patt_index(a5)
	
	;init instrument/effects
	subq.w #1,t_instr(a5)
	subq.b #1,t_slide_target(a5)
	move.b #$c0,t_pan(a5)
	addq.b #1,t_arp_speed(a5)
	move.b #$0f,t_vib_fine(a5)
	
	addq.b #3,t_psg_noise(a5)
	
	;initialize fm patch to TL $7f/RR $f/ D1L $f
	;this is to avoid any init noise
	moveq #-1,d1
	move.l d1,t_fm+fm_40(a5)
	move.l d1,t_fm+fm_80(a5)
	
	;depending on channel type, init volume
	move.b #$7f,d1
	cmpi.b #6+4,d0
	blo .volfm
	move.b #$0f,d1
.volfm
	move.b d1,t_vol(a5)
	
	adda.l d5,a0
	adda.l #t_size,a5
	
	dbra d6,.track
	
	
	;; turn off any unused tracks in the song slot
	sub.l d7,d4 ;cleared tracks = song slot tracks - song tracks
	beq .notrackdisable
	subq.l #1,d4 ;dbra adjust
.trackdisable
	clr.b t_flags(a5)
	adda.l #t_size,a5
	dbra d4,.trackdisable
	
.notrackdisable
	
	
	
	movem.l (sp)+,d2-d7/a2-a6
	rts
	
	
	
	
	
	
	
	
	
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	;; play routine
kn_play::
	cargs #(6+5+1)*4, .arg_music_base.l
	
	movem.l d2-d7/a2-a6,-(sp)
	
	movea.l .arg_music_base(sp),a6
	
	
	
	
	
	
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	;; handle song slots
	moveq #AMT_SONG_SLOTS-1,d7
	lea k_song_slots(a6),a4
.song_slot_loop
	btst.b #SS_FLG_ON,ss_flags(a4)
	beq .next_song_slot
	
	move.b ss_order(a4),d5
	move.b ss_row(a4),d4
	move.b ss_speed_cnt(a4),d3
	
	
	;is the row over?
	moveq #0,d0
	move.b d4,d0
	andi.b #1,d0
	addq.b #1,d3
	cmp.b ss_speed1(a4,d0),d3
	bne .song_slot_set_speed
	moveq #0,d3
	
	;any pattern break?
	move.b d5,d2 ;save the old order
	
	move.b ss_patt_break(a4),d0
	bmi .no_patt_break
	st ss_patt_break(a4)
	moveq #0,d4 ;back to row 0
	move.b d0,d5 ;set order
	bra .song_reset
	
.no_patt_break
	;is the pattern over?
	addq.b #1,d4
	cmp.b ss_patt_size(a4),d4
	bne .song_slot_set_row
	moveq #0,d4
	
	;is the song over?
	addq.b #1,d5
	cmp.b ss_song_size(a4),d5
	bne .song_not_over
	moveq #0,d5
.song_not_over
	
	
	;; reset song pattern stuff
.song_reset
	;get first track address
	lea kn_song_slot_track_index_tbl,a0
	move.l d7,d6
	lsl.l #1,d6
	move.w (a0,d6),d6
	lea (a6,d6.w),a5
	
	;step all song tracks
	move.l d7,d6
	lea kn_song_slot_size_tbl,a0
	move.b (a0,d6),d6
	subq.b #1,d6
.song_reset_loop:
	btst.b #T_FLG_ON,t_flags(a5)
	beq .next_song_reset
	
	move.w #2,t_patt_index(a5)
	move.b #1,t_dur_cnt(a5)
	
	cmp.b d5,d2 ;if current order < new order, DON'T reset song state
	blo .next_song_reset
	
	;see if we need to loop or not
	btst.b #SS_FLG_LOOP,ss_flags(a4)
	bne .song_yes_loop
	sf ss_flags(a4)
	bra .next_song_slot
	
.song_yes_loop
	
	;this is kind of a lame solution, but actually saving all the song state
	;would waste a lot of RAM.
	;this is enough for at least decent compatibility
	bset.b #T_FLG_KEYOFF,t_flags(a5)
	clr.w t_slide(a5)
	clr.b t_vol_slide(a5)
	
	move.b #$7f,d0
	cmpi.b #6+4,t_chn(a5)
	blo .reset_vol_fm
	move.b #$0f,d0
.reset_vol_fm
	move.b d0,t_vol(a5)
	
.next_song_reset:
	adda.l #t_size,a5
	dbra d6,.song_reset_loop
	
	
	;set song locations
.song_slot_set_order
	move.b d5,ss_order(a4)
.song_slot_set_row
	move.b d4,ss_row(a4)
.song_slot_set_speed
	move.b d3,ss_speed_cnt(a4)
	
.next_song_slot
	adda.l #ss_size,a4
	dbra d7,.song_slot_loop
	
	
	
	
	
	
	
	
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	;; main track loop
	
	lea k_chn_track(a6),a0
	move.w #AMT_CHANNELS-1,d7
	moveq #-1,d0
.clrchnloop:
	move.b d0,(a0)+
	dbra d7,.clrchnloop
	
	
	
	
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	lea k_tracks(a6),a5 ;track base pointer
	moveq #0,d7 ;track counter
.trackloop:
	btst.b #T_FLG_ON,t_flags(a5)
	beq .notrack
	
	;; get song slot pointer in a4
	lea kn_track_song_slot_index_tbl,a0
	move.l d7,d0
	lsl.l #1,d0
	move.w (a0,d0),d0
	lea (a6,d0.w),a4
	
	btst.b #SS_FLG_ON,ss_flags(a4)
	beq .notrack
	
	
	;;;;;;;;;;;;;;;;;;;;;;
	;; check timers
	move.b t_delay(a5),d0 ;any delay?
	beq .nowaitdelay
	cmp.b ss_speed_cnt(a4),d0
	bne .nonewsongdata
	clr.b t_delay(a5)
	bra .dosongdata
	
.nowaitdelay
	;if the speedcnt is 0, that means it overflowed and we should get a new row
	tst.b ss_speed_cnt(a4)
	bne .nonewsongdata
	
.newrow
	clr.b t_retrig(a5)
	clr.b t_cut(a5)
	
	
.nopattskip
	;has the duration expired?
	subq.b #1,t_dur_cnt(a5)
	bne .nonewsongdata
	
	;;;;;;;;;;;;;;;;;;;;;;
	;; get pattern base
.dosongdata
	movea.l t_seq_base(a5),a0
	moveq #0,d0
	move.b ss_order(a4),d0
	lsl.l #2,d0
	movea.l (a0,d0),a0
	movea.l a0,a3 ;pattern base in a3
	move.w t_patt_index(a5),d0
	adda.w d0,a0
	
	;;;;;;;;;;;;;;;;;;;;;;
	;; read pattern data
	moveq #0,d0
	move.b (a0)+,d0
	
	;;;;;;; delay
	cmpi.b #$fe,d0
	bne .noeffdelay
	move.b (a0)+,d0
	moveq #0,d1 ;get current row speed
	move.b ss_row(a4),d1
	andi.b #1,d1
	move.b (ss_speed1,a4,d1),d1
	cmp.b d1,d0
	bhs .effdelaytoobig
	move.b d0,t_delay(a5)
	bra .aftersongdata
.effdelaytoobig
	move.b (a0)+,d0
.noeffdelay
	
	;;;;;;; instrument
	cmpi.b #$fc,d0
	blo .noinstrset
	beq .shortinstr
	move.b (a0)+,d0
	lsl.l #8,d0
.shortinstr
	move.b (a0)+,d0
	;instrument number is now in d0.w
	
	cmp.w t_instr(a5),d0
	beq .afterinstrset
	move.w d0,t_instr(a5)
	
	;get instrument base
	ext.l d0
	lsl.l #2,d0
	lea kn_instrument_tbl,a1
	movea.l (a1,d0),a1
	
	;read macros
	
	move.b (a1)+,d4 ;instrument type
	moveq #0,d5
	move.b (a1)+,d5 ;macro amount
	
	if MACRO_SLOTS > 0
	
	moveq #0,d3 ;macro counter
	lea t_macros(a5),a2
	
.instrmacrosetloop:
	cmp.b d5,d3
	bhs .instrmacclear
	move.l (a1)+,(a2)+
	bra .nextinstrmac
.instrmacclear:
	move.l #0,(a2)+
.nextinstrmac
	move.w #0,(a2)+
	addq.b #1,d3
	cmpi.b #MACRO_SLOTS,d3
	bne .instrmacrosetloop
	
	endif
	
	
	;;read any extra data
	cmpi.b #2,d4
	blo .notsampleinstr
	bne .melosampleinstr
	
	;TODO: mapped sample instrument
	
	bra .setsampleinstr
	
	;melodic sample instrument
.melosampleinstr
	moveq #0,d0
	move.w (a1)+,d0
	lsl.l #2,d0
	lea kn_sample_tbl,a1
	move.l (a1,d0),d0
	ori.l #$03000000,d0
	
.setsampleinstr
	move.l d0,t_instr_sample(a5)
	bra .afterinstrset
	
	
.notsampleinstr
	clr.l t_instr_sample(a5)
	
	cmpi.b #1,d4 ;fm instrument
	bne .notfminstr
	
	;get fm patch address
	moveq #0,d0
	move.w (a1)+,d0
	lsl.l #2,d0
	lea kn_fm_tbl,a1
	movea.l (a1,d0),a1
	
	;get fm patch
	lea t_fm(a5),a2
	;fm data is (7*4)+2 = 30 bytes long
	rept 28/4
		move.l (a1)+,(a2)+
	endr
	move.w (a1)+,(a2)+
	
	bset.b #T_FLG_FM_UPDATE,t_flags(a5)
	
.notfminstr
	
	
	
.afterinstrset
	moveq #0,d0
	move.b (a0)+,d0
.noinstrset

	;;;;;;;;;;; volume
	cmpi.b #$fb,d0
	bne .novolset
	move.b (a0)+,t_vol(a5)
	
	move.b (a0)+,d0
.novolset
	
	;;;;;;;;;;;;;;;; effects
	
	;; 20xx psg noise
	cmpi.b #EFF_NOISE,d0
	bne .noeffnoise
	move.b (a0)+,t_psg_noise(a5)
	move.b (a0)+,d0
.noeffnoise

	;; 19xx global AR
	move.b #$e0,d2
	cmpi.b #EFF_AR,d0
	bne .noeffar
	move.b (a0)+,d0
	lea t_fm+fm_50(a5),a1
	rept 4
		move.b (a1),d1
		and.b d2,d1
		or.b d0,d1
		move.b d1,(a1)+
	endr
	bset.b #T_FLG_FM_UPDATE,t_flags(a5)
	move.b (a0)+,d0
.noeffar

	;; 1Axx-1Dxx operator AR
	moveq #3,d6
	move.b #EFF_AR4,d1
	lea t_fm+fm_50+3(a5),a1
.effarloop
	cmp.b d1,d0
	bne .noeffopar
	move.b (a0)+,d0
	move.b (a1),d1
	and.b d2,d1
	or.b d0,d1
	move.b d1,(a1)
	bset.b #T_FLG_FM_UPDATE,t_flags(a5)
	move.b (a0)+,d0
.noeffopar
	subq.b #1,d1
	subq.l #1,a1
	dbra d6,.effarloop
	
	;; 17xx dac mode
	cmpi.b #EFF_DAC,d0
	bne .noeffdac
	move.b (a0)+,t_dac_mode(a5)
	move.b (a0)+,d0
.noeffdac
	
	;; 16xy mult
	cmpi.b #EFF_MUL,d0
	bne .noeffmul
	move.b (a0)+,d0
	moveq #0,d1
	move.b d0,d1
	lsr.l #4,d1
	andi.b #$0f,d0
	lea t_fm+fm_30(a5,d1),a1
	move.b (a1),d1
	andi.b #$70,d1
	or.b d0,d1
	move.b d1,(a1)
	bset.b #T_FLG_FM_UPDATE,t_flags(a5)
	move.b (a0)+,d0
.noeffmul
	
	;; 12xx-15xx operator TL
	moveq #3,d6
	move.b #EFF_TL4,d1
	lea t_fm+fm_40+3(a5),a1
.efftlloop
	cmp.b d1,d0
	bne .noeffoptl
	move.b (a0)+,(a1)
	;bset.b #T_FLG_FM_UPDATE,t_flags(a5) ;tl is ALWAYS updated
	move.b (a0)+,d0
.noeffoptl
	subq.b #1,d1
	subq.l #1,a1
	dbra d6,.efftlloop
	
	;; 11xx feedback
	cmpi.b #EFF_FB,d0
	bne .noefffb
	move.b (a0)+,d0
	lsl.b #3,d0
	lea t_fm+fm_b0(a5),a1
	move.b (a1),d1
	andi.b #$c7,d1
	or.b d0,d1
	move.b d1,(a1)
	bset.b #T_FLG_FM_UPDATE,t_flags(a5)
	move.b (a0)+,d0
.noefffb
	
	;; 10xy lfo
	cmpi.b #EFF_LFO,d0
	bne .noefflfo
	move.b (a0)+,k_fm_lfo(a6)
	bset.b #T_FLG_FM_UPDATE,t_flags(a5)
	move.b (a0)+,d0
.noefflfo
	
	
	
	;;;;
	
	;; EExx sync
	cmpi.b #EFF_SYNC,d0
	bne .noeffsync
	move.b (a0)+,k_sync(a6)
	move.b (a0)+,d0
.noeffsync
	
	;; ECxx cut
	cmpi.b #EFF_CUT,d0
	bne .noeffcut
	move.b (a0)+,t_cut(a5)
	move.b (a0)+,d0
.noeffcut
	
	;; EBxx sample bank
	cmpi.b #EFF_SMPLBANK,d0
	bne .noeffsmplbank
	move.b (a0)+,t_smpl_bank(a5)
	move.b (a0)+,d0
.noeffsmplbank
	
	;; EAxx legato
	cmpi.b #EFF_LEGATO,d0
	bne .noefflegato
	move.b (a0)+,t_legato(a5)
	move.b (a0)+,d0
.noefflegato
	
	;; E5xx finetune
	cmpi.b #EFF_FINETUNE,d0
	bne .noefffinetune
	move.b (a0)+,t_finetune(a5)
	move.b (a0)+,d0
.noefffinetune
	
	;; E4xx fine vib depth
	cmpi.b #EFF_VIBDEPTH,d0
	bne .noeffvibdepth
	move.b (a0)+,t_vib_fine(a5)
	move.b (a0)+,d0
.noeffvibdepth
	
	;; E3xx vib mode
	cmpi.b #EFF_VIBMODE,d0
	bne .noeffvibmode
	move.b (a0)+,t_vib_mode(a5)
	move.b (a0)+,d0
.noeffvibmode
	
	;; E0xx arp speed
	cmpi.b #EFF_ARPTICK,d0
	bne .noeffarptick
	move.b (a0)+,t_arp_speed(a5)
	move.b (a0)+,d0
.noeffarptick
	
	
	
	;;;;;
	
	;; Cxx retrig
	cmpi.b #EFF_RETRIG,d0
	bne .noeffretrig
	move.b (a0)+,t_retrig(a5)
	clr.b t_retrig_cnt(a5)
	move.b (a0)+,d0
.noeffretrig
	
	
	;; Bxx/Dxx pattern break
	cmpi.b #EFF_PATTBREAK,d0
	bne .noeffpattbreak
	move.b (a0)+,d0
	cmpi.b #$ff,d0
	bne .effpattnonext
	move.b ss_order(a4),d0
	addq.b #1,d0
.effpattnonext
	cmp.b ss_song_size(a4),d0
	bhs .aftereffpattbreak
	
	move.b d0,ss_patt_break(a4)
	
.aftereffpattbreak
	move.b (a0)+,d0
.noeffpattbreak
	
	
	;; Axy volume slide
	cmpi.b #EFF_VOLSLIDE,d0
	bne .noeffvolslide
	move.b (a0)+,t_vol_slide(a5)
	move.b (a0)+,d0
.noeffvolslide
	
	;; Fxx speed 2
	cmpi.b #EFF_SPEED2,d0
	bne .noeffspeed2
	move.b (a0)+,ss_speed2(a4)
	move.b (a0)+,d0
.noeffspeed2
	
	;; 9xx speed 1
	cmpi.b #EFF_SPEED1,d0
	bne .noeffspeed1
	move.b (a0)+,ss_speed1(a4)
	move.b (a0)+,d0
.noeffspeed1
	
	;; 8xx panning
	cmpi.b #EFF_PANNING,d0
	bne .noeffpan
	move.b (a0)+,t_pan(a5)
	move.b (a0)+,d0
.noeffpan
	
	;; 4xy vibrato
	cmpi.b #EFF_VIBRATO,d0
	bne .noeffvib
	move.b (a0)+,t_vib(a5)
	move.b (a0)+,d0
.noeffvib
	
	;; 0xy arpeggio
	cmpi.b #EFF_ARP,d0
	bne .noeffarp
	move.b (a0)+,t_arp(a5)
	move.b (a0)+,d0
.noeffarp
	
	
	;; get pitch slide effect, we act on it later
	moveq #0,d5 ;code in d5
	cmpi.b #EFF_PORTAUP,d0
	blo .notenopitcheff
	move.b d0,d5
	moveq #0,d6 ;param in d6
	move.b (a0)+,d6
	move.b (a0)+,d0
.notenopitcheff
	
	
	
	
	;;;;;;;;;;; ok, we have the note column
	
	
	; get duration
	cmpi.b #$a0,d0
	bhs .recalldur
	tst.b d0
	bpl .normaldur
	
	move.b (a0)+,d1
	move.b d1,t_dur_save(a5)
	bra .setdur
	
.recalldur
	move.b t_dur_save(a5),d1
	bra .setdur
	
.normaldur
	moveq #0,d1
	move.b d0,d1
	lsr.b #5,d1
	moveq #0,d2
	move.b 0(a3),d2
	lsl.l #2,d2
	lea kn_duration_tbl,a1
	add.l d2,d1
	move.b (a1,d1),d1
	
.setdur:
	move.b d1,t_dur_cnt(a5)
	
	; get note
	andi.b #$1f,d0
	cmpi.b #$1e,d0
	blo .nonoteoff
	bne .blanknote
	
	bset.b #T_FLG_KEYOFF,t_flags(a5)
	
	;apparently in furnace keyoffs disable slides
	clr.w t_slide(a5)
	move.b #$ff,t_slide_target(a5)
	
	bra .blanknote
	
.nonoteoff:
	cmpi.b #$1d,d0
	bne .nolongnote
	move.b (a0)+,d0
	bra .gotnote
.nolongnote:
	add.b 1(a3),d0
.gotnote:
	
	;if there will be a toneportamento, DON'T reinit the note, just init a slide
	cmpi.b #EFF_TONEPORTA,d5
	beq .inittargetslide
	
	;if there will be another slide initialized this row, always reinit the note
	tst.b d5
	bne .noretarget
	
	;if there is already a targeted slide, just change the target
	cmpi.b #$ff,t_slide_target(a5)
	beq .noretarget
	move.w t_slide(a5),d6
	bpl .inittargetslide
	neg.w d6
	bra .inittargetslide
	
.noretarget
	;init note as normal
	move.b d0,t_note(a5)
	move.l a0,-(sp)
	bsr get_note_pitch
	move.l (sp)+,a0
	move.w d0,t_pitch(a5)
	
	btst.b #SS_FLG_CONT_VIB,ss_flags(a4)
	bne .noclrvib
	clr.b t_vib_phase(a5)
.noclrvib
	
	;if legato is on, just change the pitch
	tst.b t_legato(a5)
	bne .blanknote
	
	bclr.b #T_FLG_KEYOFF,t_flags(a5) ;undo keyoff
	bclr.b #T_FLG_CUT,t_flags(a5)
	bset.b #T_FLG_NOTE_RESET,t_flags(a5)
	
	
.blanknote:
	
	;any other pitch effects?
	tst.b d5
	beq .afternote
	moveq #0,d0
	cmpi.b #EFF_PORTADOWN,d5
	bls .effporta
	
.effnoteslide:
	move.b d6,d0
	andi.b #$f0,d6
	lsr.b #2,d6
	andi.b #$0f,d0
	cmpi.b #EFF_NOTEDOWN,d5
	bne .effnoteup
	neg.b d0
.effnoteup
	add.b t_note(a5),d0
	
.inittargetslide:
	;note is in d0, speed is in d6
	move.b d0,t_slide_target(a5)
	move.l a0,-(sp)
	bsr get_note_pitch
	move.l (sp)+,a0
	cmp.w t_pitch(a5),d0
	bhs .targetslideadd
	neg.w d6
.targetslideadd:
	move.w d6,t_slide(a5)
	
	bra .effsetslide
	
	
.effporta
	bne .effportaup
	neg.w d6
.effportaup
	move.b #$ff,t_slide_target(a5)
	cmpi.b #10,t_chn(a5)
	blo .effsetslide
	neg.w d6
.effsetslide
	move.w d6,t_slide(a5)
	
.afternote:
	
	
.aftersongdata:
	;prepare for next song data read
	suba.l a3,a0
	move.w a0,t_patt_index(a5)
	
	
.nonewsongdata:
	
	
	
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	;; cut: if cut <= speedcnt then keyoff
	move.b t_cut(a5),d0
	beq .nocut
	cmp.b ss_speed_cnt(a4),d0
	bhi .nocut
	bset.b #T_FLG_KEYOFF,t_flags(a5)
	clr.b t_cut(a5)
.nocut:
	
	
	
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	;; retrig
	move.b t_retrig(a5),d0
	beq .noretrig
	
	move.b t_retrig_cnt(a5),d1
	cmp.b d0,d1
	bne .stepretrig
	
	move.b #1,t_retrig_cnt(a5)
	bset.b #T_FLG_NOTE_RESET,t_flags(a5)
	
	bra .notereset
	
.stepretrig
	addq.b #1,t_retrig_cnt(a5)
.noretrig
	
	
	
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	;; handle note resets
	btst.b #T_FLG_NOTE_RESET,t_flags(a5)
	beq .nonotereset
	
.notereset
	;reset the macro volume to its default
	move.b #$7f,d0
	cmpi.b #6+4,t_chn(a5)
	blo .volfm
	move.b #$0f,d0
.volfm
	move.b d0,t_macro_vol(a5)
	
	;disable any macro-arp
	move.b #$ff,t_macro_arp(a5)
	
	if MACRO_SLOTS > 0
	
	;restart all macros
	lea t_macros+mac_index(a5),a1
	move.w #MACRO_SLOTS-1,d0
.notemacclear
	move.w #0,(a1)+
	addq.l #4,a1
	dbra d0,.notemacclear
	
	endif
	
.nonotereset:
	
	
	
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	;; handle macros
	if MACRO_SLOTS > 0
	
	move.b #$ff,t_macro_arp(a5)
	
	move.w #MACRO_SLOTS-1,d6
	lea t_macros(a5),a3
	
.macro_loop:
	movea.l (a3)+,a0
	moveq #0,d0
	move.w (a3)+,d0
	
	move.l a0,d1 ;pointer is null?
	beq .next_macro
	cmp.b 1(a0),d0 ;already reached end?
	bne .do_macro
	move.b 2(a0),d1 ;is there a loop?
	cmpi.b #$ff,d1
	beq .end_macro
	move.b d1,d0
.do_macro
	addq.l #4,a0 ;get actual macro value
	move.b (a0,d0),d1
	addq.w #1,d0 ;step index
	move.w d0,-2(a3)
	moveq #0,d0 ;get macro type
	move.b -4(a0),d0
	
	;perform macro action
	cmpi.b #$20,d0 ;fm operator macro?
	blo .not_fm_op_macro
	
	bset.b #T_FLG_FM_UPDATE,t_flags(a5)
	
	move.l d0,d2 ;operator index in d2
	andi.b #3,d2
	
	andi.b #$fc,d0 ;dispatch
	jmp .fm_op_macro_jmp_tbl-$20(pc,d0)
	
.fm_op_macro_jmp_tbl:
	;these MUST be .w, the jump routines rely on each entry being 4 bytes long
	bra.w .macro_fm_op_tl
	bra.w .macro_fm_op_ar
	bra.w .macro_fm_op_d1r
	bra.w .macro_fm_op_d2r
	bra.w .macro_fm_op_rr
	bra.w .macro_fm_op_d1l
	bra.w .macro_fm_op_rs
	bra.w .macro_fm_op_mul
	bra.w .macro_fm_op_dt
	bra.w .macro_fm_op_am
	bra.w .macro_fm_op_ssg_eg
	
	
.macro_fm_op_tl
	not.b d1
	andi.b #$7f,d1
	move.b d1,t_fm+fm_40(a5,d2)
	bra .next_macro
	
.macro_fm_op_ar
	lea t_fm+fm_50(a5,d2),a0
	andi.b #$1f,d1
	move.b (a0),d0
	andi.b #$c0,d0
	or.b d1,d0
	move.b d0,(a0)
	bra .next_macro
	
.macro_fm_op_d1r
	lea t_fm+fm_60(a5,d2),a0
	andi.b #$1f,d1
	move.b (a0),d0
	andi.b #$80,d0
	or.b d1,d0
	move.b d0,(a0)
	bra .next_macro
	
.macro_fm_op_d2r
	move.b d1,t_fm+fm_70(a5,d2)
	bra .next_macro
	
.macro_fm_op_rr
	lea t_fm+fm_80(a5,d2),a0
	andi.b #$0f,d1
	move.b (a0),d0
	andi.b #$f0,d0
	or.b d1,d0
	move.b d0,(a0)
	bra .next_macro
	
.macro_fm_op_d1l
	lea t_fm+fm_80(a5,d2),a0
	andi.b #$0f,d1
	lsl.b #4,d1
	move.b (a0),d0
	andi.b #$0f,d0
	or.b d1,d0
	move.b d0,(a0)
	bra .next_macro
	
.macro_fm_op_rs
	lea t_fm+fm_50(a5,d2),a0
	lsl.b #6,d1
	move.b (a0),d0
	andi.b #$1f,d0
	or.b d1,d0
	move.b d0,(a0)
	bra .next_macro
	
.macro_fm_op_mul
	lea t_fm+fm_30(a5,d2),a0
	andi.b #$0f,d1
	move.b (a0),d0
	andi.b #$70,d0
	or.b d1,d0
	move.b d0,(a0)
	bra .next_macro
	
.macro_fm_op_dt
	lea t_fm+fm_30(a5,d2),a0
	andi.w #7,d1
	move.b .fm_dt_map(pc,d1.w),d1
	move.b (a0),d0
	andi.b #$0f,d0
	or.b d1,d0
	move.b d0,(a0)
	bra .next_macro
.fm_dt_map
	db 7<<4, 6<<4, 5<<4, 0<<4, 1<<4, 2<<4, 3<<4, 4<<4
	
.macro_fm_op_am
	lea t_fm+fm_60(a5,d2),a0
	lsl.b #7,d1
	move.b (a0),d0
	andi.b #$1f,d0
	or.b d1,d0
	move.b d0,(a0)
	bra .next_macro
	
.macro_fm_op_ssg_eg
	move.b d1,t_fm+fm_90(a5,d2)
	bra .next_macro
	
	
.not_fm_op_macro
	cmpi.b #4,d0
	blo .not_fm_macro
	bset.b #T_FLG_FM_UPDATE,t_flags(a5)
.not_fm_macro
	
	lsl.l #2,d0 ;dispatch
	jmp .reg_macro_jmp_tbl(pc,d0)
	
.reg_macro_jmp_tbl
	;these MUST be .w, the jump routines rely on each entry being 4 bytes long
	bra.w .macro_vol
	bra.w .macro_arp
	bra.w .macro_arp_fixed
	bra.w .macro_noise
	
	bra.w .macro_fm_alg
	bra.w .macro_fm_fb
	bra.w .macro_fm_fms
	bra.w .macro_fm_ams
	
	
.macro_vol
	move.b d1,t_macro_vol(a5)
	bra .next_macro
	
.macro_arp
	add.b t_note(a5),d1
	move.b d1,t_macro_arp(a5)
	bra .next_macro
	
.macro_arp_fixed
	addi.b #5*12,d1 ;fixed arp notes are relative to C-0
	move.b d1,t_macro_arp(a5)
	bra .next_macro
	
.macro_noise
	move.b d1,t_psg_noise(a5)
	bra .next_macro
	

.macro_fm_alg
	lea t_fm+fm_b0(a5),a0
	andi.b #7,d1
	move.b (a0),d0
	andi.b #$38,d0
	or.b d1,d0
	move.b d0,(a0)
	bra .next_macro
	
.macro_fm_fb
	lea t_fm+fm_b0(a5),a0
	lsl.b #3,d1
	move.b (a0),d0
	andi.b #7,d0
	or.b d1,d0
	move.b d0,(a0)
	bra .next_macro
	
.macro_fm_fms
	lea t_fm+fm_b4(a5),a0
	andi.b #7,d1
	move.b (a0),d0
	andi.b #$30,d0
	or.b d1,d0
	move.b d0,(a0)
	bra .next_macro
	
.macro_fm_ams
	lea t_fm+fm_b4(a5),a0
	andi.b #3,d1
	lsl.b #4,d1
	move.b (a0),d0
	andi.b #7,d0
	or.b d1,d0
	move.b d0,(a0)
	bra .next_macro
	
	
	;macro is over!
.end_macro:	
	move.b (a0),d0 ;get macro type
	;on fixed arpeggios, disable the macro arp
	cmpi.b #2,d0
	bne .next_macro
	move.b #$ff,t_macro_arp(a5)
	
.next_macro
	dbra d6,.macro_loop
	
	endif
	
	
	
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	;; slides
	move.w t_slide(a5),d2
	beq .noslide
	
	btst.b #SS_FLG_PT_SLIDE,ss_flags(a4)
	beq .doslide
	tst.b ss_speed_cnt(a4)
	beq .noslide
	
.doslide
	move.w t_pitch(a5),d3
	
	cmpi.b #10,t_chn(a5)
	blo .slidefm
	
.slidepsg
	add.w d2,d3
	bra .afterslide
	
	;on fm we need to separate fnum and block, and keep the fnum in range
.slidefm
	move.w d3,d4
	andi.w #$07ff,d3
	andi.w #$f800,d4
	add.w d2,d3
	cmpi.w #C_FNUM,d3
	blo .slidefmdown
	cmpi.w #C_FNUM*2,d3
	blo .afterslidefm
	
.slidefmup
	cmpi.w #$3800,d4 ;if we are already on octave 7 don't push it up
	bhs .slidefmupclamp
	lsr.w #1,d3
	addi.w #$0800,d4
	bra .afterslidefm
	
.slidefmupclamp
	cmpi.w #$0800,d3 ;don't allow going above block 7 fnum $7ff
	blo .afterslidefm
	move.w #$3fff,d3
	bra .afterslide
	
.slidefmdownclamp
	tst.w d3 ;can't go below block 0 fnum 0
	bpl .afterslidefm
	moveq #0,d3
	bra .afterslide
	
.slidefmdown
	tst.w d4 ;if we are already on octave 0 don't push it down
	beq .slidefmdownclamp
	lsl.w #1,d3
	subi.w #$0800,d4
	
.afterslidefm
	or.w d4,d3
	
.afterslide
	;if the slide is targeted, check if we hit the note
	moveq #0,d0
	move.b t_slide_target(a5),d0
	cmpi.b #$ff,d0
	beq .setslide
	bsr get_note_pitch
	
	tst.w d2
	bmi .slidesub
.slideadd
	;we are adding. that means we hit the target when target <= pitch
	cmp.w d3,d0
	bls .hittarget
	bra .setslide
	
.slidesub
	;we are subtracting. that means we hit the target when target >= pitch
	cmp.w d3,d0
	blo .setslide
	
.hittarget
	move.b t_slide_target(a5),t_note(a5)
	move.b #$ff,t_slide_target(a5)
	move.w d0,d3
	clr.w t_slide(a5)
	
.setslide
	move.w d3,t_pitch(a5)
.noslide
	
	
	
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	;; arp
	tst.b t_arp(a5)
	beq .noarp
	
	btst.b #SS_FLG_PT_ARP,ss_flags(a4)
	beq .normalarp
	tst.b ss_speed_cnt(a4)
	bne .normalarp
	moveq #0,d0
	moveq #0,d1
	bra .setarp
	
.normalarp
	move.b t_arp_cnt(a5),d0
	move.b t_arp_phase(a5),d1
	
	addq.b #1,d0
	cmp.b t_arp_speed(a5),d0
	blo .setarpcnt
	moveq #0,d0
	addq.b #1,d1
	cmpi.b #3,d1
	blo .setarp
	moveq #0,d1
	
.setarp
	move.b d1,t_arp_phase(a5)
.setarpcnt
	move.b d0,t_arp_cnt(a5)
.noarp
	
	
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	;; vibrato
	move.b t_vib(a5),d0
	lsr.b #4,d0
	add.b d0,t_vib_phase(a5)
	
	
	
	
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	;; volume slide
	move.b t_vol_slide(a5),d0
	beq .novolslide
	
	move.w t_vol(a5),d1
	
	ext.w d0
	asl.w #6,d0
	bpl .volslideup
	
.volslidedown
	add.w d0,d1
	bcs .volslideset
	moveq #0,d1
	bra .volslideset
	
.volslideup
	;get max volume
	move.w #$7fc0,d2
	cmpi.b #6+4,t_chn(a5)
	blo .volslidefm
	move.w #$0fc0,d2
.volslidefm
	
	add.w d0,d1
	bcs .volslideclamp
	cmp.w d2,d1
	bls .volslideset
	
.volslideclamp
	move.w d2,d1
	
.volslideset
	move.w d1,t_vol(a5)
.novolslide
	
	
	
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	;; tell what channel we're on
	
	;if the track is cut, don't set it
	btst.b #T_FLG_CUT,t_flags(a5)
	bne .nosetchn
	
	rem ;disabled for now, error-prone
	;if any volume is 0, don't set it
	tst.b ss_volume(a4)
	beq .nosetchn
	tst.b t_vol(a5)
	beq .nosetchn
	erem
	
	;if a psg channel is keyed off, don't set it
	cmpi.b #10,t_chn(a5)
	blo .setchn
	btst.b #T_FLG_KEYOFF,t_flags(a5)
	bne .nosetchn
	
.setchn
	;set the channel
	lea k_chn_track(a6),a0
	moveq #0,d0
	move.b t_chn(a5),d0
	move.b d7,(a0,d0)
	
.nosetchn
	
	
	
	
	
.notrack:
	adda.l #t_size,a5
	addq.b #1,d7
	cmpi.b #AMT_TRACKS,d7
	blo .trackloop
	
	
	
	
	
	
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	;; fm channel output
	
	;request z80 bus
	lea Z80BUSREQ,a0
	move.w #$0100,d0
	move.w d0,(a0)
.fm_wait_z80
	cmp.w (a0),d0
	beq .fm_wait_z80
	
	
	lea Z80+$4000,a3 ;part 1 reg port
	
	
	macro fm_reg
		move.b \1,(a2)
	endm
	macro fm_reg_1
		move.b \1,(a3)
	endm
	
	macro fm_write
.fm_write_wait_\@:
		tst.b (a3)
		bmi .fm_write_wait_\@
		move.b \1,1(a2)
	endm
	macro fm_write_1
.fm_write_1_wait_\@:
		tst.b (a3)
		bmi .fm_write_1_wait_\@
		move.b \1,1(a3)
	endm
	
	
	;send lfo
	fm_reg_1 #$22
	fm_write_1 k_fm_lfo(a6)
	
	
	;;;;;;;;;;;;;;;;;; extd.chn3 out
	
	fm_reg_1 #$27
	;;first see if we should actually use it at all
	
	;if all extd.chn3 tracks are unoccupied use std.chn3
	lea k_chn_track+6(a6),a2
	move.b 0(a2),d0
	and.b 1(a2),d0
	and.b 2(a2),d0
	and.b 3(a2),d0
	bmi .no_fm_3_out
	
	;if the std.chn3 track is higher than any extd.chn3 track, do std.chn3
	move.b k_chn_track+2(a6),d0
	bmi .do_fm_3_out
	cmp.b 0(a2),d0
	bhi .no_fm_3_out
	cmp.b 1(a2),d0
	bhi .no_fm_3_out
	cmp.b 2(a2),d0
	bhi .no_fm_3_out
	cmp.b 3(a2),d0
	bhi .no_fm_3_out
	
.do_fm_3_out:
	;ok, turn on extd.chn3
	fm_write_1 #$40
	
	move.b #$fe,k_chn_track+2(a6)
	st k_fm_extd_chn3(a6)
	
	st k_prv_fm_track+2(a6)
	
	
	moveq #3,d7
.fm_3_out_loop:
	;ok, so this part is kind of stupid. usually, fm operators are sorted in
	;_register_ order. but i guess it would be confusing if the user is editing
	;instruments and he finds that 2 and 3 are swapped, so when dealing with extd.chn3
	;the channels are in operator order.
	
	; get operator index
	move.l d7,d6
	beq .fm_3_out_nofix
	cmpi.b #3,d6
	beq .fm_3_out_nofix
	eori.b #3,d6
.fm_3_out_nofix
	move.l d6,d5
	lsl.b #2,d6
	addq.b #2,d6
	; get keyoff bit
	addq.b #4,d5
	
	moveq #0,d0
	lea k_chn_track+6(a6),a0
	move.b (a0,d7),d0
	lea k_prv_fm_track+6(a6),a0
	lea (a0,d7),a0
	bpl .fm_3_out_go
.fm_3_out_kill:
	st (a0) ;set channel as killed
	
	;set TL of operator to $7f
	move.l d6,d0
	ori.b #$40,d0
	fm_reg_1 d0
	fm_write_1 #$ff
	
	;set RR of operator to $0f
	move.l d6,d0
	ori.b #$80,d0
	fm_reg_1 d0
	fm_write_1 #$ff
	
	;keyoff
	fm_reg_1 #$28
	move.b k_fm_prv_chn3_keyon(a6),d0
	bclr d5,d0
	move.b d0,k_fm_prv_chn3_keyon(a6)
	fm_write_1 d0
	
	bra .fm_3_out_next
	
.fm_3_out_go:

	move.l d0,d1
	lsl.l #1,d1
	
	;;get track address
	lea track_index_tbl,a5
	move.w (a5,d1),d2
	lea (a6,d2),a5
	
	;;get song slot address
	lea kn_track_song_slot_index_tbl,a4
	move.w (a4,d1),d2
	lea (a6,d2),a4
	
	;; if the track of the channel has changed and there is no note reset yet, kill the channel
	move.b (a0),d1
	cmp.b d0,d1
	beq .fm_3_no_check_change
	btst.b #T_FLG_NOTE_RESET,t_flags(a5)
	beq .fm_3_out_kill
	
	bset.b #T_FLG_FM_UPDATE,t_flags(a5)
	move.b d0,(a0)
.fm_3_no_check_change
	
	
	;; if the note will be reset, keyoff first
	btst.b #T_FLG_NOTE_RESET,t_flags(a5)
	beq .fm_3_out_no_reset
	fm_reg_1 #$28
	move.b k_fm_prv_chn3_keyon(a6),d0
	bclr d5,d0
	move.b d0,k_fm_prv_chn3_keyon(a6)
	fm_write_1 d0
.fm_3_out_no_reset
	
	
	bclr.b #T_FLG_FM_UPDATE,t_flags(a5)
	beq .fm_3_no_patch
	
	;; write fm patch (but just for this operator)
	lea t_fm(a5,d7),a0
	move.l d6,d0
	ori.b #$30,d0
	move.b #$10,d2
	
	;mul/dt
	fm_reg_1 d0
	fm_write_1 (a0)
	addq.l #8,a0
	add.b d2,d0
	add.b d2,d0
	
	;everything else that isn't TL
	rept 5
		fm_reg_1 d0
		fm_write_1 (a0)
		addq.l #4,a0
		add.b d2,d0
	endr
	
.fm_3_no_patch:
	
	;ONLY write the global fm params for the highest channel
	tst.b k_fm_extd_chn3(a6)
	bpl .fm_3_no_global
	move.b d7,k_fm_extd_chn3(a6)
	
	fm_reg_1 #$b2
	fm_write_1 t_fm+fm_b0(a5)
	fm_reg_1 #$b6
	move.b t_fm+fm_b4(a5),d0
	or.b t_pan(a5),d0
	fm_write_1 d0
.fm_3_no_global:
	
	;always write TL, since it could be changed at any moment by t_vol
	move.b t_vol(a5),d1
	move.b t_macro_vol(a5),d2
	not.b d1
	not.b d2
	andi.b #$7f,d1
	andi.b #$7f,d2
	add.b d2,d1
	
	move.l d6,d0
	ori.b #$40,d0
	add.b t_fm+fm_40(a5,d7),d1
	bcs .fm_3_tl
	bpl .fm_3_no_tl
.fm_3_tl
	move.b #$7f,d1
.fm_3_no_tl
	fm_reg_1 d0
	fm_write_1 d1

	
	
	;; write frequency
	bsr get_effected_pitch
	move.w d0,d1
	lsr.w #8,d1
	lea fm_chn3_freq_reg_tbl,a0
	move.b (a0,d7),d2
	fm_reg_1 d2
	fm_write_1 d1
	subq.b #4,d2
	fm_reg_1 d2
	fm_write_1 d0
	
	
	;;write key state
	move.b k_fm_prv_chn3_keyon(a6),d0
	bclr d5,d0
	btst.b #T_FLG_KEYOFF,t_flags(a5)
	bne .fm_3_out_keyedoff
	bset d5,d0
.fm_3_out_keyedoff
	move.b d0,k_fm_prv_chn3_keyon(a6)
	fm_reg_1 #$28
	fm_write_1 d0
	
	
	
.fm_3_out_next:
	dbra d7,.fm_3_out_loop
	
	
	bra .fm_normal_out
	
.no_fm_3_out:

	;no, turn off extd. chn3
	fm_write_1 #0

	
	;;;;;;;;;;;;;;;;;;; standard fm out
.fm_normal_out:
	lea 2(a3),a2 ;"current" part
	
	moveq #5,d7
.fm_out_loop:
	;get channel register offset in d6, and keyon offset in d5
	move.l d7,d6
	move.l d7,d5
	cmpi.b #3,d6
	blo .fm_no_offs
	subq.b #3,d6
	addq.b #1,d5
.fm_no_offs
	
	moveq #0,d0
	lea k_chn_track+0(a6),a0
	move.b (a0,d7),d0
	lea k_prv_fm_track(a6),a0
	lea (a0,d7),a0
	bpl .fm_out_go
	cmpi.b #$fe,d0 ;if this channel was disabled by extd.chn3, do nothing
	beq .fm_out_next
.fm_out_kill:
	st (a0) ;set channel as killed
	
	;set RRs of operators to $f
	move.l d6,d0
	ori.b #$80,d0
	move.b #$ff,d1
	fm_reg d0
	fm_write d1
	addq.b #4,d0
	fm_reg d0
	fm_write d1
	addq.b #4,d0
	fm_reg d0
	fm_write d1
	addq.b #4,d0
	fm_reg d0
	fm_write d1
	
	;key off
	fm_reg_1 #$28
	fm_write_1 d5
	
	;disable dac
	cmpi.b #5,d7
	bne .fm_kill_no_dac
	move.b #$ff,z80_base+z80_start_flag
.fm_kill_no_dac
	
	bra .fm_out_next
.fm_out_go

	move.l d0,d1
	lsl.l #1,d1
	
	;;get track address
	lea track_index_tbl,a5
	move.w (a5,d1),d2
	lea (a6,d2),a5
	
	;;get song slot address
	lea kn_track_song_slot_index_tbl,a4
	move.w (a4,d1),d2
	lea (a6,d2),a4
	
	;; if the track of the channel has changed and there is no note reset yet, kill the channel
	move.b (a0),d1
	cmp.b d0,d1
	beq .fm_no_check_change
	btst.b #T_FLG_NOTE_RESET,t_flags(a5)
	beq .fm_out_kill
	
	bset.b #T_FLG_FM_UPDATE,t_flags(a5)
	move.b d0,(a0)
.fm_no_check_change
	
	
	cmpi.b #2,d7
	bne .fm_out_no_reset_prv_chn3
	moveq #-1,d0
	move.l d0,k_prv_fm_track+6(a6)
.fm_out_no_reset_prv_chn3
	
	
	;; handle dac channel
	cmpi.b #5,d7
	bne .fm_out_no_dac
	
	move.l t_instr_sample(a5),d0
	bne .fm_out_instr_dac
	
	tst.b t_dac_mode(a5)
	beq .fm_out_disable_dac
	
	;write panning
	fm_reg #$b6
	fm_write t_pan(a5)
	
	btst.b #T_FLG_NOTE_RESET,t_flags(a5) ;if there is a new note, init the sample
	beq .fm_out_next
	
	; get sample index ((note % 12) + (samplebank * 12))
	moveq #0,d0
	moveq #0,d1
	move.b t_note(a5),d0
	move.b t_smpl_bank(a5),d1
	move.l d1,d2
	
	lsl.l #1,d0
	lea note_octave_tbl,a0
	move.b 1(a0,d0),d0
	andi.w #$00ff,d0
	
	lsl.l #3,d1
	lsl.l #2,d2
	add.l d2,d1
	
	add.l d1,d0
	
	;get sample map
	moveq #0,d1
	move.b k_chn_track+5(a6),d1
	lsl.l #1,d1
	lea kn_track_song_slot_index_tbl,a0
	move.w (a0,d1),d1
	lea (a6,d1.w),a0
	movea.l ss_sample_map(a0),a0
	
	;get sample id
	lsl.l #1,d0
	move.w (a0,d0),d0
	
	;get sample pointer
	lsl.l #2,d0
	lea kn_sample_tbl,a0
	movea.l (a0,d0),a0
	
	move.l (a0)+,d2 ;loop
	move.w (a0)+,d3 ;rate
	addq.l #2,a0 ;skip center rate
	
	move.l a0,d0 ;sample base
	tst.l d2
	bmi .fm_dac_no_add_loop
	add.l d0,d2
.fm_dac_no_add_loop:
	
	lea z80_base,a0
	move.b #1,z80_start_flag(a0)
	
	;set start pointer on z80 side
	lea z80_start_lo(a0),a0
	move.b d0,(a0)+
	lsr.l #8,d0
	move.b d0,d4
	ori.b #$80,d4
	move.b d4,(a0)+
	lsr.l #7,d0
	move.b d0,(a0)+
	
	;set loop pointer on z80 side
	tst.l d2
	bmi .fm_dac_no_loop
	move.b d2,(a0)+
	lsr.l #8,d2
	move.b d2,d4
	ori.b #$80,d4
	move.b d4,(a0)+
	lsr.l #7,d2
	move.b d2,(a0)+
	bra .fm_dac_after_loop
	
.fm_dac_no_loop
	clr.b (a0)+
	clr.b (a0)+
	clr.b (a0)+
.fm_dac_after_loop:
	
	;rate
	move.b d3,(a0)+
	lsr.l #8,d3
	move.b d3,(a0)
	
	
	
	bra .fm_out_next
	
	
.fm_out_instr_dac
	;; do instrument melodic sample
	
	;write panning
	fm_reg #$b6
	fm_write t_pan(a5)
	
	movea.l d0,a0
	move.l (a0)+,d2 ;loop
	addq.l #2,a0 ;skip rate
	move.w (a0)+,d3 ;center rate
	
	move.b #2,z80_start_flag(a0)
	btst.b #T_FLG_NOTE_RESET,t_flags(a5) ;if there is a new note, init the sample
	beq .fm_out_instr_dac_change_rate
	
	move.l a0,d0 ;sample base
	tst.l d2
	bmi .fm_instr_dac_no_add_loop
	add.l d0,d2
.fm_instr_dac_no_add_loop:
	
	lea z80_base,a0
	move.b #1,z80_start_flag(a0)
	
	;set start pointer on z80 side
	lea z80_start_lo(a0),a0
	move.b d0,(a0)+
	lsr.l #8,d0
	move.b d0,d4
	ori.b #$80,d4
	move.b d4,(a0)+
	lsr.l #7,d0
	move.b d0,(a0)+
	
	;set loop pointer on z80 side
	tst.l d2
	bmi .fm_instr_dac_no_loop
	move.b d2,(a0)+
	lsr.l #8,d2
	move.b d2,d4
	ori.b #$80,d4
	move.b d4,(a0)+
	lsr.l #7,d2
	move.b d2,(a0)+
	bra .fm_instr_dac_after_loop
	
.fm_instr_dac_no_loop
	clr.b (a0)+
	clr.b (a0)+
	clr.b (a0)+
.fm_instr_dac_after_loop:
	
	
	
	; get rate
.fm_out_instr_dac_change_rate
	move.w d3,-(sp)
	bsr get_effected_note
	move.w (sp)+,d3
	
	lea semitune_tbl-(12*4*2),a0
	lsl.l #1,d0
	move.w (a0,d0),d0
	mulu.w d3,d0
	lsr.l #8,d0
	lsr.l #3,d0
	
	lea z80_rate_lo+z80_base,a0
	move.b d0,(a0)+
	lsr.l #8,d0
	move.b d0,(a0)
	
	bra .fm_out_next
	
	
.fm_out_disable_dac:
	move.b #$ff,z80_base+z80_start_flag
	
.fm_out_no_dac:
	
	
	;; if the note will be reset, keyoff first
	btst.b #T_FLG_NOTE_RESET,t_flags(a5)
	beq .fm_out_no_reset
	fm_reg_1 #$28
	fm_write_1 d5
.fm_out_no_reset
	
	
	
	
	bclr.b #T_FLG_FM_UPDATE,t_flags(a5)
	beq .fm_out_no_patch
	
	;; write fm patch
	lea t_fm(a5),a0
	move.l d6,d0
	ori.b #$30,d0
	
	;mul/dt
	rept 4
		fm_reg d0
		fm_write (a0)+
		addq.b #4,d0
	endr
	
	;SKIP TL, we always write it
	addi.b #$10,d0
	addq.l #4,a0
	
	;everything else that isn't TL
	rept 5*4
		fm_reg d0
		fm_write (a0)+
		addq.b #4,d0
	endr
	
	;global
	addi.b #$10,d0
	fm_reg d0
	fm_write (a0)+
	
.fm_out_no_patch
	
	;panning
	move.l d6,d0
	ori.b #$b4,d0
	fm_reg d0
	move.b t_fm+fm_b4(a5),d1
	or.b t_pan(a5),d1
	fm_write d1
	
	
	;tl
	move.l d6,d0
	ori.b #$40,d0
	lea t_fm+fm_40(a5),a0
	
	move.b t_vol(a5),d2 ;first get the tl add value
	move.b t_macro_vol(a5),d3
	not.b d2
	not.b d3
	andi.b #$7f,d2
	andi.b #$7f,d3
	add.b d3,d2
	
	move.b t_fm+fm_b0(a5),d3 ;then get algorithm
	andi.b #$07,d3
	
	;tl 1
	move.b (a0)+,d1
	cmpi.b #7,d3
	blo .fm_no_tl1
	add.b d2,d1
	bcs .fm_tl1
	bpl .fm_no_tl1
.fm_tl1
	move.b #$7f,d1
.fm_no_tl1
	fm_reg d0
	fm_write d1
	addq.b #4,d0
	
	;tl 3
	move.b (a0)+,d1
	cmpi.b #5,d3
	blo .fm_no_tl3
	add.b d2,d1
	bcs .fm_tl3
	bpl .fm_no_tl3
.fm_tl3
	move.b #$7f,d1
.fm_no_tl3
	fm_reg d0
	fm_write d1
	addq.b #4,d0
	
	;tl 2
	move.b (a0)+,d1
	cmpi.b #4,d3
	blo .fm_no_tl2
	add.b d2,d1
	bcs .fm_tl2
	bpl .fm_no_tl2
.fm_tl2
	move.b #$7f,d1
.fm_no_tl2
	fm_reg d0
	fm_write d1
	addq.b #4,d0
	
	;tl 4
	move.b (a0)+,d1
	add.b d2,d1
	bcs .fm_tl4
	bpl .fm_no_tl4
.fm_tl4
	move.b #$7f,d1
.fm_no_tl4
	fm_reg d0
	fm_write d1
	
	
	
	
	;; write frequency
	bsr get_effected_pitch
	move.w d0,d1
	lsr.w #8,d1
	move.l d6,d2
	ori.b #$a4,d2
	fm_reg d2
	fm_write d1
	subq.b #4,d2
	fm_reg d2
	fm_write d0
	
	
	
	
	
	;; write keyoff state
	fm_reg_1 #$28
	move.l d5,d0
	btst.b #T_FLG_KEYOFF,t_flags(a5)
	bne .fm_out_no_keyon
	ori.b #$f0,d0
.fm_out_no_keyon
	fm_write_1 d0
	cmpi.b #2,d7
	bne .fm_out_no_set_chn3_keyon
	move.b d0,k_fm_prv_chn3_keyon(a6)
.fm_out_no_set_chn3_keyon
	
	
	
	
	
.fm_out_next
	;; are we done dealing with part 2?
	cmpi.b #3,d7
	bne .fm_out_no_flush_part2
	suba.l #2,a1
	suba.l #2,a2
	
.fm_out_no_flush_part2
	dbra d7,.fm_out_loop
	
	
	
	lea z80_base,a0
	fm_reg_1 z80_cur_reg(a0)
	
	move.w #0,Z80BUSREQ ;release the bus
	
	
	
	
	
	
	
	
	
	
	
	
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	;; psg channel output
	
	lea psg_volume_tbl,a2
	lea PSG,a3
	
	moveq #3,d7
.psg_out_loop
	;;get channel write mask
	move.b d7,d6
	lsl.b #5,d6
	
	;;is the channel occupied?
	moveq #0,d0
	lea k_chn_track+10(a6),a0
	move.b (a0,d7),d0
	bpl .psg_out_ok
.psg_out_kill:
	ori.b #$9f,d6
	move.b d6,(a3)
	bra .psg_out_next
.psg_out_ok:
	
	lsl.l #1,d0
	
	;;get track address
	lea track_index_tbl,a5
	move.w (a5,d0),d1
	lea (a6,d1),a5
	
	;;get song slot address
	lea kn_track_song_slot_index_tbl,a4
	move.w (a4,d0),d1
	lea (a6,d1),a4
	
	;;get volume
	moveq #0,d0
	move.b t_vol(a5),d0
	lsl.b #4,d0
	or.b t_macro_vol(a5),d0
	move.b (a2,d0),d0
	move.b ss_volume(a4),d1
	andi.b #$f0,d1
	or.b d1,d0
	move.b (a2,d0),d0
	not.b d0
	andi.b #$0f,d0
	or.b d6,d0
	ori.b #$90,d0
	move.b d0,(a3)
	
	;;; check noise channel
	cmpi.b #3,d7 ;if this is the noise we need to do some extra stuff
	bne .psg_not_noise
	
	;;setup noise register write value
	move.b #$e0,d1
	move.b t_psg_noise(a5),d0
	
	btst #0,d0 ;white noise?
	beq .psg_per_noise
	ori.b #4,d1
.psg_per_noise
	
	btst #1,d0 ;locked mode?
	bne .psg_noise_ext
	
	;locked mode, get the noise
	bsr get_effected_note
	lea note_octave_tbl,a0
	lsl.l #1,d0
	move.b 1(a0,d0),d0
	
	;note too high?
	cmpi.b #3,d0
	blo .psg_lock_set
	moveq #2,d0
.psg_lock_set
	
	eori.b #3,d0
	subq.b #1,d0
	or.b d0,d1
	
	bra .psg_set_noise
	
.psg_noise_ext
	ori.b #3,d1
	
.psg_set_noise
	cmp.b k_psg_prv_noise(a6),d1
	beq .no_psg_noise
	move.b d1,k_psg_prv_noise(a6)
	move.b d1,(a3)
.no_psg_noise
	
	;ok, we wrote the noise register, do we need to write period?
	not.b d1
	andi.b #3,d1
	bne .psg_out_next
	
	move.b #$40,d6 ;change channel id to tone2
	move.b #$ff,k_chn_track+10+2(a6) ;disable tone2 output
	
	;;; actually output period
.psg_not_noise
	bsr get_effected_pitch
	move.w #$3ff,d1
	cmp.w d1,d0
	bls .psg_out_no_3ff
	move.w d1,d0
.psg_out_no_3ff
	move.b d0,d1
	andi.b #$0f,d1
	or.b d6,d1
	ori.b #$80,d1
	move.b d1,(a3)
	lsr.w #4,d0
	move.b d0,(a3)
	
	
	
	
.psg_out_next
	dbra d7,.psg_out_loop
	
	
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	;; disable any force-keyon
	lea k_tracks(a6),a5
	moveq #AMT_TRACKS-1,d7
	
.unforce_keyon_loop
	bclr.b #T_FLG_NOTE_RESET,t_flags(a5)
	adda.l #t_size,a5
	dbra d7,.unforce_keyon_loop
	
	
	
	
	
	
	
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	movem.l (sp)+,d2-d7/a2-a6
	rts
	
	
	;;;;;;;;
	;; note in d0
	;; track in a5
	;; returns pitch in d0.w
get_note_pitch:
	lsl.l #1,d0
	cmpi.b #10,t_chn(a5)
	bhs .psg
	
.fm
	lea note_octave_tbl,a0
	lea (a0,d0),a0
	moveq #0,d0
	moveq #0,d1
	move.b (a0)+,d1 ;octave
	move.b (a0)+,d0 ;note
	
	lea fm_fnum_tbl,a0
	lsl.l #1,d0
	move.w (a0,d0),d0
	
	;if the octave is too high, left shift the fnum
	cmpi.b #8,d1
	bge .fm_high
	
	;if the octave is negative, right shift the fnum
	tst.b d1
	bmi .fm_neg
	
	lsl.l #8,d1
	lsl.l #3,d1
	or.w d1,d0
	rts
	
.fm_neg:
	neg.b d1
	lsr.w d1,d0
	rts
	
.fm_high:
	subq.l #7,d1 ;shift count
	lsl.l d1,d0
	
	cmpi.l #$800,d0 ;if it's too high, too bad
	bhs .fm_too_big
	
	ori.w #$3800,d0
	rts
	
.fm_too_big
	move.l #$3fff,d0
	rts
	
	
.psg
	lea psg_period_tbl,a0
	move.w (a0,d0),d0
	rts
	
	
	
	;;;;;;;;;;;;;;;;;;;
	;; track in a5
	;; this routine can't touch d1/d4-d7/a5-a6
	;; returns note in d0
get_effected_note:
	moveq #0,d0
	;if the macro is arpeggiating, use that as the base note
	move.b t_macro_arp(a5),d0
	cmpi.b #$ff,d0
	bne .usemacroarp
	
	;otherwise use the pattern base note
	move.b t_note(a5),d0
	
.usemacroarp
	move.b t_arp_phase(a5),d2 ;do we need to add anything to the note?
	beq .gotarp
	move.b t_arp(a5),d3 ;ok, which?
	subq.b #1,d2
	bne .arp2
	lsr.b #4,d3
.arp2:
	andi.b #$0f,d3
	add.b d3,d0
.gotarp
	
	rts
	
	
	
	;;;;;;;;;;;;;;;;;;;;
	;; song slot in a4
	;; track in a5
	;; this routine can't touch d5-d7/a2-a6
	;; returns pitch in d0
	;;;; NOTE: this whole routine is really slow due to all the multiplications.
	;;;; please contact me if you know how to make it faster without wasting a bunch of ROM
get_effected_pitch:
	;;; get song flags in d3
	
	move.b ss_flags(a4),d3
	
	
	;;; get total finetune in d4
	;;; every 256 finetune units is a semitone up
	
	move.b t_finetune(a5),d4
	ext.w d4
	ext.l d4
	btst #SS_FLG_LINEAR_PITCH,d3
	beq .no_e5_adj
	asl.l #1,d4 ;effect finetune takes 128 units to go up a semitone
.no_e5_adj
	
	;if vibrato is on, add it to the finetune
	tst.b t_vib(a5)
	beq .novib
	moveq #0,d0
	move.b t_vib_phase(a5),d0
	andi.b #$3f,d0
	lsl.l #1,d0
	lea vib_tbl,a0
	move.w (a0,d0),d0
	
	;check for vibrato mode 
	move.b t_vib_mode(a5),d2 ;mode 0, normal mode
	beq .addvib
	subq.b #1,d2
	bne .vibdown
	;mode 1, only up
.vibup:
	tst.w d0
	bpl .addvib
	bra .novib
	
	;mode 2, only down
.vibdown:
	tst.w d0
	bpl .novib
	
.addvib:

	;; scale vibrato based on depths
	tst.w d0
	beq .novib
	moveq #0,d1
	lea vib_scale_tbl,a0
	move.b t_vib_fine(a5),d1
	move.b t_vib(a5),d2
	andi.b #$0f,d2
	lsl.l #4,d1
	or.b d2,d1
	lsl.l #1,d1
	muls.w (a0,d1),d0
	asr.l #8,d0
	
	btst #SS_FLG_LINEAR_PITCH,d3
	bne .addvibft
	asr.l #3,d0
	
	;; add vibrato amplitude to finetune
.addvibft:
	add.l d0,d4
.novib:
	
	;;; get base pitch in d0
	
	;first, check if we should use the current pitch, or the arpeggio
	tst.w t_slide(a5) ;if sliding, ALWAYS use current pitch
	bne .curpitch
	cmpi.b #$ff,t_macro_arp(a5) ;if the macro is arpeggiating, use arpeggio
	bne .pitcharp
	tst.b t_arp(a5) ;if NOT arpeggiating, use current pitch
	beq .curpitch
	;otherwise use arpeggio
.pitcharp
	bsr get_effected_note
	
	;now actually get the arpeggiated note pitch
	bsr get_note_pitch
	bra .gotpitch
	
.curpitch:
	move.w t_pitch(a5),d0
	
.gotpitch:
	
	;;; we have the pitch, now apply finetune
	btst #SS_FLG_LINEAR_PITCH,d3
	beq .no_linear
	
	move.l d4,d3
	andi.l #$ff,d4 ;finetune in d4
	asr.l #8,d3 ;semitone difference in d3
	
	cmpi.b #10,t_chn(a5)
	bhs .psg
	
	;;; apply finetune to fm
.fm:
	move.w d0,d1
	andi.w #$f800,d1 ;octave in d1
	andi.l #$07ff,d0 ;fnum in d0
	
	;; if needed, fix the semitone
	tst.l d3
	beq .fm_no_semi
	lea semitune_tbl+(5*12*2),a0
	asl.l #1,d3
	mulu.w (a0,d3),d0
	lsr.l #8,d0
	lsr.l #3,d0
.fm_no_semi
	
	;; do any finetuning
	tst.l d4
	beq .fm_no_fine
	lea fm_finetune_tbl,a0
	lsl.l #1,d4
	move.w (a0,d4),d4
	mulu.w d0,d4
	clr.w d4 ;effectively divide by $10000
	swap d4
	add.l d4,d0
.fm_no_fine
	
	;; if the fnum is too high fix it and the octave
	move.l #$0800,d2
	cmp.l d2,d0
	blo .fm_done
.fm_fix
	sub.w d2,d1
	lsr.l #1,d0
	cmp.l d2,d0
	bhs .fm_fix
	
	
	;; done, return pitch
.fm_done:
	or.w d1,d0
	rts
	
	
	;;; apply finetune to psg
.psg:
	
	;; if needed, fix the semitone
	neg.l d3
	beq .psg_no_semi
	lea semitune_tbl+(5*12*2),a0
	asl.l #1,d3
	mulu.w (a0,d3),d0
	lsr.l #8,d0
	lsr.l #3,d0
.psg_no_semi

	;; do any finetuning
	tst.l d4
	beq .psg_no_fine
	lea psg_finetune_tbl,a0
	lsl.l #1,d4
	mulu.w (a0,d4),d0
	clr.w d0 ;effectively divide by $10000
	swap d0
.psg_no_fine
	
	rts
	
	
	
.no_linear
	cmpi.b #10,t_chn(a5)
	bhs .no_linear_psg
	
	;;;;
.no_linear_fm
	move.w d0,d1
	andi.w #$f800,d1 ;octave in d1
	andi.l #$07ff,d0 ;fnum in d0
	
	add.l d4,d0
	cmp.l #$0800,d0
	blt .nlfr
	
	;too high
	addi.w #$0800,d1
	lsr.l #1,d0
	
	
.nlfr
	or.w d1,d0
	rts
	
	;;;;
.no_linear_psg
	
	sub.l d4,d0
	rts
	
	
	
	
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	;; data
	
track_index_tbl:
	rept AMT_TRACKS
		dw t_size*REPTN + k_tracks
	endr
	
song_slot_index_tbl:
	rept AMT_SONG_SLOTS
		dw ss_size*REPTN + k_song_slots
	endr
	
	
;;; this stuff should be generated by convert.c later on
kn_track_song_slot_index_tbl:
	rept AMT_TRACKS
		dw k_song_slots
	endr

kn_song_slot_track_index_tbl:
	rept AMT_SONG_SLOTS
		dw k_tracks
	endr
	
kn_song_slot_size_tbl:
	db AMT_TRACKS
	align 1
	
	
	
fm_chn3_freq_reg_tbl:
	db $ad,$ac,$ae,$a6
	
C_FNUM = 644
fm_fnum_tbl:
	dw 644,681,722,765,810,858,910,964,1021,1081,1146,1214
	
	
	include "GENERATED-DATA.asm"
	
	
z80_blob:
	incbin "z80-player.bin"
z80_blob_end:

