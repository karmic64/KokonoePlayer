Z80 = $a00000
Z80BUSREQ = $a11100
Z80RESET = $a11200

PSG = $c00011
	
	
	

sound_reset::
	movem.l d0-d7/a0-a6,-(sp)	
	
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
.copy:
	move.b (a3)+,(a0)+
	dbra d7,.copy
	
	move.w d0,(a2) ;reset on
	move.w d0,(a1) ;busreq off

	moveq #$7f,d7
.waitreset:
	dbra d7,.waitreset
	move.w d1,(a2) ;reset off
	
	
	
	
	
	
	
	movem.l (sp)+,d0-d7/a0-a6
	rts
	
	
	
z80_blob:
	incbin "z80-player.bin"
z80_blob_end: