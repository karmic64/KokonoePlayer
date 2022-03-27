Z80 = $a00000
Z80BUSREQ = $a11100
Z80RESET = $a11200

PSG = $c00011




AMT_TRACKS = 14

AMT_CHANNELS = 14


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
T_FLG_KEYOFF = 6
T_FLG_NOTE_RESET = 5
T_FLG_PATT_SKIP = 4
	
	
	clrso
t_flags so.b 1
t_chn so.b 1

t_song so.w 1

t_speed1 so.b 1
t_speed2 so.b 1
t_speed_cnt so.b 1
t_row so.b 1
t_delay so.b 1
t_legato so.b 1
t_cut so.b 1
t_smpl_bank so.b 1
t_retrig so.b 1
t_retrig_cnt so.b 1

t_seq_base so.l 1
t_order so.b 1
t_song_size so.b 1

t_dur_cnt so.b 1
t_dur_save so.b 1
t_patt_index so.w 1

;;;
t_instr so.w 1
t_note so.b 1

t_vol so.b 1
t_pan so.b 1
t_vol_slide so.b 1

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
t_macros so.b mac_size*MACRO_SLOTS

t_fm so.b fm_size

t_psg_vol so.b 1
t_psg_noise so.b 1

t_dac_mode so.b 1

	so.b 1

t_size = __SO
	
	
	;all vars
	clrso
k_tracks so.b t_size*AMT_TRACKS


k_chn_track so.b AMT_CHANNELS

k_psg_prv_noise so.b 1

k_fm_prv_chn3_keyon so.b 1
k_fm_extd_chn3 so.b 1
k_fm_lfo so.b 1


k_sync so.b 1

KN_VAR_SIZE = __SO

	public KN_VAR_SIZE
	


	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	;; effect enum
	setso $c0
EFF_PORTAUP so.b 1
EFF_PORTADOWN so.b 1
EFF_TONEPORTA so.b 1
EFF_NOTEUP so.b 1
EFF_NOTEDOWN so.b 1
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
EFF_SYNC so.b 1

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
	
	
	move.b #2,k_fm_prv_chn3_keyon(a6)
	
	
	movem.l (sp)+,d2-d7/a2-a6
	rts
	
	
	
	db "KokonoePlayer v0.01 coded by Karmic"
	align 1
	
	
	
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	;; Init routine
kn_init::
	cargs #(6+5+1)*4, .arg_music_base.l, .arg_song_id.l
	
	movem.l d2-d7/a2-a6,-(sp)
	
	movea.l .arg_music_base(sp),a6
	move.l .arg_song_id(sp),d0
	
	;;; get song base
	lea kn_song_tbl,a0
	lsl.l #2,d0
	movea.l (a0,d0),a0
	
	;;; get global song parameters
	move.b (a0)+,d4 ;speed 1
	move.b (a0)+,d5 ;speed 2
	move.b (a0)+,d6 ;pattern size
	addq.l #1,a0
	moveq #0,d7 ;tracks in song
	move.b (a0)+,d7
	moveq #0,d3 ;orders in song
	move.b (a0)+,d3
	
	movea.l a0,a1 ;channel arrangement table
	adda.l d7,a0
	
	;if the amount of tracks is odd, re-align the pointer
	move.b d7,d0
	lsr.b #1,d0
	bcc .noadjust
	addq.l #1,a0
.noadjust:

	
	;for each track, init its data
	subq.l #1,d7 ;adjust track counter for dbra
	movea.l a6,a5 ;track base pointer
	
.track:
	
	movea.l a5,a4
	move.l #t_size-1,d0
	moveq #0,d1
.trackclear:
	move.b d1,(a4)+
	dbra d0,.trackclear
	
	move.b #$c0,t_flags(a5)
	move.b (a1)+,d2
	move.b d2,t_chn(a5)
	move.w .arg_song_id+2(sp),t_song(a5)
	move.b d4,t_speed1(a5)
	move.b d5,t_speed2(a5)
	move.b d5,t_speed_cnt(a5)
	subq.b #1,t_row(a5)
	move.b d3,t_song_size(a5)
	move.l a0,t_seq_base(a5)
	addq.b #1,t_dur_cnt(a5)
	addq.w #2,t_patt_index(a5)
	subq.w #1,t_instr(a5)
	subq.b #1,t_slide_target(a5)
	move.b #$80,t_finetune(a5)
	move.b #$c0,t_pan(a5)
	
	;depending on channel type, init volume
	move.b #$7f,d0
	cmpi.b #6+4,d2
	blo .volfm
	move.b #$0f,d0
.volfm
	move.b d0,t_vol(a5)
	
	move.l d3,d0
	lsl.l #2,d0
	adda.l d0,a0
	adda.l #t_size,a5
	
	dbra d7,.track
	
	
	
	movem.l (sp)+,d2-d7/a2-a6
	rts
	
	
	
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	;; play routine
kn_play::
	cargs #(6+5+1)*4, .arg_music_base.l, .arg_song_id.l
	
	movem.l d2-d7/a2-a6,-(sp)
	
	movea.l .arg_music_base(sp),a6
	
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	
	lea k_chn_track(a6),a0
	move.w #AMT_CHANNELS-1,d7
	moveq #-1,d0
.clrchnloop:
	move.b d0,(a0)+
	dbra d7,.clrchnloop
	
	
	
	
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	lea k_tracks(a6),a5 ;track base pointer
	move.w #AMT_TRACKS-1,d7 ;track counter
.trackloop:
	btst.b #T_FLG_ON,t_flags(a5)
	beq .notrack
	
	
	
	;;;;;;;;;;;;;;;;;;;;;;
	;; check timers
	move.b t_delay(a5),d0 ;any delay?
	beq .nowaitdelay
	cmp.b t_speed_cnt(a5),d0
	bne .nonewsongdata
	clr.b t_delay(a5)
	bra .dosongdata
	
.nowaitdelay
	moveq #0,d0 ;get speed value for this row
	move.b t_row(a5),d0
	andi.b #1,d0
	move.b (t_speed1,a5,d0),d0
	cmp.b t_speed_cnt(a5),d0
	bne .nonewsongdata
	move.b #0,t_speed_cnt(a5)
	addq.b #1,t_row(a5)
	
	subq.b #1,t_dur_cnt(a5)
	bne .nonewsongdata
	
	clr.b t_retrig(a5)
	clr.b t_cut(a5)
	
	;;;;;;;;;;;;;;;;;;;;;;
	;; get pattern base
.dosongdata
	movea.l t_seq_base(a5),a0
	moveq #0,d0
	move.b t_order(a5),d0
	lsl.l #2,d0
	movea.l (a0,d0),a0
	movea.l a0,a4
	move.w t_patt_index(a5),d0
	adda.w d0,a0
	
	;; if this is the first byte of the pattern, reset the row counter
	cmpi.w #2,d0
	bne .noresetrow
	move.b #0,t_row(a5)
.noresetrow
	
	;;;;;;;;;;;;;;;;;;;;;;
	;; read pattern data
	move.b (a0)+,d0
	
	;;;;;;; delay
	cmpi.b #$fe,d0
	bne .noeffdelay
	move.b (a0)+,d0
	moveq #0,d1 ;get current row speed
	move.b t_row(a5),d1
	andi.b #1,d1
	move.b (t_speed1,a5,d1),d1
	cmp.b d1,d0
	bhs .effdelaytoobig
	move.b d0,t_delay(a5)
	bra .nopattend
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
	
	
	;;read any extra data
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
	
.notfminstr
	
	
	
.afterinstrset
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
	andi.b #$f0,d1
	or.b d0,d1
	move.b d1,(a1)
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
	move.b (a0)+,d0
.noefffb
	
	;; 10xy lfo
	cmpi.b #EFF_LFO,d0
	bne .noefflfo
	move.b (a0)+,k_fm_lfo(a6)
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
	move.b (a0)+,d0
.noeffretrig
	
	
	;; Bxx/Dxx pattern break
	cmpi.b #EFF_PATTBREAK,d0
	bne .noeffpattbreak
	move.b (a0)+,d0
	move.w t_song(a5),d1
	
	moveq #AMT_TRACKS-1,d6
	lea k_tracks(a6),a1
.effpattbreakloop
	cmp.w t_song(a1),d1
	bne .noeffpattbreaktrack
	bset.b #T_FLG_PATT_SKIP,t_flags(a1)
	
.noeffpattbreaktrack
	adda.l #t_size,a1
	dbra d6,.effpattbreakloop
	
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
	move.b (a0)+,t_speed2(a5)
	move.b (a0)+,d0
.noeffspeed2
	
	;; 9xx speed 1
	cmpi.b #EFF_SPEED1,d0
	bne .noeffspeed1
	move.b (a0)+,t_speed1(a5)
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
	
	;; 1xx 2xx 3xx E1xy E2xy slides
	cmpi.b #$c0,d0
	blo .noeffslides
	move.b (a0)+,d1
	move.w d1,t_slide(a5)
	
	
	move.b (a0)+,d0
.noeffslides
	
	
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
	move.b 0(a4),d2
	lsl.l #2,d2
	lea kn_duration_tbl,a1
	add.l d2,d1
	move.b (a1,d1),d1
	
.setdur:
	move.b d1,t_dur_cnt(a5)
	
	; get note
	andi.b #$1f,d0
	cmpi.b #$1f,d0
	beq .blanknote
	cmpi.b #$1e,d0
	bne .nonoteoff
	
	bset.b #T_FLG_KEYOFF,t_flags(a5)
	bra .blanknote
	
.nonoteoff:
	cmpi.b #$1d,d0
	bne .nolongnote
	move.b (a0)+,d0
	bra .gotnote
.nolongnote:
	add.b 1(a4),d0
.gotnote
	move.b d0,t_note(a5)
	bsr get_note_pitch
	move.w d0,t_pitch(a5)
	
	bclr.b #T_FLG_KEYOFF,t_flags(a5) ;undo keyoff
	bset.b #T_FLG_NOTE_RESET,t_flags(a5)
	lea t_macros+mac_index(a5),a1 ;restart all macros
	move.w #MACRO_SLOTS-1,d0
.notemacclear
	move.w #0,(a1)+
	addq.l #4,a1
	dbra d0,.notemacclear
	
	
.blanknote:
	
	;;;;;;;;;;;;;; is the pattern over?
	cmpi.b #$ff,(a0)
	bne .nopattend
	
	move.w #2,t_patt_index(a5)
	move.b t_order(a5),d0
	addq.b #1,d0
	cmp.b t_song_size(a5),d0
	bne .noresetsong
	moveq #0,d0
.noresetsong
	move.b d0,t_order(a5)
	bra .nonewsongdata
.nopattend:
	suba.l a4,a0
	move.w a0,t_patt_index(a5)
	
	
.nonewsongdata:
	addq.b #1,t_speed_cnt(a5)
	
	
	
	
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	;; handle macros
	move.w #MACRO_SLOTS-1,d6
	lea t_macros(a5),a4
	
.macro_loop:
	movea.l (a4)+,a0
	moveq #0,d0
	move.w (a4)+,d0
	
	move.l a0,d1 ;pointer is null?
	beq .next_macro
	cmp.b 1(a0),d0 ;already reached end?
	bne .do_macro
	move.b 2(a0),d1 ;is there a loop?
	cmpi.b #$ff,d1
	beq .next_macro
	move.b d1,d0
.do_macro
	addq.l #4,a0 ;get actual macro value
	move.b (a0,d0),d1
	addq.w #1,d0 ;step index
	move.w d0,-2(a4)
	moveq #0,d0 ;get macro type
	move.b -4(a0),d0
	
	;eventually do this properly, for now all we support is psg volume
	cmpi.b #0,d0
	bne .next_macro
	move.b d1,t_psg_vol(a5)
	
	
.next_macro
	dbra d6,.macro_loop
	
	
	
	
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	;; tell what channel we're on
	lea k_chn_track(a6),a0
	moveq #0,d0
	move.b t_chn(a5),d0
	move.b #AMT_TRACKS-1,d1
	sub.b d7,d1
	move.b d1,(a0,d0)
	
	
.notrack:
	adda.l #t_size,a5
	dbra d7,.trackloop
	
	
	
	
	
	
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
	lea 1(a3),a4 ;part 1 data port
	
	
	macro fm_reg
		move.b \1,(a1)
	endm
	macro fm_reg_1
		move.b \1,(a3)
	endm
	
	macro fm_write
.fm_write_wait_\@:
		tst.b (a2)
		bmi .fm_write_wait_\@
		move.b \1,(a2)
	endm
	macro fm_write_1
.fm_write_1_wait_\@:
		tst.b (a4)
		bmi .fm_write_1_wait_\@
		move.b \1,(a4)
	endm
	
	
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
	fm_write_1 #$55
	
	move.b #$fe,k_chn_track+2(a6)
	move.b #$ff,k_fm_extd_chn3(a6)
	
	
	moveq #3,d7
.fm_3_out_loop:
	; get operator index
	move.l d7,d6
	lsl.b #2,d6
	addq.b #2,d6
	; get keyoff bit
	move.l d7,d5
	addq.b #4,d5
	
	moveq #0,d0
	move.b (a2,d7),d0
	bpl .fm_3_out_go
.fm_3_out_kill:
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
	
	;;get track address
	lea track_index_tbl,a5
	lsl.l #1,d0
	move.w (a5,d0),d0
	lea (a6,d0),a5
	
	
	;; if the note will be reset, keyoff first
	btst.b #T_FLG_NOTE_RESET,t_flags(a5)
	beq .fm_3_out_no_reset
	fm_reg_1 #$28
	move.b k_fm_prv_chn3_keyon(a6),d0
	bclr d5,d0
	move.b d0,k_fm_prv_chn3_keyon(a6)
	fm_write_1 d0
.fm_3_out_no_reset
	
	
	;; write fm patch (but just for this operator)
	lea t_fm(a5,d7),a0
	move.l d6,d0
	ori.b #$30,d0
	move.b #$10,d2
	
	;mul/dt
	fm_reg_1 d0
	fm_write_1 (a0)
	addq.l #4,a0
	add.b d2,d0
	
	;tl
	moveq #0,d1
	move.b t_vol(a5),d1
	eori.b #$7f,d1
	add.b (a0),d1
	bpl .fm_3_no_tl
	move.b #$7f,d1
.fm_3_no_tl
	fm_reg_1 d0
	fm_write_1 d1
	addq.l #4,a0
	add.b d2,d0
	
	rept 5
		fm_reg_1 d0
		fm_write_1 (a0)
		addq.l #4,a0
		add.b d2,d0
	endr
	
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
	
	
	;; write frequency
	lea fm_chn3_freq_reg_tbl,a0
	move.b (a0,d7),d2
	fm_reg_1 d2
	fm_write_1 t_pitch(a5)
	subq.b #4,d2
	fm_reg_1 d2
	fm_write_1 t_pitch+1(a5)
	
	
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
	fm_write_1 #$15

	
	;;;;;;;;;;;;;;;;;;; standard fm out
.fm_normal_out:
	lea 2(a3),a1 ;"current" part reg port
	lea 3(a3),a2 ;"current" part data port
	
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
	bpl .fm_out_go
	cmpi.b #$fe,d0 ;if this channel was disabled by extd.chn3, do nothing
	beq .fm_out_next
.fm_out_kill:
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
	bra .fm_out_next
.fm_out_go
	
	;;get track address
	lea track_index_tbl,a5
	lsl.l #1,d0
	move.w (a5,d0),d0
	lea (a6,d0),a5
	
	
	
	;; if the note will be reset, keyoff first
	btst.b #T_FLG_NOTE_RESET,t_flags(a5)
	beq .fm_out_no_reset
	fm_reg_1 #$28
	fm_write_1 d5
.fm_out_no_reset
	
	
	
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
	
	;tl
	move.b t_vol(a5),d2 ;first get the tl add value
	eori.b #$7f,d2
	
	move.b t_fm+fm_b0(a5),d3 ;then get algorithm
	andi.b #$07,d3
	
	;tl 1
	move.b (a0)+,d1
	cmpi.b #7,d3
	blo .fm_no_tl1
	add.b d2,d1
.fm_no_tl1
	fm_reg d0
	fm_write d1
	addq.b #4,d0
	
	;tl 3
	move.b (a0)+,d1
	cmpi.b #5,d3
	blo .fm_no_tl3
	add.b d2,d1
.fm_no_tl3
	fm_reg d0
	fm_write d1
	addq.b #4,d0
	
	;tl 2
	move.b (a0)+,d1
	cmpi.b #4,d3
	blo .fm_no_tl2
	add.b d2,d1
.fm_no_tl2
	fm_reg d0
	fm_write d1
	addq.b #4,d0
	
	;tl 4
	move.b (a0)+,d1
	add.b d2,d1
	fm_reg d0
	fm_write d1
	addq.b #4,d0
	
	
	;everything else
	rept 5*4
		fm_reg d0
		fm_write (a0)+
		addq.b #4,d0
	endr
	
	;global
	addi.b #$10,d0
	fm_reg d0
	fm_write (a0)+
	addq.b #4,d0
	fm_reg d0
	move.b (a0)+,d1
	or.b t_pan(a5),d1
	fm_write d1
	
	
	
	
	;; write frequency
	move.l d6,d2
	ori.b #$a4,d2
	fm_reg d2
	fm_write t_pitch(a5)
	subq.b #4,d2
	fm_reg d2
	fm_write t_pitch+1(a5)
	
	
	
	
	
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
	
	
	
	move.w #0,Z80BUSREQ ;release the bus
	
	
	
	
	
	
	
	
	
	
	
	
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	;; psg channel output
	
	lea psg_volume_tbl,a2
	lea PSG,a3
	lea k_chn_track+10(a6),a4
	
	moveq #3,d7
.psg_out_loop
	;;get channel write mask
	move.b d7,d6
	lsl.b #5,d6
	
	;;is the channel occupied?
	moveq #0,d0
	move.b (a4,d7),d0
	bpl .psg_out_ok
.psg_out_kill:
	ori.b #$9f,d6
	move.b d6,(a3)
	bra .psg_out_next
.psg_out_ok:
	
	;;get track address
	lea track_index_tbl,a5
	lsl.l #1,d0
	move.w (a5,d0),d0
	lea (a6,d0),a5
	
	;;if track is keyed off stop here
	btst.b #T_FLG_KEYOFF,t_flags(a5)
	bne .psg_out_kill
	
	;;get volume
	moveq #0,d0
	move.b t_vol(a5),d0
	lsl.b #4,d0
	or.b t_psg_vol(a5),d0
	move.b (a2,d0),d0
	or.b d6,d0
	ori.b #$90,d0
	move.b d0,(a3)
	
	;;output the period
	cmpi.b #3,d7 ;if this is the noise we need to do some extra stuff
	bne .psg_out_per
	
	;temp stuff for now
	move.b #$e7,d0
	cmp.b k_psg_prv_noise(a6),d0
	beq .no_psg_noise
	move.b d0,k_psg_prv_noise(a6)
	move.b d0,(a3)
.no_psg_noise
	
	move.b #$40,d6
	move.b #$ff,2(a4)
	
	
.psg_out_per
	move.w #$3ff,d1
	move.w t_pitch(a5),d0
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
	lea note_octave_tbl,a1
	lea (a1,d0),a1
	moveq #0,d0
	moveq #0,d1
	move.b (a1)+,d1 ;octave
	move.b (a1)+,d0 ;note
	
	lea fm_fnum_tbl,a1
	lsl.l #1,d0
	move.w (a1,d0),d0
	
	;if the octave is negative, right shift the fnum
	tst.b d1
	bpl .fm_set
	neg.b d1
	lsr.w d1,d0
	bra .fm_set2
	
.fm_set
	lsl.l #8,d1
	lsl.l #3,d1
.fm_set2
	or.w d1,d0
	
	rts
	
.psg
	lea psg_period_tbl,a1
	move.w (a1,d0),d0
	rts
	
	
	
	
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	;; data
	
track_index_tbl:
	rept AMT_TRACKS
		dw t_size*REPTN + k_tracks
	endr
	
	
	
fm_chn3_freq_reg_tbl:
	db $ad,$ac,$ae,$a6
	
C_FNUM = 644
fm_fnum_tbl:
	dw 644,681,722,765,810,858,910,964,1021,1081,1146,1214
	dw 644*2 ;this is only used when finetuning between B and the next octave's C
	
	
	include "GENERATED-DATA.asm"
	
	
z80_blob:
	incbin "z80-player.bin"
z80_blob_end:


	include "COMPILED-MODULE.asm"