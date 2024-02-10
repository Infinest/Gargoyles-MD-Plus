; Constants: ---------------------------------------------------------------------------------
	MD_PLUS_OVERLAY_PORT:			equ $0003F7FA
	MD_PLUS_CMD_PORT:				equ $0003F7FE
	MD_PLUS_RESPONSE_PORT:			equ $0003F7FC

	_MUS_Castle:					equ	$3C ; 60 CUE: 01 Sound test: 04 | LOOP
	_MUS_Rookery:					equ	$3E ; 62 CUE: 02 Sound test: 05 | LOOP
	_MUS_Subway:					equ	$40 ; 64 CUE: 03 Sound test: 07 | LOOP
	_MUS_Titlepage:					equ	$41 ; 65 CUE: 04 Sound test: 03 | LOOP
	_MUS_Rooftops:					equ	$42 ; 66 CUE: 05 Sound test: 06 | LOOP
	_MUS_Continue:					equ	$43 ; 67 CUE: 06 Sound test: 10 | LOOP
	_MUS_Forge:						equ	$44 ; 68 CUE: 07 Sound test: 08 | LOOP
	_MUS_Boss:						equ	$45 ; 69 CUE: 08 Sound test: 00 | LOOP
	_MUS_GameOver:					equ	$46 ; 70 CUE: 09 Sound test: 01 | NO LOOP
	_MUS_Hammer:					equ	$47 ; 71 CUE: 10 Sound test: 02 | NO LOOP
	_MUS_StoryScreen:				equ	$48 ; 72 CUE: 11 Sound test: 09 | LOOP

	OFFSET_RESET_VECTOR:			equ $4
	OFFSET_GEMS_START_SONG:			equ $0C14A6
	OFFSET_GEMS_STOP_SONG:			equ $0C14C4
	OFFSET_GEMS_PAUSE_ALL:			equ $0C14E2
	OFFSET_GEMS_RESUME_ALL:			equ $0C14F6
	OFFSET_GEMS_STOP_ALL:			equ $0C150A
	OFFSET_GEMS_STD_SETUP:			equ $0C13B8

	RAM_CURRENTLY_PLAYING_MUSIC:	equ $FFF700

	RESET_VECTOR_ORIGINAL:			equ $00000200
; Overrides: ---------------------------------------------------------------------------------

	org		OFFSET_RESET_VECTOR
	dc.l	DETOUR_RESET_VECTOR

	org OFFSET_GEMS_START_SONG
	jmp	DETOUR_PLAY_COMMAND_HANDLER

	org OFFSET_GEMS_STOP_SONG
	jsr	DETOUR_STOP_SPECIFIC_COMMAND_HANDLER

	org OFFSET_GEMS_PAUSE_ALL
	jsr DETOUR_STOP_COMMAND_HANDLER

	org OFFSET_GEMS_RESUME_ALL
	jsr DETOUR_RESUME_COMMAND_HANDLER

	org OFFSET_GEMS_STOP_ALL
	jsr DETOUR_STOP_COMMAND_HANDLER

; Detours: -----------------------------------------------------------------------------------
	org $2FA080

DETOUR_PLAY_COMMAND_HANDLER
	movem.l	d1-d2,-(sp)
	jsr		IS_MUSIC_FUNCTION
	tst.b	d2
	beq		NOT_MUSIC
	move.b	d0,RAM_CURRENTLY_PLAYING_MUSIC			; Currently playing CDDA track needs to be remembered for to correctly handle
	move.b	#$3B,d1									; hammer music that plays temporarily. This is, because the game stops only
	cmpi.b	#_MUS_Subway,d0							; the hammer music after thelevel music has already been started up again.
	blt		.beneath_second_gap						; Also necessary because OFFSET_GEMS_STOP_SONG is used for SFX as well.
	addi.b	#$1,d1
.beneath_second_gap									; Logic for converting track ids, which have holes internally and don't start 
	cmpi.b #_MUS_Rookery,d0							; from 1, to numbers from 1 counting upwards for MegaSD play command.
	blt .beneath_first_gap
	addi.b #$1,d1
.beneath_first_gap
	sub.b	d1,d0
	ori.w	#$1100,d0
	cmpi.b	#$9,d0
	beq		.do_not_loop_track						; Tracks 9 (_MUS_Hammer) and 10 (_MUS_GameOver) should not loop
	cmpi.b	#$a,d0
	beq		.do_not_loop_track
	addi.w	#$0100,d0
.do_not_loop_track
	jsr		WRITE_MD_PLUS_FUNCTION
	movem.l	(sp)+,d1-d2
	rts
NOT_MUSIC
	movem.l	(sp)+,d1-d2
	jsr		OFFSET_GEMS_STD_SETUP
	jmp		OFFSET_GEMS_START_SONG+$6

DETOUR_STOP_SPECIFIC_COMMAND_HANDLER				; GEMS driver can stop specific tracks. We only want to stop CDDA playback
	cmp.b	RAM_CURRENTLY_PLAYING_MUSIC,d0			; if  the given id equals our last played CDDA music track.
	beq		DETOUR_STOP_COMMAND_HANDLER
	jmp		OFFSET_GEMS_STD_SETUP
DETOUR_STOP_COMMAND_HANDLER
	movem.l	d0,-(sp)	
	move.w	#$1300,d0
	jsr		WRITE_MD_PLUS_FUNCTION
	movem.l	(sp)+,d0
	jmp		OFFSET_GEMS_STD_SETUP

DETOUR_RESUME_COMMAND_HANDLER
	move.w	#$1400,d0
	jsr		WRITE_MD_PLUS_FUNCTION
	jmp		OFFSET_GEMS_STD_SETUP

DETOUR_RESET_VECTOR
	move.w	#$1300,d0								; Move MD+ stop command into d1
	jsr		WRITE_MD_PLUS_FUNCTION
	incbin	"intro.bin"								; Show MD+ intro screen
	jmp		RESET_VECTOR_ORIGINAL					; Return to game's original entry point

; Helper Functions: --------------------------------------------------------------------------

WRITE_MD_PLUS_FUNCTION:
	move.w  #$CD54,(MD_PLUS_OVERLAY_PORT)			; Open interface
	move.w  d0,(MD_PLUS_CMD_PORT)					; Send command to interface
	move.w  #$0000,(MD_PLUS_OVERLAY_PORT)			; Close interface
	rts

IS_MUSIC_FUNCTION:									; Walks through MUSIC_LIST to check whether the given id is a music track
	movem.l	a0,-(sp)
	lea		MUSIC_LIST,a0
.loop
	move.b	(a0)+,d2
	cmpi.b #$FF,d2
	beq		.leave_loop
	cmp.b	d0,d2
	beq		.is_music
	bra		.loop
.leave_loop
	move.b	#$0,d2
	movem.l	(sp)+,a0
	rts
.is_music
	move.b	#$1,d2
	movem.l	(sp)+,a0
	rts



MUSIC_LIST:
	dc.b _MUS_Castle, _MUS_Rookery, _MUS_Subway, _MUS_Titlepage, _MUS_Rooftops, _MUS_Continue, _MUS_Forge, _MUS_Boss, _MUS_GameOver, _MUS_Hammer, _MUS_StoryScreen, $FF