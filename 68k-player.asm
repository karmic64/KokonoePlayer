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
	
	
	; track
T_FLG_ON = 7
T_FLG_KEYOFF = 6
	
	
	clrso
t_flags so.b 1
	;bit 7 - 1: track on
	;bit 6 - 1: track keyed off
t_chn so.b 1

t_speed1 so.b 1
t_speed2 so.b 1
t_speed_cnt so.b 1
t_row so.b 1

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


;;;
t_macros so.b mac_size*MACRO_SLOTS

t_fm_op1 so.b 7
t_fm_op2 so.b 7
t_fm_op3 so.b 7
t_fm_op4 so.b 7
t_fm_global so.b 2

t_psg_vol so.b 1
	so.b 1

t_size = __SO
	
	
	
	;all vars
	clrso
k_tracks so.b t_size*AMT_TRACKS

k_chn_track so.b AMT_CHANNELS

k_psg_prv_noise so.b 1

KN_VAR_SIZE = __SO

	public KN_VAR_SIZE
	





	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	;;
	;; Note on calling conventions:
	;;	GCC expects the parameters to be pushed in REVERSE order, and then manually popped off once the subroutine exits.
	;;	Registers d0-d1/a0-a1 are safe to clobber, all others must be saved.
	;;	Any return value is returned in d0.
	
	
	
	
	
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	;; Reset routine
	;; Params:
	;;	long: ram base
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
	
	move.w #KN_VAR_SIZE/4 - 1, d7
.clearram:
	move.l d0,(a6)+
	dbra d7,.clearram
	
	
	
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
	move.b d4,t_speed1(a5)
	move.b d5,t_speed2(a5)
	move.b d5,t_speed_cnt(a5)
	subq.b #1,t_row(a5)
	move.b d3,t_song_size(a5)
	move.l a0,t_seq_base(a5)
	addq.b #1,t_dur_cnt(a5)
	addq.w #2,t_patt_index(a5)
	subq.w #1,t_instr(a5)
	
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
	movea.l a6,a5 ;track base pointer
	move.w #AMT_TRACKS-1,d7 ;track counter
.trackloop:
	btst.b #T_FLG_ON,t_flags(a5)
	beq .notrack
	
	
	
	;;;;;;;;;;;;;;;;;;;;;;
	;; check timers
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
	
	;;;;;;;;;;;;;;;;;;;;;;
	;; get pattern base
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
	
	;; delay
	cmpi.b #$fe,d0
	bne .noeffdelay
	;todo delay
	addq.b #1,d0
	move.b (a0)+,d0
.noeffdelay
	
	;; instrument
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
	move.b (a1)+,d5 ;instrument type
	moveq #0,d6
	move.b (a1)+,d6 ;macro amount
	moveq #0,d4 ;macro counter
	lea t_macros(a5),a2
	
	
.instrmacrosetloop:
	cmp.b d6,d4
	bhs .instrmacclear
	move.l (a1)+,(a2)+
	bra .nextinstrmac
.instrmacclear:
	move.l #0,(a2)+
.nextinstrmac
	move.w #0,(a2)+
	addq.b #1,d4
	cmpi.b #MACRO_SLOTS,d4
	bne .instrmacrosetloop
	
	
	;;read any extra data
	cmpi.b #1,d5 ;fm instrument
	bne .notfminstr
	
	;get fm patch address
	moveq #0,d0
	move.w (a1)+,d0
	lsl.l #2,d0
	lea kn_fm_tbl,a1
	movea.l (a1,d0),a1
	
	;get fm patch
	lea t_fm_op1(a5),a2
	;fm data is (7*4)+2 = 30 bytes long
	rept 28/4
		move.l (a1)+,(a2)+
	endr
	move.w (a1)+,(a2)+
	
.notfminstr
	
	
	
.afterinstrset
	move.b (a0)+,d0
.noinstrset

	;; volume
	cmpi.b #$fb,d0
	bne .novolset
	move.b (a0)+,t_vol(a5)
	
	move.b (a0)+,d0
.novolset
	
	;; for now skip effects
	bra .effdo
.nexteff
	move.b (a0)+,d0
	move.b (a0)+,d0
.effdo
	cmpi.b #$c0,d0
	bhs .nexteff
	
	;; ok, we have the note column
	
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
	
	bclr.b #T_FLG_KEYOFF,t_flags(a5) ;undo keyoff
	lea t_macros+mac_index(a5),a1 ;restart all macros
	move.w #MACRO_SLOTS-1,d0
.notemacclear
	move.w #0,(a1)+
	addq.l #4,a1
	dbra d0,.notemacclear
	
	
.blanknote:
	
	;; is the pattern over?
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
	;; todo fm channel output
	
	
	
	
	
	
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	;; psg channel output
	
	lea psg_period_tbl,a1
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
	moveq #0,d0
	move.b t_note(a5),d0
	lsl.l #1,d0
	move.w (a1,d0),d0
	move.b d0,d1
	andi.b #$0f,d1
	or.b d6,d1
	ori.b #$80,d1
	move.b d1,(a3)
	lsr.w #4,d0
	move.b d0,(a3)
	
	
	
	
.psg_out_next
	dbra d7,.psg_out_loop
	
	
	
	
	movem.l (sp)+,d2-d7/a2-a6
	rts
	
	
	
	
	
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	;; data
	
track_index_tbl:
	rept AMT_TRACKS
		dw t_size*REPTN + k_tracks
	endr
	
	
	include "GENERATED-DATA.asm"
	
	
z80_blob:
	incbin "z80-player.bin"
z80_blob_end:


	include "COMPILED-MODULE.asm"