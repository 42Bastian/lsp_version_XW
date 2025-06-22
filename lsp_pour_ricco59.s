; LSP pour Ricco59

include	"jaguar.inc"


display_infos_debug				.equ			1
ob_list_courante			equ		((ENDRAM-$4000)+$2000)				; address of read list
nb_octets_par_ligne			equ		320
nb_lignes					equ		256

curseur_Y_min		.equ		8




CLEAR_BSS			.equ			1									; 1=efface toute la BSS jusqu'a la fin de la ram utilisÃ©e


;---------------------
; DSP
TEST_FIN_LSP_FORCE=0				; 1 = check de fin forcé
DSP_STACK_SIZE	equ	32	; long words
DSP_USP			equ		(D_ENDRAM-(4*DSP_STACK_SIZE))
DSP_ISP			equ		(DSP_USP-(4*DSP_STACK_SIZE))
LSP_DSP_Audio_frequence					.equ			15000				; real hardware needs lower sample frequencies than emulators
nb_bits_virgule_offset					.equ			11					; 11 ok DRAM/ 8 avec samples en ram DSP
DSP_DEBUG						.equ			0
LSP_avancer_module				.equ			1								; 1=incremente position dans le module
;DSP_diviseur_volume_module			.equ			2					; shift le volume
; DSP
;---------------------

VOLUME_MAX=760					; 760/2						; 255*3						; max=255*3
VOLUME_MAX__FX=760			; 760/2				;255*3				; max=255*3



.opt "~Oall"

.text

			.68000


	move.l		#$70007,G_END
	move.l		#$70007,D_END
	move.l		#INITSTACK-128, sp

	move.w		#%0000011011000111, VMODE			; 320x256
	move.w		#$100,JOYSTICK


; clear BSS
	.if			CLEAR_BSS=1
	lea			DEBUT_BSS,a0
	lea			FIN_RAM,a1
	moveq		#0,d0

boucle_clean_BSS:
	move.b		d0,(a0)+
	cmp.l		a0,a1
	bne.s		boucle_clean_BSS
; clear stack
	lea			INITSTACK-100,a0
	lea			INITSTACK,a1
	moveq		#0,d0

boucle_clean_BSS2:
	move.b		d0,(a0)+
	cmp.l		a0,a1
	bne.s		boucle_clean_BSS2

	.endif


					; OLP
					move.l	#$00000000,$600			; OLP = $600
					move.l	#$00000004,$604
					move.l	#$06000000,d0
					move.l	d0,OLP

;check ntsc ou pal:

	moveq		#0,d0
	move.w		JOYBUTS ,d0

	move.l		#26593900,frequence_Video_Clock			; PAL
	move.l		#415530,frequence_Video_Clock_divisee
	;move.l		#DUREE_MODE_CARAVAN*60*50,compteur_mode_caravan
	;move.l		#50,mode_caravan__nb_frames_par_seconde


	btst		#4,d0
	beq.s		jesuisenpal
jesuisenntsc:
	move.l		#26590906,frequence_Video_Clock			; NTSC
	move.l		#415483,frequence_Video_Clock_divisee
	;move.l		#DUREE_MODE_CARAVAN*60*50,compteur_mode_caravan
	;move.l		#60,mode_caravan__nb_frames_par_seconde
jesuisenpal:

	; ecrire volumes FX = 84
	move.l		#VOLUME_MAX__FX,d0
	move.l		d0,volume_max_fx_low
	; ecrire volumes musique = 82
	move.l		#VOLUME_MAX,d0
	move.l		d0,volume_max_music_low


	bsr			remplir_table_panning_stereo



; --------- DSP ------------
; copie du code DSP dans la RAM DSP
	move.l	#0,D_CTRL

	lea		YM_DSP_debut,A0
	lea		D_RAM,A1
	move.l	#YM_DSP_fin-DSP_base_memoire,d0
	lsr.l	#2,d0
	sub.l	#1,D0
boucle_copie_bloc_DSP:
	move.l	(A0)+,(A1)+
	dbf		D0,boucle_copie_bloc_DSP

	move.l		pointeur_module_music_data,a0
	move.l		pointeur_module_sound_bank,a1
	bsr			LSP_PlayerInit


	move.l		#0,DSP_LSP_replay_ON

; adaptation du code mono ou stereo
	bsr			DSP_code_bruitages_mono_ou_stereo






    bsr     InitVideo               	; Setup our video registers.

	jsr     copy_olist              	; use Blitter to update active list from shadow

	move.l	#ob_list_courante,d0					; set the object list pointer
	swap	d0
	move.l	d0,OLP

	lea		CLUT,a2
	move.l	#255-2,d7
	moveq	#0,d0

copie_couleurs:
	move.w	d0,(a2)+
	addq.l	#5,d0
	dbf		d7,copie_couleurs

	lea		CLUT+2,a2
	move.w	#$F00F,(a2)+

	move.l  #VBL,LEVEL0     	; Install 68K LEVEL0 handler
	move.w  a_vde,d0                	; Must be ODD
	sub.w   #16,d0
	ori.w   #1,d0
	move.w  d0,VI

	move.w  #%01,INT1                 	; Enable video interrupts 11101


	;and.w   #%1111100011111111,sr				; 1111100011111111 => bits 8/9/10 = 0
	and.w   #$f8ff,sr

; CLS
	moveq	#0,d0
	bsr		print_caractere

; init DSP

	lea		chaine_LSP,a0
	bsr		print_string

	move.l	#0,vbl_counter




















	move.l	#REGPAGE,D_FLAGS
	move.l	#DSP_routine_init_DSP,D_PC
	move.l	#DSPGO,D_CTRL

debut_attend_dsp_engine_ON:
	move.l		DSP_engine_ON,d0
	cmp.l		#1,d0
	bne.s		debut_attend_dsp_engine_ON

	bsr				LSP_init_son_silence__music

	move.l		#0,DSP_LSP_replay_ON



; début de la musique
	move.l		#1,DSP_LSP_replay_ON


	; balance le son du debut
	move.l		#sample_son_debut,d0
	move.l		#fin_sample_son_debut,d1
	move.l		#silence,d2
	move.l		#fin_silence,d3
	move.l		#8000<<nb_bits_virgule_offset,d4
	move.l		volume_max_fx_low.w,d5
	lsl.l		#6,d5
	move.l		d5,d7
	moveq		#0,d6			; channel 0
	bsr			LSP_Sample



main:
	bra.s			main



; ------------------------------------------------------
;---------------------------------------------------------------------------------------------------
;						routines
;---------------------------------------------------------------------------------------------------

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;
;; Procedure: InitVideo (same as in vidinit.s)
;;            Build values for hdb, hde, vdb, and vde and store them.
;;

InitVideo:
                movem.l d0-d6,-(sp)


				move.w	#-1,ntsc_flag
				move.l	#50,_50ou60hertz

				move.w  CONFIG,d0                ; Also is joystick register
                andi.w  #VIDTYPE,d0              ; 0 = PAL, 1 = NTSC
                beq     .palvals
				move.w	#1,ntsc_flag
				move.l	#60,_50ou60hertz


.ntscvals:		move.w  #NTSC_HMID,d2
                move.w  #NTSC_WIDTH,d0

                move.w  #NTSC_VMID,d6
                move.w  #NTSC_HEIGHT,d4

                bra     calc_vals
.palvals:
				move.w #PAL_HMID,d2
				move.w #PAL_WIDTH,d0

				move.w #PAL_VMID,d6
				move.w #PAL_HEIGHT,d4


calc_vals:
                move.w  d0,width
                move.w  d4,height
                move.w  d0,d1
                asr     #1,d1                   ; Width/2
                sub.w   d1,d2                   ; Mid - Width/2
                add.w   #4,d2                   ; (Mid - Width/2)+4
                sub.w   #1,d1                   ; Width/2 - 1
                ori.w   #$400,d1                ; (Width/2 - 1)|$400
                move.w  d1,a_hde
                move.w  d1,HDE
                move.w  d2,a_hdb
                move.w  d2,HDB1
                move.w  d2,HDB2
                move.w  d6,d5
                sub.w   d4,d5
                add.w   #16,d5
                move.w  d5,a_vdb
                add.w   d4,d6
                move.w  d6,a_vde

			    move.w  a_vdb,VDB
				move.w  a_vde,VDE


				move.l  #0,BORD1                ; Black border
                move.w  #0,BG                   ; Init line buffer to black
                movem.l (sp)+,d0-d6
                rts


;-----------------------------------------------------------------------------------
;--------------------------
; VBL

VBL:
                movem.l d0-d7/a0-a6,-(a7)

				.if		display_infos_debug=1
				move.l		vbl_counter,d0
				move.w		d0,BG					; debug pour voir si vivant
				.endif
				move.l		vbl_counter,d0
				move.w		d0,BG

                jsr     copy_olist              	; use Blitter to update active list from shadow

                addq.l	#1,vbl_counter

                move.w  #$101,INT1              	; Signal we're done
				move.w  #$0,INT2
.exit:
                movem.l (a7)+,d0-d7/a0-a6
                rte

; ---------------------------------------
; print pads status
; Pads : mask = xxxxxxCx xxBx2580 147*oxAP 369#RLDU
print_pads_status:

	move.l		DSP_pad1,d1
	lea			string_pad_status,a0
	move.l		#31,d6

.boucle:
	moveq		#0,d0
	btst.l		d6,d1
	beq.s		.print_space
	move.b		(a0)+,d0
	bsr			print_caractere
	bra.s		.ok
.print_space:
	move.b		#'.',d0
	bsr			print_caractere
	lea			1(a0),a0
.ok:
	dbf			d6,.boucle

; ligne suivante
	moveq		#10,d0
	bsr			print_caractere

print_pads_status_pad2:
; pad2
	move.l		DSP_pad2,d1
	lea			string_pad_status,a0
	move.l		#31,d6

.boucle2:
	moveq		#0,d0
	btst.l		d6,d1
	beq.s		.print_space2
	move.b		(a0)+,d0
	bsr			print_caractere
	bra.s		.ok2
.print_space2:
	move.b		#'.',d0
	bsr			print_caractere
	lea			1(a0),a0
.ok2:
	dbf			d6,.boucle2

; ligne suivante
	moveq		#10,d0
	bsr			print_caractere


	rts

string_pad_status:		dc.b		"......CE..BD2580147*oFAp369#RLDU"
		even

; ---------------------------------------
; imprime une chaine terminée par un zéro
; a0=pointeur sur chaine
print_string:
	movem.l d0-d7/a0-a6,-(a7)

print_string_boucle:
	moveq	#0,d0
	move.b	(a0)+,d0
	cmp.w	#0,d0
	bne.s	print_string_pas_fin_de_chaine
	movem.l (a7)+,d0-d7/a0-a6
	rts
print_string_pas_fin_de_chaine:
	bsr		print_caractere
	bra.s	print_string_boucle

; ---------------------------------------
; imprime un nombre HEXA de 2 chiffres
print_nombre_hexa_2_chiffres:
	movem.l d0-d7/a0-a6,-(a7)
	lea		convert_hexa,a0
	move.l		d0,d1
	divu		#16,d0
	and.l		#$F,d0			; limite a 0-15
	move.l		d0,d2
	mulu		#16,d2
	sub.l		d2,d1
	move.b		(a0,d0.w),d0
	bsr			print_caractere
	move.l		d1,d0
	and.l		#$F,d0			; limite a 0-15
	move.b		(a0,d0.w),d0
	bsr			print_caractere
	movem.l (a7)+,d0-d7/a0-a6
	rts

convert_hexa:
	dc.b		48,49,50,51,52,53,54,55,56,57
	dc.b		65,66,67,68,69,70
	even

; ---------------------------------------
; imprime un nombre de 2 chiffres
print_nombre_2_chiffres:
	movem.l d0-d7/a0-a6,-(a7)
	move.l		d0,d1
	divu		#10,d0
	and.l		#$FF,d0
	move.l		d0,d2
	mulu		#10,d2
	sub.l		d2,d1
	cmp.l		#0,d0
	beq.s		.zap
	add.l		#48,d0
	bsr			print_caractere
.zap:
	move.l		d1,d0
	add.l		#48,d0
	bsr			print_caractere
	movem.l (a7)+,d0-d7/a0-a6
	rts

; ---------------------------------------
; imprime un nombre de 3 chiffres
print_nombre_3_chiffres:
	movem.l d0-d7/a0-a6,-(a7)
	move.l		d0,d1

	divu		#100,d0
	and.l		#$FF,d0
	move.l		d0,d2
	mulu		#100,d2
	sub.l		d2,d1
	cmp.l		#0,d0
	beq.s		.zap
	add.l		#48,d0
	bsr			print_caractere
.zap:
	move.l		d1,d0
	divu		#10,d0
	and.l		#$FF,d0
	move.l		d0,d2
	mulu		#10,d2
	sub.l		d2,d1
	add.l		#48,d0
	bsr			print_caractere

	move.l		d1,d0
	add.l		#48,d0
	bsr			print_caractere
	movem.l (a7)+,d0-d7/a0-a6
	rts


; ---------------------------------------
; imprime un nombre de 2 chiffres , 00
print_nombre_2_chiffres_force:
	movem.l d0-d7/a0-a6,-(a7)
	move.l		d0,d1
	divu		#10,d0
	and.l		#$FF,d0
	move.l		d0,d2
	mulu		#10,d2
	sub.l		d2,d1
	add.l		#48,d0
	bsr			print_caractere
	move.l		d1,d0
	add.l		#48,d0
	bsr			print_caractere
	movem.l (a7)+,d0-d7/a0-a6
	rts

; ---------------------------------------
; imprime un nombre de 4 chiffres HEXA
print_nombre_hexa_4_chiffres:
	movem.l d0-d7/a0-a6,-(a7)
	move.l		d0,d1
	lea		convert_hexa,a0

	divu		#4096,d0
	and.l		#$FF,d0
	move.l		d0,d2
	mulu		#4096,d2
	sub.l		d2,d1
	move.b		(a0,d0.w),d0
	bsr			print_caractere

	move.l		d1,d0
	divu		#256,d0
	and.l		#$FF,d0
	move.l		d0,d2
	mulu		#256,d2
	sub.l		d2,d1
	move.b		(a0,d0.w),d0
	bsr			print_caractere


	move.l		d1,d0
	divu		#16,d0
	and.l		#$FF,d0
	move.l		d0,d2
	mulu		#16,d2
	sub.l		d2,d1
	move.b		(a0,d0.w),d0
	bsr			print_caractere
	move.l		d1,d0
	move.b		(a0,d0.w),d0
	bsr			print_caractere
	movem.l (a7)+,d0-d7/a0-a6
	rts

; ---------------------------------------
; imprime un nombre de 6 chiffres HEXA ( pour les adresses memoire)
print_nombre_hexa_6_chiffres:
	movem.l d0-d7/a0-a6,-(a7)

	move.l		d0,d1
	lea		convert_hexa,a0

	move.l		d1,d0
	swap		d0
	and.l		#$F0,d0
	divu		#16,d0
	and.l		#$F,d0
	move.b		(a0,d0.w),d0
	and.l		#$FF,d0
	bsr			print_caractere

	move.l		d1,d0
	swap		d0
	and.l		#$F,d0
	move.b		(a0,d0.w),d0
	and.l		#$FF,d0
	bsr			print_caractere

	and.l		#$FFFF,d1
	move.l		d1,d0
	divu		#4096,d0
	and.l		#$FF,d0
	move.l		d0,d2
	mulu		#4096,d2
	sub.l		d2,d1
	move.b		(a0,d0.w),d0
	bsr			print_caractere

	move.l		d1,d0
	divu		#256,d0
	and.l		#$FF,d0
	move.l		d0,d2
	mulu		#256,d2
	sub.l		d2,d1
	move.b		(a0,d0.w),d0
	bsr			print_caractere


	move.l		d1,d0
	divu		#16,d0
	and.l		#$FF,d0
	move.l		d0,d2
	mulu		#16,d2
	sub.l		d2,d1
	move.b		(a0,d0.w),d0
	bsr			print_caractere
	move.l		d1,d0
	move.b		(a0,d0.w),d0
	bsr			print_caractere
	movem.l (a7)+,d0-d7/a0-a6
	rts

; ---------------------------------------
; imprime un nombre de 8 chiffres HEXA ( pour les adresses memoire et les données en 16:16)
print_nombre_hexa_8_chiffres:
	movem.l d0-d7/a0-a6,-(a7)

	move.l		d0,d1
	lea		convert_hexa,a0

	move.l		d1,d0
	swap		d0
	and.l		#$F000,d0
	divu		#4096,d0
	and.l		#$F,d0
	move.b		(a0,d0.w),d0
	and.l		#$FF,d0
	bsr			print_caractere



	move.l		d1,d0
	swap		d0
	and.l		#$F00,d0
	divu		#256,d0
	and.l		#$F,d0
	move.b		(a0,d0.w),d0
	and.l		#$FF,d0
	bsr			print_caractere


	move.l		d1,d0
	swap		d0
	and.l		#$F0,d0
	divu		#16,d0
	and.l		#$F,d0
	move.b		(a0,d0.w),d0
	and.l		#$FF,d0
	bsr			print_caractere

	move.l		d1,d0
	swap		d0
	and.l		#$F,d0
	move.b		(a0,d0.w),d0
	and.l		#$FF,d0
	bsr			print_caractere

	and.l		#$FFFF,d1
	move.l		d1,d0
	divu		#4096,d0
	and.l		#$FF,d0
	move.l		d0,d2
	mulu		#4096,d2
	sub.l		d2,d1
	move.b		(a0,d0.w),d0
	bsr			print_caractere

	move.l		d1,d0
	divu		#256,d0
	and.l		#$FF,d0
	move.l		d0,d2
	mulu		#256,d2
	sub.l		d2,d1
	move.b		(a0,d0.w),d0
	bsr			print_caractere


	move.l		d1,d0
	divu		#16,d0
	and.l		#$FF,d0
	move.l		d0,d2
	mulu		#16,d2
	sub.l		d2,d1
	move.b		(a0,d0.w),d0
	bsr			print_caractere
	move.l		d1,d0
	move.b		(a0,d0.w),d0
	bsr			print_caractere
	movem.l (a7)+,d0-d7/a0-a6
	rts


; ---------------------------------------
; imprime un nombre de 4 chiffres
print_nombre_4_chiffres:
	movem.l d0-d7/a0-a6,-(a7)
	move.l		d0,d1

	divu		#1000,d0
	and.l		#$FF,d0
	move.l		d0,d2
	mulu		#1000,d2
	sub.l		d2,d1
	add.l		#48,d0
	bsr			print_caractere

	move.l		d1,d0
	divu		#100,d0
	and.l		#$FF,d0
	move.l		d0,d2
	mulu		#100,d2
	sub.l		d2,d1
	add.l		#48,d0
	bsr			print_caractere


	move.l		d1,d0
	divu		#10,d0
	and.l		#$FF,d0
	move.l		d0,d2
	mulu		#10,d2
	sub.l		d2,d1
	add.l		#48,d0
	bsr			print_caractere
	move.l		d1,d0
	add.l		#48,d0
	bsr			print_caractere
	movem.l (a7)+,d0-d7/a0-a6
	rts

; ---------------------------------------
; imprime un nombre de 5 chiffres
print_nombre_5_chiffres:
	movem.l d0-d7/a0-a6,-(a7)
	move.l		d0,d1

	divu		#10000,d0
	and.l		#$FF,d0
	move.l		d0,d2
	mulu		#10000,d2
	sub.l		d2,d1
	add.l		#48,d0
	bsr			print_caractere

	move.l		d1,d0
	divu		#1000,d0
	and.l		#$FF,d0
	move.l		d0,d2
	mulu		#1000,d2
	sub.l		d2,d1
	add.l		#48,d0
	bsr			print_caractere

	move.l		d1,d0
	divu		#100,d0
	and.l		#$FF,d0
	move.l		d0,d2
	mulu		#100,d2
	sub.l		d2,d1
	add.l		#48,d0
	bsr			print_caractere


	move.l		d1,d0
	divu		#10,d0
	and.l		#$FF,d0
	move.l		d0,d2
	mulu		#10,d2
	sub.l		d2,d1
	add.l		#48,d0
	bsr			print_caractere
	move.l		d1,d0
	add.l		#48,d0
	bsr			print_caractere
	movem.l (a7)+,d0-d7/a0-a6
	rts


; -----------------------------
; copie un caractere a l ecran
; d0.w=caractere

print_caractere:
	movem.l d0-d7/a0-a6,-(a7)



	cmp.b	#00,d0
	bne.s	print_caractere_pas_CLS
	move.l	#ecran1,A1_BASE			; = DEST
	move.l	#$0,A1_PIXEL
	move.l	#PIXEL16|XADDPHR|PITCH1,A1_FLAGS
	move.l	#ecran1+320*100,A2_BASE			; = source
	move.l	#$0,A2_PIXEL
	move.l	#PIXEL16|XADDPHR|PITCH1,A2_FLAGS

	move.w	#$00,B_PATD


	moveq	#0,d0
	move.w	#nb_octets_par_ligne,d0
	lsr.w	#1,d0
	move.w	#nb_lignes,d1
	mulu	d1,d0
	swap	d0
	move.w	#1,d0
	swap	d0
	;move.w	#65535,d0
	move.l	d0,B_COUNT
	move.l	#LFU_REPLACE|SRCEN|PATDSEL,B_CMD


	movem.l (a7)+,d0-d7/a0-a6
	rts

print_caractere_pas_CLS:

	cmp.b	#10,d0
	bne.s	print_caractere_pas_retourchariot
	move.w	#0,curseur_x
	add.w	#8,curseur_y
	movem.l (a7)+,d0-d7/a0-a6
	rts

print_caractere_pas_retourchariot:
	cmp.b	#09,d0
	bne.s	print_caractere_pas_retourdebutligne
	move.w	#0,curseur_x
	movem.l (a7)+,d0-d7/a0-a6
	rts

print_caractere_pas_retourdebutligne:
	cmp.b	#08,d0
	bne.s	print_caractere_pas_retourdebutligneaudessus
	move.w	#0,curseur_x
	sub.w	#8,curseur_y
	movem.l (a7)+,d0-d7/a0-a6
	rts


print_caractere_pas_retourdebutligneaudessus:

	lea		ecran1,a1
	moveq	#0,d1
	move.w	curseur_x,d1
	add.l	d1,a1
	moveq	#0,d1
	move.w	curseur_y,d1
	mulu	#nb_octets_par_ligne,d1
	add.l	d1,a1

	lsl.l	#3,d0		; * 8
	lea		fonte,a0
	add.l	d0,a0


; copie 1 lettre
	move.l	#8-1,d0
copieC_ligne:
	moveq	#8-1,d1
	move.b	(a0)+,d2
copieC_colonne:
	moveq	#0,d4
	btst	d1,d2
	beq.s	pixel_a_zero
	moveq	#0,d4
	move.w	couleur_char,d4
pixel_a_zero:
	move.b	d4,(a1)+
	dbf		d1,copieC_colonne
	lea		nb_octets_par_ligne-8(a1),a1
	dbf		d0,copieC_ligne

	move.w	curseur_x,d0
	add.w	#8,d0
	cmp.w	#320,d0
	blt		curseur_pas_fin_de_ligne
	moveq	#0,d0
	add.w	#8,curseur_y
curseur_pas_fin_de_ligne:
	move.w	d0,curseur_x

	movem.l (a7)+,d0-d7/a0-a6

	rts


;----------------------------------
; recopie l'object list dans la courante

copy_olist:
				move.l	#ob_list_courante,A1_BASE			; = DEST
				move.l	#$0,A1_PIXEL
				move.l	#PIXEL16|XADDPHR|PITCH1,A1_FLAGS
				move.l	#ob_liste_originale,A2_BASE			; = source
				move.l	#$0,A2_PIXEL
				move.l	#PIXEL16|XADDPHR|PITCH1,A2_FLAGS
				move.w	#1,d0
				swap	d0
				move.l	#fin_ob_liste_originale-ob_liste_originale,d1
				move.w	d1,d0
				move.l	d0,B_COUNT
				move.l	#LFU_REPLACE|SRCEN,B_CMD
				rts


; ------------------------------------
;          LSP
; ------------------------------------


; ------------------------------------
; Init

LSP_PlayerInit:
; a0: music data (any mem)
; a1: sound bank data (chip mem)
; (a2: 16bit DMACON word address)

;		Out:a0: music BPM pointer (16bits)
;			d0: music len in tick count


			cmpi.l		#'LSP1',(a0)+
			bne			.dataError
			move.l		(a0)+,d0		; unique id
			cmp.l		(a1),d0			; check that sample bank is this one
			bne			.dataError

			lea			LSPVars,a3
			cmpi.w		#$010b,(a0)+			; minimal major & minor version of latest compatible LSPConvert.exe		 = V 1.05
			blt			.dataError

			lea			2(a0),a0					; skip relocation flag

			moveq		#0,d6
			move.w		(a0)+,d6
			move.l		d6,m_currentBpm-LSPVars(a3)		; default BPM
			move.l		d6,LSP_BPM_frequence_replay
			move.w		(a0)+,d6
			move.l		d6,m_escCodeRewind-LSPVars(a3)		; tout en .L
			move.w		(a0)+,d6
			move.l		d6,m_escCodeSetBpm-LSPVars(a3)
			move.w		(a0)+,d6
			move.l		d6,m_escCodeGetPos-LSPVars(a3)

			move.l		(a0)+,-(a7)							; nb de ticks du module en tout = temps de replay ( /BPM)
			;move.l	a2,m_dmaconPatch(a3)
			;move.w	#$8000,-1(a2)			; Be sure DMACon word is $8000 (note: a2 should be ODD address)
			moveq		#0,d0
			move.w		(a0)+,d0				; instrument count
			lea			-12(a0),a2				; LSP data has -12 offset on instrument tab ( to win 2 cycles in fast player :) )
			move.l		a2,m_lspInstruments-LSPVars(a3)	; instrument tab addr ( minus 4 )
			subq.w		#1,d0
			move.l		a1,d1

.relocLoop:
			;bset.b		#0,3(a0)				; bit0 is relocation done flag
			;bne.s		.relocated

			move.l		(a0),d5					; pointeur sample
			add.l		d1,d5					; passage de relatif en absolu
			;lsl.l		#nb_bits_virgule_offset,d6
			move.l		d5,(a0)					; pointeur sample


			moveq		#0,d6
			move.w		4(a0),d6				; taille en words
			add.l		d6,d6
			move.w		d6,4(a0)				; taille en bytes

			move.l		(a0),a4


			move.l		6(a0),d6					; pointeur sample repeat
			add.l		d1,d6					; passage de relatif en absolu
			cmp.l		d5,d6					; corrige pointeur de repeat avant le debut de l'instrument
			bge.s		.ok_loop
			move.l		d5,d6
.ok_loop:
			;lsl.l		#nb_bits_virgule_offset,d6
			move.l		d6,6(a0)					; pointeur sample repeat

			moveq		#0,d6
			move.w		10(a0),d6				; taille repeat en words
			add.l		d6,d6
			move.w		d6,10(a0)				; taille repeat en bytes

.relocated:
			lea			12(a0),a0
			dbf.w		d0,.relocLoop


			moveq		#0,d0
			move.w		(a0)+,d0				; codes count (+2)
			move.l		a0,m_codeTableAddr-LSPVars(a3)	; code table
			add.w		d0,d0
			add.w		d0,a0
; read sequence timing infos (if any)
			move.w		(a0)+,d0				; m_seqCount


			move.l		(a0)+,d0				; word stream size
			move.l		(a0)+,d1				; byte stream loop point
			move.l		(a0)+,d2				; word stream loop point

; on a la zone de wordstream, puis la zone de bytestream
			move.l		a0,m_wordStream-LSPVars(a3)
			lea			0(a0,d0.l),a1			; byte stream
			move.l		a1,m_byteStream-LSPVars(a3)
			add.l		d2,a0
			add.l		d1,a1
			move.l		a0,m_wordStreamLoop-LSPVars(a3)
			move.l		a0,sauvegarde_wordstreamloop_pour_test
			move.l		a1,m_byteStreamLoop-LSPVars(a3)
			;bset.b		#1,$bfe001				; disabling this fucking Low pass filter!!
			;move.l		#FIN_LSP_module_music_data,m_byteStream_end-LSPVars(a3)

			lea			m_currentBpm-LSPVars(a3),a0
			move.l		(a7)+,d0				; music len in frame ticks
			rts

.dataError:	illegal

sauvegarde_wordstreamloop_pour_test:			dc.l				0


LSP_init_son_silence__music:
		movem.l	d0-d1/d7/a0,-(sp)
		move.l		#silence,0
		move.l		#fin_silence,d1
		lsl.l	#8,d0
		lsl.l	#8,d1
		.if		nb_bits_virgule_offset>8
		lsl.l	#nb_bits_virgule_offset-8,d0
		lsl.l	#nb_bits_virgule_offset-8,d1
		.endif

		lea					LSP_DSP_PAULA_AUD0L,a0
		moveq			#4-1,d7
LSP_init_son_silence__music__boucle:
		move.l			d0,LSP_DSP_PAULA_AUD0L-LSP_DSP_PAULA_AUD0L(a0)
		move.l			d1,LSP_DSP_PAULA_AUD0LEN-LSP_DSP_PAULA_AUD0L(a0)
		move.l			d0,LSP_DSP_PAULA_internal_location0-LSP_DSP_PAULA_AUD0L(a0)
		move.l			d1,LSP_DSP_PAULA_internal_length0-LSP_DSP_PAULA_AUD0L(a0)
		move.l			d0,LSP_DSP_repeat_pointeur0-LSP_DSP_PAULA_AUD0L(a0)
		move.l			d1,LSP_DSP_repeat_length0-LSP_DSP_PAULA_AUD0L(a0)

		lea					(LSP_DSP_PAULA_AUD1L-LSP_DSP_PAULA_AUD0L)(a0),a0
		dbf					d7,LSP_init_son_silence__music__boucle
		movem.l		(sp)+,d0-d1/d7/a0

	rts


DSP_mets_silence_dans_musique:
	move.l		#0,d0
	move.l		d0,LSP_DSP_panning_left0
	move.l		d0,LSP_DSP_panning_left1
	move.l		d0,LSP_DSP_panning_left2
	move.l		d0,LSP_DSP_panning_left3

	move.l		d0,LSP_DSP_panning_right0
	move.l		d0,LSP_DSP_panning_right1
	move.l		d0,LSP_DSP_panning_right2
	move.l		d0,LSP_DSP_panning_right3

DSP_mets_silence_dans_FX:

	move.l		#silence,d0
	move.l		#fin_silence,d1
	move.l		#silence,d2
	move.l		#fin_silence,d3
	move.l		#8000<<nb_bits_virgule_offset,d4
	moveq		#0,d5
	moveq		#0,d7
	;move.l		volume_max_fx_low.w,d5
	;lsl.l		#6,d5
;	move.l		d5,d7
	moveq		#0,d6			; channel 0
	bsr			LSP_Sample


	move.l		#silence,d0
	move.l		#fin_silence,d1
	move.l		#silence,d2
	move.l		#fin_silence,d3
	move.l		#8000<<nb_bits_virgule_offset,d4
	moveq		#0,d5
	moveq		#0,d7
	;move.l		volume_max_fx_low.w,d5
	;lsl.l		#6,d5
;	move.l		d5,d7
	moveq		#1,d6			; channel 1
	bsr			LSP_Sample

	move.l		#silence,d0
	move.l		#fin_silence,d1
	move.l		#silence,d2
	move.l		#fin_silence,d3
	move.l		#8000<<nb_bits_virgule_offset,d4
	moveq		#0,d5
	moveq		#0,d7
	;move.l		volume_max_fx_low.w,d5
	;lsl.l		#6,d5
;	move.l		d5,d7
	moveq		#2,d6			; channel 2
	bsr			LSP_Sample

	move.l		#silence,d0
	move.l		#fin_silence,d1
	move.l		#silence,d2
	move.l		#fin_silence,d3
	move.l		#8000<<nb_bits_virgule_offset,d4
	moveq		#0,d5
	moveq		#0,d7
	;move.l		volume_max_fx_low.w,d5
	;lsl.l		#6,d5
;	move.l		d5,d7
	moveq		#3,d6			; channel 3
	bsr			LSP_Sample


; 	moveq		#0,d0
; 	move.l		d0,LSP_DSP_SOUND_panning_left0
; 	move.l		d0,LSP_DSP_SOUND_panning_left1
; 	move.l		d0,LSP_DSP_SOUND_panning_left2
; 	move.l		d0,LSP_DSP_SOUND_panning_left3
;
; 	move.l		d0,LSP_DSP_SOUND_panning_right0
; 	move.l		d0,LSP_DSP_SOUND_panning_right1
; 	move.l		d0,LSP_DSP_SOUND_panning_right2
; 	move.l		d0,LSP_DSP_SOUND_panning_right3

	rts


DSP_code_bruitages_mono_ou_stereo:
; modifier le panning suivant mono ou stereo
; + application du master volume ?
; bruitages_stereo_ou_mono.w : ; 1 = mono / 2 = stereo
	cmp.w		#1,bruitages_stereo_ou_mono
	beq.s		DSP_code_bruitages_mono_ou_stereo__MONO

; stereo, on ne change rien au panning
; appliquer le master volume
	move.l		volume_max_music_low,d0
	moveq		#0,d1
	;lsl.l		#6,d0
	move.l		d0,LSP_DSP_panning_left0			; MAx
	move.l		d1,LSP_DSP_panning_right0		; 0

	move.l		d1,LSP_DSP_panning_left1
	move.l		d0,LSP_DSP_panning_right1

	move.l		d1,LSP_DSP_panning_left2
	move.l		d0,LSP_DSP_panning_right2

	move.l		d0,LSP_DSP_panning_left3
	move.l		d1,LSP_DSP_panning_right3

	rts



DSP_code_bruitages_mono_ou_stereo__MONO:
; force MONO
	move.l		volume_max_music_low,d0
	;lsl.l		#6,d0
	move.l		d0,LSP_DSP_panning_left0
	move.l		d0,LSP_DSP_panning_left1
	move.l		d0,LSP_DSP_panning_left2
	move.l		d0,LSP_DSP_panning_left3

	move.l		d0,LSP_DSP_panning_right0
	move.l		d0,LSP_DSP_panning_right1
	move.l		d0,LSP_DSP_panning_right2
	move.l		d0,LSP_DSP_panning_right3
	rts

remplir_table_panning_stereo:
; fabrique une table pour localiser les X sur le panning stereo
;  x=0 : 127/0 // x=159 : 64/64 // x=319 : 0/127
; gauche = ((319-X)*127*volume_max_fx_low)/319
; droite = (X*127*volume_max_fx_low)/319
; version sinus
;	lea				table_panning_stereo_en_X,a0
;	move.w		#(320*2)-1,d7
;	move.l		volume_max_fx_low.w,d6
;remplir_table_panning_stereo__boucle:
;	move.w		(a0),d0			; 0 a 63
;	ext.l		d0
;	mulu			d6,d0
;	move.w		d0,(a0)+
;	dbf				d7,remplir_table_panning_stereo__boucle
;	rts


	lea				table_panning_stereo_en_X,a0
	move.w		#320-1,d7
	moveq		#0,d0				; d0=X
	move.l		volume_max_fx_low,d6
remplir_table_panning_stereo__boucle:
; calcul gauche
	move.l		#319,d1
	sub.l		d0,d1				; 319-X
	mulu			d6,d1
	divu			#319,d1
	ext.l		d1
	mulu			#63,d1
	move.w		d1,(a0)+
; calcul droite
	move.l		d0,d1
	mulu			d6,d1
	divu			#319,d1
	ext.l		d1
	mulu			#63,d1
	move.w		d1,(a0)+
	addq.l		#1,d0				; X+1
	dbf				d7,remplir_table_panning_stereo__boucle
	rts



	LSP_Sample:
; version fixe = $725c

		move.l		a0,-(sp)
		lea				DSP_tableau_upload_FX,a0
		; D6*8*4 = *32 = lsl.l #5
		lsl.l				#5,d6
		lea				(a0,d6.w),a0
		lsr.l				#5,d6
		move.l			#-1,(a0)
		movem.l		d1-d7,4(a0)
		move.l			d0,(a0)

		move.l		(sp)+,a0
		rts




	;-------------------------------------
;
;     DSP
;
;-------------------------------------

	.phrase
YM_DSP_debut:
	include "lsp_dsp.s"

;---------------------
; FIN DE LA RAM DSP
YM_DSP_fin:
;---------------------


SOUND_DRIVER_SIZE			.equ			YM_DSP_fin-DSP_base_memoire
	.print	"--- Sound driver code size (DSP): ", /u SOUND_DRIVER_SIZE, " bytes / 8192 ---"




        .68000


	.dphrase

ob_liste_originale:           				 ; This is the label you will use to address this in 68K code
        .objproc 							   ; Engage the OP assembler
		.dphrase

        .org    ob_list_courante			 ; Tell the OP assembler where the list will execute
;
        branch      VC < 0, .stahp    			 ; Branch to the STOP object if VC < 0
        branch      VC > 265, .stahp   			 ; Branch to the STOP object if VC > 241
			; bitmap data addr, xloc, yloc, dwidth, iwidth, iheight, bpp, pallete idx, flags, firstpix, pitch
        bitmap      ecran1, 16, 26, nb_octets_par_ligne/8, nb_octets_par_ligne/8, 246-26,3
		;bitmap		ecran1,16,24,40,40,255,3
        jump        .haha
.stahp:
        stop
.haha:
        jump        .stahp

		.68000
		.dphrase
fin_ob_liste_originale:


			.data
	.dphrase

stoplist:		dc.l	0,4




; DATAs DSP
silence:
		dc.l			$0,$0
		dc.l			$0,$0
		dc.l			$0,$0
		dc.l			$0,$0
fin_silence:
		dc.l			$0,$0
		dc.l			$0,$0

	.phrase
table_panning_stereo_en_X:
dc.w            $3E, $0
dc.w            $3E, $0
dc.w            $3E, $0
dc.w            $3E, $0
dc.w            $3E, $1
dc.w            $3E, $1
dc.w            $3E, $1
dc.w            $3E, $2
dc.w            $3E, $2
dc.w            $3E, $2
dc.w            $3E, $3
dc.w            $3E, $3
dc.w            $3E, $3
dc.w            $3E, $4
dc.w            $3E, $4
dc.w            $3E, $4
dc.w            $3E, $4
dc.w            $3E, $5
dc.w            $3E, $5
dc.w            $3E, $5
dc.w            $3E, $6
dc.w            $3E, $6
dc.w            $3E, $6
dc.w            $3E, $7
dc.w            $3E, $7
dc.w            $3E, $7
dc.w            $3E, $8
dc.w            $3E, $8
dc.w            $3E, $8
dc.w            $3E, $8
dc.w            $3E, $9
dc.w            $3E, $9
dc.w            $3E, $9
dc.w            $3E, $A
dc.w            $3E, $A
dc.w            $3E, $A
dc.w            $3E, $B
dc.w            $3D, $B
dc.w            $3D, $B
dc.w            $3D, $B
dc.w            $3D, $C
dc.w            $3D, $C
dc.w            $3D, $C
dc.w            $3D, $D
dc.w            $3D, $D
dc.w            $3D, $D
dc.w            $3D, $E
dc.w            $3D, $E
dc.w            $3D, $E
dc.w            $3D, $F
dc.w            $3D, $F
dc.w            $3D, $F
dc.w            $3C, $F
dc.w            $3C, $10
dc.w            $3C, $10
dc.w            $3C, $10
dc.w            $3C, $11
dc.w            $3C, $11
dc.w            $3C, $11
dc.w            $3C, $11
dc.w            $3C, $12
dc.w            $3C, $12
dc.w            $3C, $12
dc.w            $3C, $13
dc.w            $3B, $13
dc.w            $3B, $13
dc.w            $3B, $14
dc.w            $3B, $14
dc.w            $3B, $14
dc.w            $3B, $14
dc.w            $3B, $15
dc.w            $3B, $15
dc.w            $3B, $15
dc.w            $3A, $16
dc.w            $3A, $16
dc.w            $3A, $16
dc.w            $3A, $16
dc.w            $3A, $17
dc.w            $3A, $17
dc.w            $3A, $17
dc.w            $3A, $18
dc.w            $3A, $18
dc.w            $39, $18
dc.w            $39, $18
dc.w            $39, $19
dc.w            $39, $19
dc.w            $39, $19
dc.w            $39, $1A
dc.w            $39, $1A
dc.w            $39, $1A
dc.w            $38, $1A
dc.w            $38, $1B
dc.w            $38, $1B
dc.w            $38, $1B
dc.w            $38, $1C
dc.w            $38, $1C
dc.w            $38, $1C
dc.w            $37, $1C
dc.w            $37, $1D
dc.w            $37, $1D
dc.w            $37, $1D
dc.w            $37, $1D
dc.w            $37, $1E
dc.w            $37, $1E
dc.w            $36, $1E
dc.w            $36, $1F
dc.w            $36, $1F
dc.w            $36, $1F
dc.w            $36, $1F
dc.w            $36, $20
dc.w            $36, $20
dc.w            $35, $20
dc.w            $35, $20
dc.w            $35, $21
dc.w            $35, $21
dc.w            $35, $21
dc.w            $35, $21
dc.w            $34, $22
dc.w            $34, $22
dc.w            $34, $22
dc.w            $34, $23
dc.w            $34, $23
dc.w            $34, $23
dc.w            $33, $23
dc.w            $33, $24
dc.w            $33, $24
dc.w            $33, $24
dc.w            $33, $24
dc.w            $32, $25
dc.w            $32, $25
dc.w            $32, $25
dc.w            $32, $25
dc.w            $32, $26
dc.w            $32, $26
dc.w            $31, $26
dc.w            $31, $26
dc.w            $31, $27
dc.w            $31, $27
dc.w            $31, $27
dc.w            $30, $27
dc.w            $30, $27
dc.w            $30, $28
dc.w            $30, $28
dc.w            $30, $28
dc.w            $2F, $28
dc.w            $2F, $29
dc.w            $2F, $29
dc.w            $2F, $29
dc.w            $2F, $29
dc.w            $2E, $2A
dc.w            $2E, $2A
dc.w            $2E, $2A
dc.w            $2E, $2A
dc.w            $2E, $2A
dc.w            $2D, $2B
dc.w            $2D, $2B
dc.w            $2D, $2B
dc.w            $2D, $2B
dc.w            $2C, $2C
dc.w            $2C, $2C
dc.w            $2C, $2C
dc.w            $2C, $2C
dc.w            $2C, $2C
dc.w            $2B, $2D
dc.w            $2B, $2D
dc.w            $2B, $2D
dc.w            $2B, $2D
dc.w            $2A, $2E
dc.w            $2A, $2E
dc.w            $2A, $2E
dc.w            $2A, $2E
dc.w            $2A, $2E
dc.w            $29, $2F
dc.w            $29, $2F
dc.w            $29, $2F
dc.w            $29, $2F
dc.w            $28, $2F
dc.w            $28, $30
dc.w            $28, $30
dc.w            $28, $30
dc.w            $27, $30
dc.w            $27, $30
dc.w            $27, $31
dc.w            $27, $31
dc.w            $27, $31
dc.w            $26, $31
dc.w            $26, $31
dc.w            $26, $32
dc.w            $26, $32
dc.w            $25, $32
dc.w            $25, $32
dc.w            $25, $32
dc.w            $25, $32
dc.w            $24, $33
dc.w            $24, $33
dc.w            $24, $33
dc.w            $24, $33
dc.w            $23, $33
dc.w            $23, $34
dc.w            $23, $34
dc.w            $23, $34
dc.w            $22, $34
dc.w            $22, $34
dc.w            $22, $34
dc.w            $21, $35
dc.w            $21, $35
dc.w            $21, $35
dc.w            $21, $35
dc.w            $20, $35
dc.w            $20, $35
dc.w            $20, $36
dc.w            $20, $36
dc.w            $1F, $36
dc.w            $1F, $36
dc.w            $1F, $36
dc.w            $1F, $36
dc.w            $1E, $36
dc.w            $1E, $37
dc.w            $1E, $37
dc.w            $1D, $37
dc.w            $1D, $37
dc.w            $1D, $37
dc.w            $1D, $37
dc.w            $1C, $37
dc.w            $1C, $38
dc.w            $1C, $38
dc.w            $1C, $38
dc.w            $1B, $38
dc.w            $1B, $38
dc.w            $1B, $38
dc.w            $1A, $38
dc.w            $1A, $39
dc.w            $1A, $39
dc.w            $1A, $39
dc.w            $19, $39
dc.w            $19, $39
dc.w            $19, $39
dc.w            $18, $39
dc.w            $18, $39
dc.w            $18, $3A
dc.w            $18, $3A
dc.w            $17, $3A
dc.w            $17, $3A
dc.w            $17, $3A
dc.w            $16, $3A
dc.w            $16, $3A
dc.w            $16, $3A
dc.w            $16, $3A
dc.w            $15, $3B
dc.w            $15, $3B
dc.w            $15, $3B
dc.w            $14, $3B
dc.w            $14, $3B
dc.w            $14, $3B
dc.w            $14, $3B
dc.w            $13, $3B
dc.w            $13, $3B
dc.w            $13, $3C
dc.w            $12, $3C
dc.w            $12, $3C
dc.w            $12, $3C
dc.w            $11, $3C
dc.w            $11, $3C
dc.w            $11, $3C
dc.w            $11, $3C
dc.w            $10, $3C
dc.w            $10, $3C
dc.w            $10, $3C
dc.w            $F, $3C
dc.w            $F, $3D
dc.w            $F, $3D
dc.w            $F, $3D
dc.w            $E, $3D
dc.w            $E, $3D
dc.w            $E, $3D
dc.w            $D, $3D
dc.w            $D, $3D
dc.w            $D, $3D
dc.w            $C, $3D
dc.w            $C, $3D
dc.w            $C, $3D
dc.w            $B, $3D
dc.w            $B, $3D
dc.w            $B, $3D
dc.w            $B, $3E
dc.w            $A, $3E
dc.w            $A, $3E
dc.w            $A, $3E
dc.w            $9, $3E
dc.w            $9, $3E
dc.w            $9, $3E
dc.w            $8, $3E
dc.w            $8, $3E
dc.w            $8, $3E
dc.w            $8, $3E
dc.w            $7, $3E
dc.w            $7, $3E
dc.w            $7, $3E
dc.w            $6, $3E
dc.w            $6, $3E
dc.w            $6, $3E
dc.w            $5, $3E
dc.w            $5, $3E
dc.w            $5, $3E
dc.w            $4, $3E
dc.w            $4, $3E
dc.w            $4, $3E
dc.w            $4, $3E
dc.w            $3, $3E
dc.w            $3, $3E
dc.w            $3, $3E
dc.w            $2, $3E
dc.w            $2, $3E
dc.w            $2, $3E
dc.w            $1, $3E
dc.w            $1, $3E
dc.w            $1, $3E
dc.w            $0, $3E
dc.w            $0, $3E
dc.w            $0, $3E

fonte:
	.include	"fonte1plan.s"
	even

couleur_char:				dc.w		25
curseur_x:					dc.w		0
curseur_y:					dc.w		curseur_Y_min
		even

chaine_LSP:						dc.b	"LSP player for Jaguar XW version",10,0
chaine_playing_LSP:				dc.b	"Now playing module",10,0
chaine_BPM_init_LSP:			dc.b	" bpm.",0
chaine_Hz_init_LSP:				dc.b	" Hz.",10,0
chaine_replay_frequency:		dc.b	"Replay frequency : ",0
chaine_RAM_DSP:					dc.b	"DSP RAM available while running : ",0
chaine_entete_debug_module:		dc.b	"location incremen offset   end  ",10,0
chaine_entete_debug_module2:	dc.b	"location length   repeat_s rep end",10,0
		even


pointeur_module_sound_bank:				dc.l				LSP_sound_bank
pointeur_module_music_data:				dc.l				LSP_music_data

	.phrase
LSP_music_data:				.incbin		"elysium.lsmusic"
	.phrase
LSP_sound_bank:			.incbin		"elysium.lsbank"

	.phrase
sample_son_debut:
	 .incbin			"son_debut.raw"			; 18 ko	11025hz
fin_sample_son_debut:
	.phrase


		.BSS
DEBUT_BSS:
		.dphrase

frequence_Video_Clock:					ds.l				1
frequence_Video_Clock_divisee :			ds.l				1

volume_max_fx_low:				ds.l					1
volume_max_music_low:		ds.l					1
bruitages_stereo_ou_mono:	ds.w			1							; musique : 1 = mono / autre valeur = stereo

_50ou60hertz:			ds.l	1
ntsc_flag:				ds.w	1
a_hdb:          		ds.w   1
a_hde:          		ds.w   1
a_vdb:          		ds.w   1
a_vde:          		ds.w   1
width:          		ds.w   1
height:         		ds.w   1
taille_liste_OP:		ds.l	1
vbl_counter:			ds.l	1
			.phrase

ecran1:				ds.b		320*256				; 8 bitplanes
	.phrase


FIN_RAM:
