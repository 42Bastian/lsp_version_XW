
	.dsp
	.org	D_RAM
DSP_base_memoire:

; CPU interrupt
	.rept	8
		nop
	.endr
; I2S interrupt
	movei	#DSP_LSP_routine_interruption_I2S,r28						; 6 octets
	movei	#D_FLAGS,r30											; 6 octets
	jump	(r28)													; 2 octets
	load	(r30),r29	; read flags								; 2 octets = 16 octets
; Timer 1 interrupt
	movei	#DSP_LSP_routine_interruption_Timer1,r12						; 6 octets
	movei	#D_FLAGS,r16											; 6 octets
	jump	(r12)													; 2 octets
	load	(r16),r13	; read flags								; 2 octets = 16 octets
; Timer 2 interrupt
	movei	#DSP_LSP_routine_interruption_Timer2,r12						; 6 octets
	movei	#D_FLAGS,r16											; 6 octets
	jump	(r12)													; 2 octets
	load	(r16),r13	; read flags								; 2 octets = 16 octets
; External 0 interrupt
	.rept	8
		nop
	.endr
; External 1 interrupt
	.rept	8
		nop
	.endr













; -------------------------------
; DSP : routines en interruption
; -------------------------------
; utilisÃ©s : 	R29/R30/R31
; 				R15/ R18/R19/R20/R21/R22/R23/R24/R25/R26/R27/R28
;

;  DSP_FLAG_STOP_DSP : 0=RUN // 1=stop I2S // 2=stop T1 // 2=stop T2 // 4=stop DSP

;---------------------------------------------------------------------------------------------------------------------------------------------------------------------------
;---------------------------------------------------------------------------------------------------------------------------------------------------------------------------
;---------------------------------------------------------------------------------------------------------------------------------------------------------------------------
; I2S : replay sample
;	- version simple, lit un octet Ã  chaque fois
;	- puis version plus compleque : lit 1 long, et utilise ses octets

LSP_variables_table__index_location						=0
LSP_variables_table__index_increment					=1
LSP_variables_table__index_length							=2
LSP_variables_table__index_external_length		=3
LSP_variables_table__index_external_location	=4
LSP_variables_table__total_size								=5


DSP_LSP_routine_interruption_I2S__shutdown_now:
	cmpq			#10,R26				; 1=stop I2S
	jr				eq,DSP_LSP_routine_interruption_I2S__shutdown_now__real_shutdown__just_no_sound
	load		(r31),r28	; return address

DSP_LSP_routine_interruption_I2S__shutdown_now__real_shutdown:
;R30=D_FLAGS
;R29=(D_FLAGS)
; return from interrupt I2S
	bclr		#5,R29		; clear I2S enabled = I2S Interrupt Enable Bit : stop I2S
	store	R17,(R27)	; DSP_FLAG_STOP_DSP=2
DSP_LSP_routine_interruption_I2S__shutdown_now__real_shutdown__just_no_sound:
	bset		#10,r29		; clear latch 1 = I2S
	bclr		#3,r29		; clear IMASK
	addq		#4,r31		; pop from stack
	addqt	#2,r28		; next instruction
	jump		t,(r28)		; return
	store	r29,(r30)	; restore flags




;---------------------------------------------------------------------------------------------------------------------------------------------------------------------------
DSP_LSP_routine_interruption_I2S:

	.if		DSP_DEBUG
; change la couleur du fond
	movei	#$777,R26
	movei	#BG,r27
	storew	r26,(r27)
	.endif

; version complexe avec stockage de 4 octets

; test shutdown flag
	movei		#DSP_FLAG_STOP_DSP,R27
	movei		#DSP_LSP_routine_interruption_I2S__shutdown_now,R17
; module replay
		movefa		R15,R15
	load			(R27),R26
	cmpq			#0,R26				; >0=stop I2S ou no play
	jump			hi,(R17)
	moveq		#2,R17




; ----------
; channel 3
;	movei		#LSP_DSP_PAULA_internal_location3,R1
;	movei		#LSP_DSP_PAULA_internal_increment3,R2
;	movei		#LSP_DSP_PAULA_internal_length3,R3
;	movei		#LSP_DSP_PAULA_AUD3LEN,R4
;	movei		#LSP_DSP_PAULA_AUD3L,R5
		;movei		#LSP_DSP_PAULA_internal_location3,R28						; adresse sample actuelle, a virgule
		;movefa		R1,R28
		load		(R15),R28
		;movei		#LSP_DSP_PAULA_internal_increment3,R27
		;movefa		R2,R27
		load		(R15+LSP_variables_table__index_increment),R27
		load		(R28),R26										; R26=current pointeur sample 16:16
		load		(R27),R27										; R27=increment 16:16
		move		R26,R17											; R17 = pointeur sample a virgule avant increment
		;movei		#LSP_DSP_PAULA_internal_length3,R25				; =FIN
		load		(R15+LSP_variables_table__index_length),R25
		;movefa		R3,R25
		add			R27,R26											; R26=adresse+increment , a virgule
		load		(R25),R23
		movefa		R0,R22
		cmp			R23,R26
		jr			mi,DSP_LSP_routine_interruption_I2S_pas_fin_de_sample_channel3
		;nop
		shrq		#nb_bits_virgule_offset,R17								; ancien pointeur adresse sample partie entiere

; fin de sample => on recharge les infos des registres externes
		shlq		#32-nb_bits_virgule_offset,R26
		;movei		#LSP_DSP_PAULA_AUD3LEN,R27			; fin, a virgule
		load		(R15+LSP_variables_table__index_external_length),R27
		;movefa		R4,R27
		shrq		#32-nb_bits_virgule_offset,R26		; on ne garde que la virgule
		;movei		#LSP_DSP_PAULA_AUD3L,R24			; sample location a virgule
		load		(R15+LSP_variables_table__index_external_location),R24
		;movefa		R5,R24
		load		(R27),R27
		load		(R24),R23
		store		R27,(R25)							; update internal sample end, a virgule
		or			R23,R26								; on garde la virgule en cours
; update R17
		move		R26,R17											; R17 = pointeur sample a virgule avant increment
		shrq		#nb_bits_virgule_offset,R17								; ancien pointeur adresse sample partie entiere
		subq		#4,R17

DSP_LSP_routine_interruption_I2S_pas_fin_de_sample_channel3:
		store		R26,(R28)							; stocke internal sample pointeur, a virgule
		shrq		#nb_bits_virgule_offset,R26								; nouveau pointeur adresse sample partie entiere
														;shrq		#nb_bits_virgule_offset,R17								; ancien pointeur adresse sample partie entiere
		move		R26,R25								; R25 = nouveau pointeur sample
		and			R22,R17								; ancien pointeur sample modulo 4
		and			R22,R26								; nouveau pointeur sample modulo 4
		;movei		#LSP_DSP_PAULA_AUD3DAT,R28			; 4 octets actuels
		subq		#4,R28								; de LSP_DSP_PAULA_internal_location3 => LSP_DSP_PAULA_AUD3DAT
		not			R22									; => %11
		load		(R28),R19							; R19 = octets actuels en stock
		and			R22,R25								; R25 = position octet Ã  lire
		cmp			R17,R26
		jr			eq,DSP_LSP_routine_interruption_I2S_pas_nouveau_long_word3
		shlq		#3,R25					; numero d'octet Ã  lire * 8

; il faut rafraichir R21
		load		(R26),R19							; lit 4 nouveaux octets de sample
		store		R19,(R28)							; rafraichit le stockage des 4 octets

DSP_LSP_routine_interruption_I2S_pas_nouveau_long_word3:
		;movei		#LSP_DSP_PAULA_AUD3VOL,R23/R24
		subq		#4,R28								; de LSP_DSP_PAULA_AUD3DAT => LSP_DSP_PAULA_AUD3VOL right
		neg			R25									; -0 -8 -16 -24
; R25=numero d'octet Ã  lire
; ch2
		;movei		#LSP_DSP_PAULA_internal_increment2,R27
		load		(R15+(LSP_variables_table__total_size*1)+LSP_variables_table__index_increment),R27
		;movefa		R7,R27

		sh			R25,R19								; shift les 4 octets en stock vers la gauche, pour positionner l'octet Ã  lire en haut
		load		(R28),R26							; R23 = volume : 6+8=14 bits right
		sharq		#24,R19								; descends l'octet Ã  lire
		subq		#4,R28									; pointe sur volume left
		move		R19,R18
		load		(R28),R28								; R28 = volume panned left
; ch2
		imult		R26,R19								; R19=right:  unsigned multiplication : unsigned sample * volume => 8bits + 6 bits = 14 bits
		imult		R28,R18								; R18=left

; R21=sample channel 3 on 14 bits

; ----------
; channel 2
;	movei		#LSP_DSP_PAULA_internal_location2,R6
;	movei		#LSP_DSP_PAULA_internal_increment2,R7
;	movei		#LSP_DSP_PAULA_internal_length2,R8
;	movei		#LSP_DSP_PAULA_AUD2LEN,R9
;	movei		#LSP_DSP_PAULA_AUD2L,R10
		load		(R27),R27										; R27=increment 16:16
		;movei		#LSP_DSP_PAULA_internal_location2,R28						; adresse sample actuelle, a virgule
		load		(R15+(LSP_variables_table__total_size*1)+LSP_variables_table__index_location),R28
		;movefa		R6,R28
		;movei		#LSP_DSP_PAULA_internal_length2,R25				; =FIN
		load		(R15+(LSP_variables_table__total_size*1)+LSP_variables_table__index_length),R25
		;movefa		R8,R25

		;movei		#LSP_DSP_PAULA_internal_increment2,R27
		load		(R28),R26										; R26=current pointeur sample 16:16
		move		R26,R17											; R17 = pointeur sample a virgule avant increment
		add			R27,R26											; R26=adresse+increment , a virgule
		load		(R25),R23
		movefa		R0,R22
		cmp			R23,R26
		jr			mi,DSP_LSP_routine_interruption_I2S_pas_fin_de_sample_channel2
		shrq		#nb_bits_virgule_offset,R17								; ancien pointeur adresse sample partie entiere

; fin de sample => on recharge les infos des registres externes
		shlq		#32-nb_bits_virgule_offset,R26
		;movei		#LSP_DSP_PAULA_AUD2LEN,R27			; fin, a virgule
		load		(R15+(LSP_variables_table__total_size*1)+LSP_variables_table__index_external_length),R27
		;movefa		R9,R27
		shrq		#32-nb_bits_virgule_offset,R26		; on ne garde que la virgule
		;movei		#LSP_DSP_PAULA_AUD2L,R24			; sample location a virgule
		load		(R15+(LSP_variables_table__total_size*1)+LSP_variables_table__index_external_location),R24
		;movefa		R10,R24
		load		(R27),R27
		load		(R24),R23
		store		R27,(R25)							; update internal sample end, a virgule
		or			R23,R26								; on garde la virgule en cours
; update R17
		move		R26,R17											; R17 = pointeur sample a virgule avant increment
		shrq		#nb_bits_virgule_offset,R17								; ancien pointeur adresse sample partie entiere
		subq		#4,R17

DSP_LSP_routine_interruption_I2S_pas_fin_de_sample_channel2:
		store		R26,(R28)							; stocke internal sample pointeur, a virgule
		shrq		#nb_bits_virgule_offset,R26								; nouveau pointeur adresse sample partie entiere
		;shrq		#nb_bits_virgule_offset,R17								; ancien pointeur adresse sample partie entiere
		move		R26,R25								; R25 = nouveau pointeur sample
		and			R22,R17								; ancien pointeur sample modulo 4
		and			R22,R26								; nouveau pointeur sample modulo 4
		;movei		#LSP_DSP_PAULA_AUD2DAT,R28			; 4 octets actuels
		subq		#4,R28								; de LSP_DSP_PAULA_internal_location2 => LSP_DSP_PAULA_AUD2DAT
		not			R22									; => %11
		load		(R28),R20							; R20 = octets actuels en stock
		and			R22,R25								; R25 = position octet Ã  lire
		cmp			R17,R26
		jr			eq,DSP_LSP_routine_interruption_I2S_pas_nouveau_long_word2
		;nop
		shlq		#3,R25					; numero d'octet Ã  lire * 8

; il faut rafraichir R20
		load		(R26),R20							; lit 4 nouveaux octets de sample
		store		R20,(R28)							; rafraichit le stockage des 4 octets

DSP_LSP_routine_interruption_I2S_pas_nouveau_long_word2:
		;movei		#LSP_DSP_PAULA_AUD2VOL,R23
		subq		#4,R28								; de LSP_DSP_PAULA_AUD2DAT => LSP_DSP_PAULA_AUD2VOL right
		neg			R25									; -0 -8 -16 -24
; R25=numero d'octet Ã  lire
; ch1
		;movei		#LSP_DSP_PAULA_internal_increment1,R27
		load		(R15+((LSP_variables_table__total_size*2)+LSP_variables_table__index_increment)),R27
		;movefa		R12,R27

		sh			R25,R20								; shift les 4 octets en stock vers la gauche, pour positionner l'octet Ã  lire en haut
		load		(R28),R26							; R26 = volume : 6 bits right
		sharq		#24,R20								; descends l'octet Ã  lire
		subq		#4,R28									; pointe sur volume left
		move		R20,R21								; R20 & R21 = sample signÃ©
		load		(R28),R28								; R28 = volume panned left
		imult		R26,R20							; R20=right
		imult		R28,R21							; R21=left unsigned multiplication : unsigned sample * volume => 8bits + 6 bits = 14 bits
		add			R20,R19							; R19=right
		add			R21,R18							; R18=left

; R20=sample channel 2 on 14 bits

; ----------
; channel 1
;	movei		#LSP_DSP_PAULA_internal_location1,R11
;	movei		#LSP_DSP_PAULA_internal_increment1,R12
;	movei		#LSP_DSP_PAULA_internal_length1,R13
;	movei		#LSP_DSP_PAULA_AUD1LEN,R14
;	movei		#LSP_DSP_PAULA_AUD1L,R21
		;movei		#LSP_DSP_PAULA_internal_location1,R28						; adresse sample actuelle, a virgule
		load		(R15+(LSP_variables_table__total_size*2)+LSP_variables_table__index_location),R28
		;movefa		R11,R28
		load		(R28),R26										; R26=current pointeur sample 16:16
		load		(R27),R27										; R27=increment 16:16
		move		R26,R17											; R17 = pointeur sample a virgule avant increment
		;movei		#LSP_DSP_PAULA_internal_length1,R25				; =FIN
		load		(R15+(LSP_variables_table__total_size*2)+LSP_variables_table__index_length),R25
		;movefa		R13,R25
		add			R27,R26											; R26=adresse+increment , a virgule
		load		(R25),R23
		movefa		R0,R22
		cmp			R23,R26
		jr			mi,DSP_LSP_routine_interruption_I2S_pas_fin_de_sample_channel1
		;nop
		shrq		#nb_bits_virgule_offset,R17								; ancien pointeur adresse sample partie entiere

; fin de sample => on recharge les infos des registres externes
		shlq		#32-nb_bits_virgule_offset,R26
		;movei		#LSP_DSP_PAULA_AUD1LEN,R27			; fin, a virgule
		load		(R15+(LSP_variables_table__total_size*2)+LSP_variables_table__index_external_length),R27
		;movefa		R14,R27
		shrq		#32-nb_bits_virgule_offset,R26		; on ne garde que la virgule
		;movei		#LSP_DSP_PAULA_AUD1L,R24			; sample location a virgule
		load		(R15+(LSP_variables_table__total_size*2)+LSP_variables_table__index_external_location),R24
		;movefa		R21,R24
		load		(R27),R27
		load		(R24),R23
		store		R27,(R25)							; update internal sample end, a virgule
		or			R23,R26								; on garde la virgule en cours
; update R17
		move		R26,R17											; R17 = pointeur sample a virgule avant increment
		shrq		#nb_bits_virgule_offset,R17								; ancien pointeur adresse sample partie entiere
		subq		#4,R17

DSP_LSP_routine_interruption_I2S_pas_fin_de_sample_channel1:
		store		R26,(R28)							; stocke internal sample pointeur, a virgule
		shrq		#nb_bits_virgule_offset,R26								; nouveau pointeur adresse sample partie entiere
		;shrq		#nb_bits_virgule_offset,R17								; ancien pointeur adresse sample partie entiere
		move		R26,R25								; R25 = nouveau pointeur sample
		and			R22,R17								; ancien pointeur sample modulo 4
		and			R22,R26								; nouveau pointeur sample modulo 4
		;movei		#LSP_DSP_PAULA_AUD1DAT,R28			; 4 octets actuels
		subq		#4,R28								; de LSP_DSP_PAULA_internal_location1 => LSP_DSP_PAULA_AUD1DAT
		not			R22									; => %11
		load		(R28),R20							; R20 = octets actuels en stock
		and			R22,R25								; R25 = position octet Ã  lire
		cmp			R17,R26
		jr			eq,DSP_LSP_routine_interruption_I2S_pas_nouveau_long_word1
		;nop
		shlq		#3,R25					; numero d'octet Ã  lire * 8

; il faut rafraichir R19
		load		(R26),R20							; lit 4 nouveaux octets de sample
		store		R20,(R28)							; rafraichit le stockage des 4 octets

DSP_LSP_routine_interruption_I2S_pas_nouveau_long_word1:
		;movei		#LSP_DSP_PAULA_AUD1VOL,R23
		subq		#4,R28								; de LSP_DSP_PAULA_AUD1DAT => LSP_DSP_PAULA_AUD1VOL
		neg			R25									; -0 -8 -16 -24
; R25=numero d'octet Ã  lire
; ch0
		;movei		#LSP_DSP_PAULA_internal_increment0,R27
		load		(R15+(LSP_variables_table__total_size*3)+LSP_variables_table__index_increment),R27
		;movefa		R17,R27

		sh			R25,R20								; shift les 4 octets en stock vers la gauche, pour positionner l'octet Ã  lire en haut
		load		(R28),R26							; R26 = volume : 6 bits right
		sharq		#24,R20								; descends l'octet Ã  lire
		subq		#4,R28									; pointe sur volume left
		move		R20,R21								; R20 & R21 = sample signÃ©
		load		(R28),R28								; R28 = volume panned left
		imult		R26,R20							; R20=right
		imult		R28,R21							; R21=left unsigned multiplication : unsigned sample * volume => 8bits + 6 bits = 14 bits
		add			R20,R19							; R19=right
		add			R21,R18							; R18=left

; ch0
		;movei		#LSP_DSP_PAULA_internal_location0,R28						; adresse sample actuelle, a virgule
		load		(R15+(LSP_variables_table__total_size*3)+LSP_variables_table__index_location),R28
		;movefa		R16,R28


; R19=sample channel 1 on 14 bits

; ----------
; channel 0
;	movei		#LSP_DSP_PAULA_internal_location0,R16
;	movei		#LSP_DSP_PAULA_internal_increment0,R17
;	movei		#LSP_DSP_PAULA_internal_length0,R18
;	movei		#LSP_DSP_PAULA_AUD0LEN,R19
;	movei		#LSP_DSP_PAULA_AUD0L,R20
		load		(R28),R26										; R26=current pointeur sample 16:16
		load		(R27),R27										; R27=increment 16:16
		move		R26,R17											; R17 = pointeur sample a virgule avant increment
		;movei		#LSP_DSP_PAULA_internal_length0,R25				; =FIN
		load		(R15+(LSP_variables_table__total_size*3)+LSP_variables_table__index_length),R25
		;movefa		R18,R25
		add			R27,R26											; R26=adresse+increment , a virgule
		load		(R25),R23										; fin du sample
		movefa		R0,R22											; -FFFFFFC
		cmp			R23,R26
		jr			mi,DSP_LSP_routine_interruption_I2S_pas_fin_de_sample_channel0
		shrq		#nb_bits_virgule_offset,R17								; ancien pointeur adresse sample partie entiere

; fin de sample => on recharge les infos des registres externes
		shlq		#32-nb_bits_virgule_offset,R26
		;movei		#LSP_DSP_PAULA_AUD0LEN,R27			; fin, a virgule
		load		(R15+(LSP_variables_table__total_size*3)+LSP_variables_table__index_external_length),R27
		;movefa		R19,R27
		shrq		#32-nb_bits_virgule_offset,R26		; on ne garde que la virgule
		;movei		#LSP_DSP_PAULA_AUD0L,R24			; sample location a virgule
		load		(R15+(LSP_variables_table__total_size*3)+LSP_variables_table__index_external_location),R24
		;movefa		R20,R24
		load		(R27),R27
		load		(R24),R23
		store		R27,(R25)							; update internal sample end, a virgule
		or			R23,R26								; on garde la virgule en cours
; update R17
		move		R26,R17											; R17 = pointeur sample a virgule avant increment
		shrq		#nb_bits_virgule_offset,R17								; ancien pointeur adresse sample partie entiere
		subq		#4,R17

DSP_LSP_routine_interruption_I2S_pas_fin_de_sample_channel0:
		store		R26,(R28)							; stocke internal sample pointeur, a virgule
		shrq		#nb_bits_virgule_offset,R26								; nouveau pointeur adresse sample partie entiere
		move		R26,R25								; R25 = nouveau pointeur sample
		and			R22,R17								; ancien pointeur sample modulo 4
		and			R22,R26								; nouveau pointeur sample modulo 4
		;movei		#LSP_DSP_PAULA_AUD0DAT,R28			; 4 octets actuels
		subq		#4,R28								; de LSP_DSP_PAULA_internal_location0 => LSP_DSP_PAULA_AUD0DAT
		not			R22									; => %11
		load		(R28),R20							; R18 = octets actuels en stock
		and			R22,R25								; R25 = position octet Ã  lire
		cmp			R17,R26
		jr			eq,DSP_LSP_routine_interruption_I2S_pas_nouveau_long_word0
		shlq		#3,R25					; numero d'octet Ã  lire * 8

; il faut rafraichir R18
		load		(R26),R20							; lit 4 nouveaux octets de sample
		store		R20,(R28)							; rafraichit le stockage des 4 octets

DSP_LSP_routine_interruption_I2S_pas_nouveau_long_word0:
		;movei		#LSP_DSP_PAULA_AUD0VOL,R23
		subq		#4,R28								; de LSP_DSP_PAULA_AUD0DAT => LSP_DSP_PAULA_AUD0VOL
		neg			R25									; -0 -8 -16 -24

		sh			R25,R20								; shift les 4 octets en stock vers la gauche, pour positionner l'octet Ã  lire en haut
		load		(R28),R26							; R26 = volume : 6 bits right
		sharq		#24,R20								; descends l'octet Ã  lire
		subq		#4,R28									; pointe sur volume left
		move		R20,R21								; R20 & R21 = sample signÃ©
		load		(R28),R28								; R28 = volume panned left
		imult		R26,R20							; R20=right
		imult		R28,R21							; R21=left unsigned multiplication : unsigned sample * volume => 8bits + 6 bits = 14 bits
		add			R20,R19							; R19=right
		add			R21,R18							; R18=left

; R18 = sample left
; R19 = sample right


; StÃ©reo Amiga:
; les canaux 0 et 3 formant la voie stÃ©rÃ©o gauche et 1 et 2 la voie stÃ©rÃ©o droite
; R18=channel 0
; R19=channel 1
; R20=channel 2
; R21=channel 3



; gestion des sounds
; R18 = sample left
; R19 = sample right
; ----------
		movefa		R1,R15


; Sound 3
		load		(R15),R28
		load		(R15+1),R27
		load		(R28),R26										; R26=current pointeur sample 16:16
		load		(R27),R27										; R27=increment 16:16
		move		R26,R17											; R17 = pointeur sample a virgule avant increment
		load		(R15+2),R25
		add			R27,R26											; R26=adresse+increment , a virgule
		load		(R25),R23
		movefa		R0,R22
		cmp			R23,R26
		jr			mi,DSP_LSP_routine_interruption_I2S_pas_fin_de_sample_channel_sound3
		shrq		#nb_bits_virgule_offset,R17								; ancien pointeur adresse sample partie entiere

; fin de sample => on recharge les infos des registres externes
		shlq		#32-nb_bits_virgule_offset,R26
		load		(R15+3),R27
		shrq		#32-nb_bits_virgule_offset,R26		; on ne garde que la virgule
		load		(R15+4),R24
		load		(R27),R27
		load		(R24),R23
		store		R27,(R25)							; update internal sample end, a virgule
		or			R23,R26								; on garde la virgule en cours
; update R17
		move		R26,R17											; R17 = pointeur sample a virgule avant increment
		shrq		#nb_bits_virgule_offset,R17								; ancien pointeur adresse sample partie entiere
		subq		#4,R17

DSP_LSP_routine_interruption_I2S_pas_fin_de_sample_channel_sound3:
		store		R26,(R28)							; stocke internal sample pointeur, a virgule
		shrq		#nb_bits_virgule_offset,R26								; nouveau pointeur adresse sample partie entiere
														;shrq		#nb_bits_virgule_offset,R17								; ancien pointeur adresse sample partie entiere
		move		R26,R25								; R25 = nouveau pointeur sample
		and			R22,R17								; ancien pointeur sample modulo 4
		and			R22,R26								; nouveau pointeur sample modulo 4
		subq		#4,R28								; de LSP_DSP_PAULA_internal_location3 => LSP_DSP_PAULA_AUD3DAT
		not			R22									; => %11
		load		(R28),R21							; R21 = octets actuels en stock
		and			R22,R25								; R25 = position octet Ã  lire
		cmp			R17,R26
		jr			eq,DSP_LSP_routine_interruption_I2S_pas_nouveau_long_word_sound3
		shlq		#3,R25					; numero d'octet Ã  lire * 8

; il faut rafraichir R21
		load		(R26),R21							; lit 4 nouveaux octets de sample
		store		R21,(R28)							; rafraichit le stockage des 4 octets

DSP_LSP_routine_interruption_I2S_pas_nouveau_long_word_sound3:
		subq		#4,R28								; de LSP_DSP_PAULA_AUD3DAT => LSP_DSP_PAULA_AUD3VOL
		neg			R25									; -0 -8 -16 -24
; R25=numero d'octet Ã  lire
		load		(R28),R26							; R26 = volume : 6 bits right
		sh			R25,R21								; shift les 4 octets en stock vers la gauche, pour positionner l'octet Ã  lire en haut
		sharq		#24,R21								; descends l'octet Ã  lire
		subq		#4,R28									; pointe sur volume left
		move		R21,R20								; R20 & R21 = sample signÃ©
		load		(R28),R28								; R28 = volume panned left
		imult		R26,R20							; R20=right
		imult		R28,R21							; R21=left unsigned multiplication : unsigned sample * volume => 8bits + 6 bits = 14 bits
		add			R20,R19							; R19=right
		add			R21,R18							; R18=left



; Sound 2
		load		(R15+5),R28
		load		(R15+6),R27
		load		(R28),R26										; R26=current pointeur sample 16:16
		load		(R27),R27										; R27=increment 16:16
		move		R26,R17											; R17 = pointeur sample a virgule avant increment
		load		(R15+7),R25									; sample end 16:16
		add			R27,R26											; R26=adresse+increment , a virgule
		load		(R25),R23
		movefa		R0,R22
		cmp			R23,R26
		jr			mi,DSP_LSP_routine_interruption_I2S_pas_fin_de_sample_channel_sound2
		shrq		#nb_bits_virgule_offset,R17								; ancien pointeur adresse sample partie entiere

; fin de sample => on recharge les infos des registres externes
		shlq		#32-nb_bits_virgule_offset,R26
		load		(R15+8),R27
		shrq		#32-nb_bits_virgule_offset,R26		; on ne garde que la virgule
		load		(R15+9),R24
		load		(R27),R27
		load		(R24),R23
		store		R27,(R25)							; update internal sample end, a virgule
		or			R23,R26								; on garde la virgule en cours
		; update R17
		move		R26,R17											; R17 = pointeur sample a virgule avant increment
		shrq		#nb_bits_virgule_offset,R17								; ancien pointeur adresse sample partie entiere
		subq		#4,R17

DSP_LSP_routine_interruption_I2S_pas_fin_de_sample_channel_sound2:
		store		R26,(R28)							; stocke internal sample pointeur, a virgule
		shrq		#nb_bits_virgule_offset,R26								; nouveau pointeur adresse sample partie entiere
														;shrq		#nb_bits_virgule_offset,R17								; ancien pointeur adresse sample partie entiere
		move		R26,R25								; R25 = nouveau pointeur sample
		and			R22,R17								; ancien pointeur sample modulo 4
		and			R22,R26								; nouveau pointeur sample modulo 4
		subq		#4,R28								; de LSP_DSP_PAULA_internal_location3 => LSP_DSP_PAULA_AUD3DAT
		not			R22									; => %11
		load		(R28),R21							; R21 = octets actuels en stock
		and			R22,R25								; R25 = position octet Ã  lire
		cmp			R17,R26
		jr			eq,DSP_LSP_routine_interruption_I2S_pas_nouveau_long_word_sound2
		shlq		#3,R25					; numero d'octet Ã  lire * 8

; il faut rafraichir R21
		load		(R26),R21							; lit 4 nouveaux octets de sample
		store		R21,(R28)							; rafraichit le stockage des 4 octets

DSP_LSP_routine_interruption_I2S_pas_nouveau_long_word_sound2:
		subq		#4,R28								; de LSP_DSP_PAULA_AUD3DAT => LSP_DSP_PAULA_AUD3VOL
		neg			R25									; -0 -8 -16 -24
; R25=numero d'octet Ã  lire
		load		(R28),R26							; R26 = volume : 6 bits right
		sh			R25,R21								; shift les 4 octets en stock vers la gauche, pour positionner l'octet Ã  lire en haut
		sharq		#24,R21								; descends l'octet Ã  lire
		subq		#4,R28									; pointe sur volume left
		move		R21,R20								; R20 & R21 = sample signÃ©
		load		(R28),R28								; R28 = volume panned left
		imult		R26,R20							; R20=right
		imult		R28,R21							; R21=left unsigned multiplication : unsigned sample * volume => 8bits + 6 bits = 14 bits
		add			R20,R19							; R19=right
		add			R21,R18							; R18=left




; Sound 1
		load		(R15+10),R28
		load		(R15+11),R27
		load		(R28),R26										; R26=current pointeur sample 16:16
		load		(R27),R27										; R27=increment 16:16
		move		R26,R17											; R17 = pointeur sample a virgule avant increment
		load		(R15+12),R25
		add			R27,R26											; R26=adresse+increment , a virgule
		load		(R25),R23
		movefa		R0,R22
		cmp			R23,R26
		jr			mi,DSP_LSP_routine_interruption_I2S_pas_fin_de_sample_channel_sound1
		shrq		#nb_bits_virgule_offset,R17								; ancien pointeur adresse sample partie entiere

; fin de sample => on recharge les infos des registres externes
		shlq		#32-nb_bits_virgule_offset,R26
		load		(R15+13),R27
		shrq		#32-nb_bits_virgule_offset,R26		; on ne garde que la virgule
		load		(R15+14),R24
		load		(R27),R27
		load		(R24),R23
		store		R27,(R25)							; update internal sample end, a virgule
		or			R23,R26								; on garde la virgule en cours
; update R17
		move		R26,R17											; R17 = pointeur sample a virgule avant increment
		shrq		#nb_bits_virgule_offset,R17								; ancien pointeur adresse sample partie entiere
		subq		#4,R17

DSP_LSP_routine_interruption_I2S_pas_fin_de_sample_channel_sound1:
		store		R26,(R28)							; stocke internal sample pointeur, a virgule
		shrq		#nb_bits_virgule_offset,R26								; nouveau pointeur adresse sample partie entiere
														;shrq		#nb_bits_virgule_offset,R17								; ancien pointeur adresse sample partie entiere
		move		R26,R25								; R25 = nouveau pointeur sample
		and			R22,R17								; ancien pointeur sample modulo 4
		and			R22,R26								; nouveau pointeur sample modulo 4
		subq		#4,R28								; de LSP_DSP_PAULA_internal_location3 => LSP_DSP_PAULA_AUD3DAT
		not			R22									; => %11
		load		(R28),R21							; R21 = octets actuels en stock
		and			R22,R25								; R25 = position octet Ã  lire
		cmp			R17,R26
		jr			eq,DSP_LSP_routine_interruption_I2S_pas_nouveau_long_word_sound1
		shlq		#3,R25					; numero d'octet Ã  lire * 8

; il faut rafraichir R21
		load		(R26),R21							; lit 4 nouveaux octets de sample
		store		R21,(R28)							; rafraichit le stockage des 4 octets

DSP_LSP_routine_interruption_I2S_pas_nouveau_long_word_sound1:
		subq		#4,R28								; de LSP_DSP_PAULA_AUD3DAT => LSP_DSP_PAULA_AUD3VOL
		neg			R25									; -0 -8 -16 -24
; R25=numero d'octet Ã  lire
		load		(R28),R26							; R26 = volume : 6 bits right
		sh			R25,R21								; shift les 4 octets en stock vers la gauche, pour positionner l'octet Ã  lire en haut
		sharq		#24,R21								; descends l'octet Ã  lire
		subq		#4,R28									; pointe sur volume left
		move		R21,R20								; R20 & R21 = sample signÃ©
		load		(R28),R28								; R28 = volume panned left
		imult		R26,R20							; R20=right
		imult		R28,R21							; R21=left unsigned multiplication : unsigned sample * volume => 8bits + 6 bits = 14 bits
		add			R20,R19							; R19=right
		add			R21,R18							; R18=left

; Sound 0
		load		(R15+15),R28
		load		(R15+16),R27
		load		(R28),R26										; R26=current pointeur sample 16:16
		load		(R27),R27										; R27=increment 16:16
		move		R26,R17											; R17 = pointeur sample a virgule avant increment
		load		(R15+17),R25
		add			R27,R26											; R26=adresse+increment , a virgule
		load		(R25),R23
		movefa		R0,R22
		cmp			R23,R26
		jr			mi,DSP_LSP_routine_interruption_I2S_pas_fin_de_sample_channel_sound0
		shrq		#nb_bits_virgule_offset,R17								; ancien pointeur adresse sample partie entiere

; fin de sample => on recharge les infos des registres externes
		shlq		#32-nb_bits_virgule_offset,R26
		load		(R15+18),R27
		shrq		#32-nb_bits_virgule_offset,R26		; on ne garde que la virgule
		load		(R15+19),R24
		load		(R27),R27								; new sample end
		load		(R24),R23								; new sample start
		store		R27,(R25)							; update internal sample end, a virgule
		or			R23,R26								; on garde la virgule en cours
; update R17
		move		R26,R17											; R17 = pointeur sample a virgule avant increment
		shrq		#nb_bits_virgule_offset,R17								; ancien pointeur adresse sample partie entiere
		subq		#4,R17

DSP_LSP_routine_interruption_I2S_pas_fin_de_sample_channel_sound0:
		store		R26,(R28)							; stocke internal sample pointeur, a virgule
		shrq		#nb_bits_virgule_offset,R26								; nouveau pointeur adresse sample partie entiere
														;shrq		#nb_bits_virgule_offset,R17								; ancien pointeur adresse sample partie entiere
		move		R26,R25								; R25 = nouveau pointeur sample
		and			R22,R17								; ancien pointeur sample modulo 4
		and			R22,R26								; nouveau pointeur sample modulo 4
		subq		#4,R28								; de LSP_DSP_PAULA_internal_location3 => LSP_DSP_PAULA_AUD3DAT
		not			R22									; => %11
		load		(R28),R21							; R21 = octets actuels en stock
		and			R22,R25								; R25 = position octet Ã  lire
		cmp			R17,R26
		jr			eq,DSP_LSP_routine_interruption_I2S_pas_nouveau_long_word_sound0
		shlq		#3,R25					; numero d'octet Ã  lire * 8

; il faut rafraichir R21
		load		(R26),R21							; lit 4 nouveaux octets de sample
		store		R21,(R28)							; rafraichit le stockage des 4 octets

DSP_LSP_routine_interruption_I2S_pas_nouveau_long_word_sound0:
		subq		#4,R28								; de LSP_DSP_PAULA_AUD3DAT => LSP_DSP_PAULA_AUD3VOL
		neg			R25									; -0 -8 -16 -24
; R25=numero d'octet Ã  lire
		load		(R28),R26							; R26 = volume : 6 bits right
		sh			R25,R21								; shift les 4 octets en stock vers la gauche, pour positionner l'octet Ã  lire en haut
		sharq		#24,R21								; descends l'octet Ã  lire
		subq		#4,R28									; pointe sur volume left
		move		R21,R20								; R20 & R21 = sample signÃ©
		load		(R28),R28								; R28 = volume panned left
		imult		R26,R20							; R20=right
		imult		R28,R21							; R21=left unsigned multiplication : unsigned sample * volume => 8bits + 6 bits = 14 bits
		add			R20,R19							; R19=right
		add			R21,R18							; R18=left


; on passe de ( ( 8+6+7)=21  *8 = 24 bits
		movei		#L_I2S,R27
		sharq		#8,R19
		sharq		#8,R18
		sat16s		R19
		sat16s		R18
		movei		#L_I2S+4,R25
		store		R19,(R27)			; write right channel
		store		R18,(R25)			; write left channel

; test trop fort
	;movei		#(-32768),R27
	;movei		#32767,R25
	;cmp			R25,R19
	;jr			mi,I2S_EDZ_OK
	;nop
	;nop
;I2S_EDZ_OK:




	.if		DSP_DEBUG
; change la couleur du fond
	movei	#$000,R26
	movei	#BG,r27
	storew	r26,(r27)
	.endif

DSP_LSP_routine_interruption_I2S__return:
;------------------------------------
; return from interrupt I2S
	load	(r31),r28	; return address
	bset	#10,r29		; clear latch 1 = I2S
	;bset	#11,r29		; clear latch 1 = timer 1
	;bset	#12,r29		; clear latch 1 = timer 2
	bclr	#3,r29		; clear IMASK
	addq	#4,r31		; pop from stack
	addqt	#2,r28		; next instruction
	;store	r29,(r30)	; restore flags
	jump	t,(r28)		; return
	;nop
	store	r29,(r30)	; restore flags


;--------------------------------------------
; ---------------- Timer 1 ------------------
;--------------------------------------------
; autorise interruptions, pour timer I2S
;
; registres utilisÃ©s :
;		R13/R16   /R31
;		R0/R1/R2/R3/R4/R5/R6/R7/R8/R9/R10  R12/R13/R14/R16

DSP_LSP_routine_interruption_Timer1__shutdown_now:
	cmpq		#10,R0
	jr			eq,DSP_LSP_routine_interruption_Timer1__shutdown_now__just_no_play
	load	(r31),r12	; return address
; return from interrupt Timer 1
	bclr		#6,R13	; clear Timer 1 Interrupt Enable Bit
	store	R6,(R3)	; DSP_FLAG_STOP_DSP = 3 => stop timer 2
DSP_LSP_routine_interruption_Timer1__shutdown_now__just_no_play:
	bset	#11,r13		; clear latch 1 = timer 1
	bclr	#3,r13		; clear IMASK
	addq	#4,r31		; pop from stack
	addqt	#2,r12		; next instruction
	jump	t,(r12)		; return
	store	r13,(r16)	; restore flags

DSP_LSP_routine_interruption_Timer1:

; test shutdown flag
	movei		#DSP_FLAG_STOP_DSP,R3
	movei		#DSP_LSP_routine_interruption_Timer1__shutdown_now,R14
	load			(R3),R0
	cmpq			#2-1,R0			; 2 = stop timer 1 after stop I2S
	jump			hi,(R14)
	moveq		#3,R6

; flag replay ON
	movei		#DSP_LSP_replay_ON,R0
	movei		#DSP_LSP_recolle_music_ON,R3
	load		(R0),R6
	cmpq		#1,R6
	jump		eq,(R3)
	nop
	movei		#LSP_DSP_PAULA_AUD0VOL_left,R14
	moveq		#0,R0
	store		R0,(R14)				; LSP_DSP_PAULA_AUD0VOL_left
	store		R0,(R14+1)			; LSP_DSP_PAULA_AUD0VOL_right
	store		R0,(R14+13)			; LSP_DSP_PAULA_AUD1VOL_left
	store		R0,(R14+14)			; LSP_DSP_PAULA_AUD1VOL_right
	store		R0,(R14+26)			; LSP_DSP_PAULA_AUD2VOL_left
	store		R0,(R14+27)			; LSP_DSP_PAULA_AUD2VOL_right
	movei		#LSP_DSP_PAULA_AUD3VOL_left,R14
	store		R0,(R14)				; LSP_DSP_PAULA_AUD3VOL_left
	store		R0,(R14+1)			; LSP_DSP_PAULA_AUD3VOL_right
; sound
	.if				1=0
	movei		#LSP_DSP_SOUND_AUD3VOL_left,R14
	store		R0,(R14)			; LSP_DSP_SOUND_AUD0VOL_left
	store		R0,(R14+1)			;
	store		R0,(R14+11)			; LSP_DSP_SOUND_AUD1VOL_left
	store		R0,(R14+12)			;
	store		R0,(R14+22)				; LSP_DSP_SOUND_AUD2VOL_left
	store		R0,(R14+23)			;
	movei		#LSP_DSP_SOUND_AUD0VOL_left,R14
	store		R0,(R14)			; LSP_DSP_SOUND_AUD3VOL_left
	store		R0,(R14+1)			;
	.endif
	movei		#DSP_LSP_recolle_music_off,R3
	jump			(R3)
	nop


DSP_LSP_recolle_music_ON:
; gestion replay LSP

	movei		#LSPVars,R14
	load		(R14),R0					; R0 = byte stream


	.if			TEST_FIN_LSP_FORCE=1
; test la fin du byte stream
	load		(R14+10),R6					; end of byte stream
	cmp		R6,R0								; end reached ?
	jr				ne,timer1_replay_lsp_not_end_of_stream
	nop
	load		(R14+8),R0			; bouclage : R0 = byte stream / m_byteStreamLoop = 8
	load		(R14+9),R3			; m_wordStreamLoop=9
	store		R3,(R14+1)				; m_wordStream=1
timer1_replay_lsp_not_end_of_stream:
	.endif


DSP_LSP_Timer1_process:
	moveq		#0,R2
DSP_LSP_Timer1_cloop:

	loadb		(R0),R6						; R6 = byte code
	addq		#1,R0

	cmpq		#0,R6
	jr			ne,DSP_LSP_Timer1_swCode
	nop
	movei		#$0100,R3
	add			R3,R2
	jr			DSP_LSP_Timer1_cloop
	nop

DSP_LSP_Timer1_swCode:
	add			R2,R6
	move		R6,R2

	add			R2,R2
	load		(R14+2),R3			; R3=code table / m_codeTableAddr
	add			R2,R3
	movei		#DSP_LSP_Timer1_noInst,R12
	loadw		(R3),R2									; R2 = code
	cmpq		#0,R2
	jump		eq,(R12)
	nop
	load		(R14+3),R4			; R4=escape code rewind / m_escCodeRewind
	movei		#DSP_LSP_Timer1_r_rewind,R12
	cmp			R4,R2
	jump		eq,(R12)
	nop
	load		(R14+4),R4			; R4=escape code set bpm / m_escCodeSetBpm
	movei		#DSP_LSP_Timer1_r_chgbpm,R12
	cmp			R4,R2
	jump		eq,(R12)
	nop

;--------------------------
; gestion des volumes
;--------------------------
;
	movei		#DSP_Master_Volume_Music,R3
; test volume canal 3
	movei		#DSP_LSP_Timer1_noVd,R12
	load		(R3),R3				; R3 = master volime, 0 Ã  256
	movei		#63,R1
	btst		#7,R2
	jump		eq,(R12)
	nop
	loadb		(R0),R4				; load le volume / R4=volume
	movei		#LSP_DSP_panning_left3,R7
	cmp			R1,R4
	jr			mi,DSP_LSP_Timer1_noVd__vol_OK
	nop
	move		R1,R4
DSP_LSP_Timer1_noVd__vol_OK:
	move		R4,R9					; R9 = volume
	movei		#LSP_DSP_panning_right3,R10
	load		(R7),R8				; R8=panning left
	movei		#LSP_DSP_PAULA_AUD3VOL_left,R5
	imult		R8,R4					; R4 = volume panned
	movei		#LSP_DSP_PAULA_AUD3VOL_right,R6
	mult		R3,R4					; * master volume 8 bits
	load		(R10),R8				; R8= panning right
	sharq		#8,R4
	store		R4,(R5)
	mult		R8,R9					; R9=volume panned right
	or			R9,R9
	mult		R3,R9					; * master volume 8 bits
	addq		#1,R0
	sharq		#8,R9
	store		R9,(R6)
DSP_LSP_Timer1_noVd:
; test volume canal 2
	movei		#DSP_LSP_Timer1_noVc,R12
	btst		#6,R2
	jump		eq,(R12)
	nop
	loadb		(R0),R4				; load le volume / R4=volume
	movei		#LSP_DSP_panning_left2,R7
	cmp			R1,R4
	jr			mi,DSP_LSP_Timer1_noVc__vol_OK
	nop
	move		R1,R4
DSP_LSP_Timer1_noVc__vol_OK:
	move		R4,R9					; R9 = volume
	movei		#LSP_DSP_panning_right2,R10
	load		(R7),R8				; R8=panning left
	movei		#LSP_DSP_PAULA_AUD2VOL_left,R5
	imult		R8,R4					; R4 = volume panned
	movei		#LSP_DSP_PAULA_AUD2VOL_right,R6
	mult		R3,R4					; * master volume 8 bits
	load		(R10),R8				; R8= panning right
	sharq		#8,R4
	store		R4,(R5)
	mult		R8,R9					; R9=volume panned right
	mult		R3,R9					; * master volume 8 bits
	addq		#1,R0
	sharq		#8,R9
	store		R9,(R6)
DSP_LSP_Timer1_noVc:
; test volume canal 1
	movei		#DSP_LSP_Timer1_noVb,R12
	btst		#5,R2
	jump		eq,(R12)
	nop
	loadb		(R0),R4				; load le volume / R4=volume
	movei		#LSP_DSP_panning_left1,R7
	cmp			R1,R4
	jr			mi,DSP_LSP_Timer1_noVb__vol_OK
	nop
	move		R1,R4
DSP_LSP_Timer1_noVb__vol_OK:
	move		R4,R9					; R9 = volume
	movei		#LSP_DSP_panning_right1,R10
	load		(R7),R8				; R8=panning left
	movei		#LSP_DSP_PAULA_AUD1VOL_left,R5
	imult		R8,R4					; R4 = volume panned
	movei		#LSP_DSP_PAULA_AUD1VOL_right,R6
	mult		R3,R4					; * master volume 8 bits
	load		(R10),R8				; R8= panning right
	sharq		#8,R4
	store		R4,(R5)
	mult		R8,R9					; R9=volume panned right
	mult		R3,R9					; * master volume 8 bits
	addq		#1,R0
	sharq		#8,R9
	store		R9,(R6)
DSP_LSP_Timer1_noVb:
; test volume canal 0
	movei		#DSP_LSP_Timer1_noVa,R12
	btst		#4,R2
	jump		eq,(R12)
	nop
	loadb		(R0),R4				; load le volume / R4=volume
	movei		#LSP_DSP_panning_left0,R7
	cmp			R1,R4
	jr			mi,DSP_LSP_Timer1_noVa__vol_OK
	nop
	move		R1,R4
DSP_LSP_Timer1_noVa__vol_OK:
	move		R4,R9					; R9 = volume
	movei		#LSP_DSP_panning_right0,R10
	load		(R7),R8				; R8=panning left
	movei		#LSP_DSP_PAULA_AUD0VOL_left,R5
	imult		R8,R4					; R4 = volume panned
	movei		#LSP_DSP_PAULA_AUD0VOL_right,R6
	mult		R3,R4					; * master volume 8 bits
	load		(R10),R8				; R8= panning right
	sharq		#8,R4
	store		R4,(R5)
	mult		R8,R9					; R9=volume panned right
	mult		R3,R9					; * master volume 8 bits
	addq		#1,R0
	sharq		#8,R9
	store		R9,(R6)
DSP_LSP_Timer1_noVa:

	.if			LSP_avancer_module=1
	store		R0,(R14)									; store byte stream ptr
	.endif
	addq		#4,R14									; avance a word stream ptr
	load		(R14),R0									; R0 = word stream

;--------------------------
; gestion des notes
;--------------------------
; test period canal 3
	btst		#3,R2
	jr			eq,DSP_LSP_Timer1_noPd
	nop
	loadw		(R0),R4
	movei		#LSP_DSP_PAULA_AUD3PER,R5
	addq		#2,R0
	store		R4,(R5)
DSP_LSP_Timer1_noPd:
; test period canal 2
	btst		#2,R2
	jr			eq,DSP_LSP_Timer1_noPc
	nop
	loadw		(R0),R4
	movei		#LSP_DSP_PAULA_AUD2PER,R5
	addq		#2,R0
	store		R4,(R5)
DSP_LSP_Timer1_noPc:
; test period canal 1
	btst		#1,R2
	jr			eq,DSP_LSP_Timer1_noPb
	nop
	loadw		(R0),R4
	movei		#LSP_DSP_PAULA_AUD1PER,R5
	addq		#2,R0
	store		R4,(R5)
DSP_LSP_Timer1_noPb:
; test period canal 0
	btst		#0,R2
	jr			eq,DSP_LSP_Timer1_noPa
	nop
	loadw		(R0),R4
	movei		#LSP_DSP_PAULA_AUD0PER,R5
	addq		#2,R0
	store		R4,(R5)
DSP_LSP_Timer1_noPa:

; pas de test des 8 bits du haut en entier pour zapper la lecture des instruments
; tst.w	d0							; d0.w, avec d0.b qui a avancÃ© ! / beq.s	.noInst

	load		(R14+4),R5		; R5= instrument table  ( =+$10)  = a2   / m_lspInstruments-1 = 5-1

;--------------------------
; gestion des instruments
;--------------------------
;--- test instrument voie 3
	movei		#DSP_LSP_Timer1_setIns3,R12
	btst		#15,R2
	jump		ne,(R12)
	nop

	movei		#DSP_LSP_Timer1_skip3,R12
	btst		#14,R2
	jump		eq,(R12)
	nop

; repeat voie 3
	movei		#LSP_DSP_repeat_pointeur3,R3
	movei		#LSP_DSP_repeat_length3,R4
	load		(R3),R3					; pointeur sauvegardÃ©, sur infos de repeats
	load		(R4),R4
	movei		#LSP_DSP_PAULA_AUD3L,R7
	movei		#LSP_DSP_PAULA_AUD3LEN,R8
	store		R3,(R7)
	store		R4,(R8)					; stocke le pointeur sample de repeat dans LSP_DSP_PAULA_AUD3L
	jump		(R12)				; jump en DSP_LSP_Timer1_skip3
	nop

DSP_LSP_Timer1_setIns3:
	loadw		(R0),R3				; offset de l'instrument par rapport au precedent
; addition en .w
; passage en .L
	shlq		#16,R3
	sharq		#16,R3
	add			R3,R5				;R5=pointeur datas instruments
	addq		#2,R0


	movei		#LSP_DSP_PAULA_AUD3L,R7
	loadw		(R5),R6
	addq		#2,R5
	shlq		#16,R6
	loadw		(R5),R8
	or			R8,R6
	movei		#LSP_DSP_PAULA_AUD3LEN,R8
	shlq		#nb_bits_virgule_offset,R6
	store		R6,(R7)				; stocke le pointeur sample a virgule dans LSP_DSP_PAULA_AUD3L
	addq		#2,R5
	loadw		(R5),R9				; .w = R9 = taille du sample
	shlq		#nb_bits_virgule_offset,R9				; en 16:16
	add			R6,R9				; taille devient fin du sample, a virgule
	store		R9,(R8)				; stocke la nouvelle fin a virgule
	addq		#2,R5				; positionne sur pointeur de repeat
; repeat pointeur
	movei		#LSP_DSP_repeat_pointeur3,R7
	loadw		(R5),R4
	addq		#2,R5
	shlq		#16,R4
	loadw		(R5),R8
	or			R8,R4
	addq		#2,R5
	shlq		#nb_bits_virgule_offset,R4
	store		R4,(R7)				; pointeur sample repeat, a virgule
; repeat length
	movei		#LSP_DSP_repeat_length3,R7
	loadw		(R5),R8				; .w = R8 = taille du sample
	shlq		#nb_bits_virgule_offset,R8				; en 16:16
	add			R4,R8
	store		R8,(R7)				; stocke la nouvelle taille
	subq		#4,R5

; test le reset pour prise en compte immediate du changement de sample
	movei		#DSP_LSP_Timer1_noreset3,R12
	btst		#14,R2
	jump		eq,(R12)
	nop
; reset a travers le dmacon, il faut rafraichir : LSP_DSP_PAULA_internal_location3 & LSP_DSP_PAULA_internal_length3 & LSP_DSP_PAULA_internal_offset3=0
	movei		#LSP_DSP_PAULA_internal_location3,R7
	movei		#LSP_DSP_PAULA_internal_length3,R8
	store		R6,(R7)				; stocke le pointeur sample dans LSP_DSP_PAULA_internal_location3
	store		R9,(R8)				; stocke la nouvelle taille en 16:16: dans LSP_DSP_PAULA_internal_length3
; remplace les 4 octets en stock
	move		R6,R12
	shrq		#nb_bits_virgule_offset+2,R12	; enleve la virgule  + 2 bits du bas
	movei		#LSP_DSP_PAULA_AUD3DAT,R8
	shlq		#2,R12
	load		(R12),R7
	store		R7,(R8)


DSP_LSP_Timer1_noreset3:
DSP_LSP_Timer1_skip3:

;--- test instrument voie 2
	movei		#DSP_LSP_Timer1_setIns2,R12
	btst		#13,R2
	jump		ne,(R12)
	nop

	movei		#DSP_LSP_Timer1_skip2,R12
	btst		#12,R2
	jump		eq,(R12)
	nop

; repeat voie 2
	movei		#LSP_DSP_repeat_pointeur2,R3
	movei		#LSP_DSP_repeat_length2,R4
	load		(R3),R3					; pointeur sauvegardÃ©, sur infos de repeats
	load		(R4),R4
	movei		#LSP_DSP_PAULA_AUD2L,R7
	movei		#LSP_DSP_PAULA_AUD2LEN,R8
	store		R3,(R7)
	store		R4,(R8)					; stocke le pointeur sample de repeat dans LSP_DSP_PAULA_AUD3L
	jump		(R12)				; jump en DSP_LSP_Timer1_skip3
	nop

DSP_LSP_Timer1_setIns2:
	loadw		(R0),R3				; offset de l'instrument par rapport au precedent
; addition en .w
; passage en .L
	shlq		#16,R3
	sharq		#16,R3
	add			R3,R5				;R5=pointeur datas instruments
	addq		#2,R0


	movei		#LSP_DSP_PAULA_AUD2L,R7
	loadw		(R5),R6
	addq		#2,R5
	shlq		#16,R6
	loadw		(R5),R8
	or			R8,R6
	movei		#LSP_DSP_PAULA_AUD2LEN,R8
	shlq		#nb_bits_virgule_offset,R6
	store		R6,(R7)				; stocke le pointeur sample a virgule dans LSP_DSP_PAULA_AUD3L
	addq		#2,R5
	loadw		(R5),R9				; .w = R9 = taille du sample
	shlq		#nb_bits_virgule_offset,R9				; en 16:16
	add			R6,R9				; taille devient fin du sample, a virgule
	store		R9,(R8)				; stocke la nouvelle fin a virgule
	addq		#2,R5				; positionne sur pointeur de repeat
; repeat pointeur
	movei		#LSP_DSP_repeat_pointeur2,R7
	loadw		(R5),R4
	addq		#2,R5
	shlq		#16,R4
	loadw		(R5),R8
	or			R8,R4
	addq		#2,R5
	shlq		#nb_bits_virgule_offset,R4
	store		R4,(R7)				; pointeur sample repeat, a virgule
; repeat length
	movei		#LSP_DSP_repeat_length2,R7
	loadw		(R5),R8				; .w = R8 = taille du sample
	shlq		#nb_bits_virgule_offset,R8				; en 16:16
	add			R4,R8
	store		R8,(R7)				; stocke la nouvelle taille
	subq		#4,R5

; test le reset pour prise en compte immediate du changement de sample
	movei		#DSP_LSP_Timer1_noreset2,R12
	btst		#12,R2
	jump		eq,(R12)
	nop
; reset a travers le dmacon, il faut rafraichir : LSP_DSP_PAULA_internal_location3 & LSP_DSP_PAULA_internal_length3 & LSP_DSP_PAULA_internal_offset3=0
	movei		#LSP_DSP_PAULA_internal_location2,R7
	movei		#LSP_DSP_PAULA_internal_length2,R8
	store		R6,(R7)				; stocke le pointeur sample dans LSP_DSP_PAULA_internal_location3
	store		R9,(R8)				; stocke la nouvelle taille en 16:16: dans LSP_DSP_PAULA_internal_length3
; remplace les 4 octets en stock
	move		R6,R12
	shrq		#nb_bits_virgule_offset+2,R12	; enleve la virgule  + 2 bits du bas
	movei		#LSP_DSP_PAULA_AUD2DAT,R8
	shlq		#2,R12
	load		(R12),R7
	store		R7,(R8)


DSP_LSP_Timer1_noreset2:
DSP_LSP_Timer1_skip2:

;--- test instrument voie 1
	movei		#DSP_LSP_Timer1_setIns1,R12
	btst		#11,R2
	jump		ne,(R12)
	nop

	movei		#DSP_LSP_Timer1_skip1,R12
	btst		#10,R2
	jump		eq,(R12)
	nop

; repeat voie 1
	movei		#LSP_DSP_repeat_pointeur1,R3
	movei		#LSP_DSP_repeat_length1,R4
	load		(R3),R3					; pointeur sauvegardÃ©, sur infos de repeats
	load		(R4),R4
	movei		#LSP_DSP_PAULA_AUD1L,R7
	movei		#LSP_DSP_PAULA_AUD1LEN,R8
	store		R3,(R7)
	store		R4,(R8)					; stocke le pointeur sample de repeat dans LSP_DSP_PAULA_AUD3L
	jump		(R12)				; jump en DSP_LSP_Timer1_skip3
	nop

DSP_LSP_Timer1_setIns1:
	loadw		(R0),R3				; offset de l'instrument par rapport au precedent
; addition en .w
; passage en .L
	shlq		#16,R3
	sharq		#16,R3
	add			R3,R5				;R5=pointeur datas instruments
	addq		#2,R0


	movei		#LSP_DSP_PAULA_AUD1L,R7
	loadw		(R5),R6
	addq		#2,R5
	shlq		#16,R6
	loadw		(R5),R8
	or			R8,R6
	movei		#LSP_DSP_PAULA_AUD1LEN,R8
	shlq		#nb_bits_virgule_offset,R6
	store		R6,(R7)				; stocke le pointeur sample a virgule dans LSP_DSP_PAULA_AUD3L
	addq		#2,R5
	loadw		(R5),R9				; .w = R9 = taille du sample
	shlq		#nb_bits_virgule_offset,R9				; en 16:16
	add			R6,R9				; taille devient fin du sample, a virgule
	store		R9,(R8)				; stocke la nouvelle fin a virgule
	addq		#2,R5				; positionne sur pointeur de repeat
; repeat pointeur
	movei		#LSP_DSP_repeat_pointeur1,R7
	loadw		(R5),R4
	addq		#2,R5
	shlq		#16,R4
	loadw		(R5),R8
	or			R8,R4
	addq		#2,R5
	shlq		#nb_bits_virgule_offset,R4
	store		R4,(R7)				; pointeur sample repeat, a virgule
; repeat length
	movei		#LSP_DSP_repeat_length1,R7
	loadw		(R5),R8				; .w = R8 = taille du sample
	shlq		#nb_bits_virgule_offset,R8				; en 16:16
	add			R4,R8
	store		R8,(R7)				; stocke la nouvelle taille
	subq		#4,R5

; test le reset pour prise en compte immediate du changement de sample
	movei		#DSP_LSP_Timer1_noreset1,R12
	btst		#10,R2
	jump		eq,(R12)
	nop
; reset a travers le dmacon, il faut rafraichir : LSP_DSP_PAULA_internal_location3 & LSP_DSP_PAULA_internal_length3 & LSP_DSP_PAULA_internal_offset3=0
	movei		#LSP_DSP_PAULA_internal_location1,R7
	movei		#LSP_DSP_PAULA_internal_length1,R8
	store		R6,(R7)				; stocke le pointeur sample dans LSP_DSP_PAULA_internal_location3
	store		R9,(R8)				; stocke la nouvelle taille en 16:16: dans LSP_DSP_PAULA_internal_length3
; remplace les 4 octets en stock
	move		R6,R12
	shrq		#nb_bits_virgule_offset+2,R12	; enleve la virgule  + 2 bits du bas
	movei		#LSP_DSP_PAULA_AUD1DAT,R8
	shlq		#2,R12
	load		(R12),R7
	store		R7,(R8)


DSP_LSP_Timer1_noreset1:
DSP_LSP_Timer1_skip1:

;--- test instrument voie 0
	movei		#DSP_LSP_Timer1_setIns0,R12
	btst		#9,R2
	jump		ne,(R12)
	nop

	movei		#DSP_LSP_Timer1_skip0,R12
	btst		#8,R2
	jump		eq,(R12)
	nop

; repeat voie 0
	movei		#LSP_DSP_repeat_pointeur0,R3
	movei		#LSP_DSP_repeat_length0,R4
	load		(R3),R3					; pointeur sauvegardÃ©, sur infos de repeats
	load		(R4),R4
	movei		#LSP_DSP_PAULA_AUD0L,R7
	movei		#LSP_DSP_PAULA_AUD0LEN,R8
	store		R3,(R7)
	store		R4,(R8)					; stocke le pointeur sample de repeat dans LSP_DSP_PAULA_AUD3L
	jump		(R12)				; jump en DSP_LSP_Timer1_skip3
	nop

DSP_LSP_Timer1_setIns0:
	loadw		(R0),R3				; offset de l'instrument par rapport au precedent
; addition en .w
; passage en .L
	shlq		#16,R3
	sharq		#16,R3
	add			R3,R5				;R5=pointeur datas instruments
	addq		#2,R0


	movei		#LSP_DSP_PAULA_AUD0L,R7
	loadw		(R5),R6
	addq		#2,R5
	shlq		#16,R6
	loadw		(R5),R8
	or			R8,R6
	movei		#LSP_DSP_PAULA_AUD0LEN,R8
	shlq		#nb_bits_virgule_offset,R6
	store		R6,(R7)				; stocke le pointeur sample a virgule dans LSP_DSP_PAULA_AUD3L
	addq		#2,R5
	loadw		(R5),R9				; .w = R9 = taille du sample
	shlq		#nb_bits_virgule_offset,R9				; en 16:16
	add			R6,R9				; taille devient fin du sample, a virgule
	store		R9,(R8)				; stocke la nouvelle fin a virgule
	addq		#2,R5				; positionne sur pointeur de repeat
; repeat pointeur
	movei		#LSP_DSP_repeat_pointeur0,R7
	loadw		(R5),R4
	addq		#2,R5
	shlq		#16,R4
	loadw		(R5),R8
	or			R8,R4
	addq		#2,R5
	shlq		#nb_bits_virgule_offset,R4
	store		R4,(R7)				; pointeur sample repeat, a virgule
; repeat length
	movei		#LSP_DSP_repeat_length0,R7
	loadw		(R5),R8				; .w = R8 = taille du sample
	shlq		#nb_bits_virgule_offset,R8				; en 16:16
	add			R4,R8
	store		R8,(R7)				; stocke la nouvelle taille
	subq		#4,R5

; test le reset pour prise en compte immediate du changement de sample
	movei		#DSP_LSP_Timer1_noreset0,R12
	btst		#8,R2
	jump		eq,(R12)
	nop
; reset a travers le dmacon, il faut rafraichir : LSP_DSP_PAULA_internal_location3 & LSP_DSP_PAULA_internal_length3 & LSP_DSP_PAULA_internal_offset3=0
	movei		#LSP_DSP_PAULA_internal_location0,R7
	movei		#LSP_DSP_PAULA_internal_length0,R8
	store		R6,(R7)				; stocke le pointeur sample dans LSP_DSP_PAULA_internal_location3
	store		R9,(R8)				; stocke la nouvelle taille en 16:16: dans LSP_DSP_PAULA_internal_length3

; remplace les 4 octets en stock
	move		R6,R12
	shrq		#nb_bits_virgule_offset+2,R12	; enleve la virgule  + 2 bits du bas
	movei		#LSP_DSP_PAULA_AUD0DAT,R8
	shlq		#2,R12
	load		(R12),R7
	store		R7,(R8)


DSP_LSP_Timer1_noreset0:
DSP_LSP_Timer1_skip0:



DSP_LSP_Timer1_noInst:
	.if			LSP_avancer_module=1
	store		R0,(R14)			; store word stream (or byte stream if coming from early out)
	.endif


; - fin de la conversion du player LSP

; elements d'emulation Paula
; calcul des increments
; calcul de l'increment a partir de la note Amiga : (3546895 / note) / frequence I2S

; conversion period => increment voie 0
	movei		#DSP_frequence_de_replay_reelle_I2S,R0
	movei		#LSP_DSP_PAULA_internal_increment0,R1
	movei		#LSP_DSP_PAULA_AUD0PER,R2
	load		(R0),R0
	movei		#3546895,R3

	load		(R2),R2
	cmpq		#0,R2
	jr			ne,.1
	nop
	moveq		#0,R4
	jr			.2
	nop
.1:
	move		R3,R4
	div			R2,R4			; (3546895 / note)
	or			R4,R4
	shlq		#nb_bits_virgule_offset,R4
	div			R0,R4			; (3546895 / note) / frequence I2S en 16:16
	or			R4,R4
.2:
	store		R4,(R1)
; conversion period => increment voie 1
	movei		#LSP_DSP_PAULA_AUD1PER,R2
	movei		#LSP_DSP_PAULA_internal_increment1,R1
	move		R3,R4
	load		(R2),R2
	cmpq		#0,R2
	jr			ne,.12
	nop
	moveq		#0,R4
	jr			.22
	nop
.12:

	div			R2,R4			; (3546895 / note)
	or			R4,R4
	shlq		#nb_bits_virgule_offset,R4
	div			R0,R4			; (3546895 / note) / frequence I2S en 16:16
	or			R4,R4
.22:
	store		R4,(R1)

; conversion period => increment voie 2
	movei		#LSP_DSP_PAULA_AUD2PER,R2
	movei		#LSP_DSP_PAULA_internal_increment2,R1
	move		R3,R4
	load		(R2),R2
	cmpq		#0,R2
	jr			ne,.13
	nop
	moveq		#0,R4
	jr			.23
	nop
.13:
	div			R2,R4			; (3546895 / note)
	or			R4,R4
	shlq		#nb_bits_virgule_offset,R4
	div			R0,R4			; (3546895 / note) / frequence I2S en 16:16
	or			R4,R4
.23:
	store		R4,(R1)

; conversion period => increment voie 3
	movei		#LSP_DSP_PAULA_AUD3PER,R2
	movei		#LSP_DSP_PAULA_internal_increment3,R1
	move		R3,R4
	load		(R2),R2
	cmpq		#0,R2
	jr			ne,.14
	nop
	moveq		#0,R4
	jr			.24
	nop
.14:
	div			R2,R4			; (3546895 / note)
	or			R4,R4
	shlq		#nb_bits_virgule_offset,R4
	div			R0,R4			; (3546895 / note) / frequence I2S en 16:16
	or			R4,R4
.24:
	store		R4,(R1)

;--------------------------------------------------
DSP_LSP_recolle_music_off:


;--------------------------------------------------


; prise en compte des FX uploadé dans le tableau
;  #F1BA20
		movei		#DSP_tableau_upload_FX,R10
		movei		#DSP_frequence_de_replay_reelle_I2S,R12
		movei		#-1,R0
		load			(R12),R12
		moveq		#(DSP_tableau_upload_FX__fin-DSP_tableau_upload_FX)/32,R2
		movei		#DSP_timer1__FX_upload_boucle,R3
		movei		#DSP_timer1__next_FX_upload,R9
		movei		#11*4,R5

DSP_timer1__FX_upload_boucle:
		load			(R10),R1
		or				R1,R1
		cmp			R0,R1
		jump			eq,(R9)
	move				R10,R6


; on a un FX a uploader
; ordre :
	addq				#24,R6							; se positionne sur channel
	shlq				#nb_bits_virgule_offset,R1
	load				(R6),R8						; channel
	movei			#LSP_DSP_SOUND_AUD3L,R14				; dest
	mult				R5,R8								; channel * 11 *4
	move				R10,R6
	add					R8,R14								; dest + channel
	addq				#4,R6
	store			R1,(R14+6)							; d0=LSP_DSP_SOUND_internal_location = +6			OK

	load				(R6),R7									; R7 = d1 = LSP_DSP_SOUND_internal_length
	or					R7,R7
	shlq				#nb_bits_virgule_offset,R7
	store			R7,(R14+8)							; LSP_DSP_SOUND_internal_length = +8						OK
	addq				#4,R6
	load				(R6),R7									; R7 = d2 = LSP_DSP_SOUND_AUDxL
	or					R7,R7
	shlq				#nb_bits_virgule_offset,R7
	store			R7,(R14)								; LSP_DSP_SOUND_AUDxL = +0												OK
	addq				#4,R6
	load				(R6),R7									; R7 = d3 = LSP_DSP_SOUND_AUDxLEN
	or					R7,R7
	shlq				#nb_bits_virgule_offset,R7
	store			R7,(R14+1)							; LSP_DSP_SOUND_AUDxLEN = +1											OK
	addq				#4,R6
	load				(R6),R7									; R7 = d4 = LSP_DSP_SOUND_internal_increment
	or					R7,R7
	div					R12,R7
	store			R7,(R14+7)							; LSP_DSP_SOUND_internal_increment = +7					OK
	addq				#4,R6
	load				(R6),R7									; R7 = d5 = LSP_DSP_SOUND_AUD0VxL_left
	or					R7,R7
	store			R7,(R14+3)							; LSP_DSP_SOUND_AUD0VxL_left = +9								OK
	addq				#8,R6
	load				(R6),R7									; R7 = d5 = LSP_DSP_SOUND_AUD0VxL_right
	or					R7,R7
	store			R7,(R14+4)							; LSP_DSP_SOUND_AUD0VxL_left = +10							OK
	store			R0,(R10)							; remet à -1 = pas de son en stock

DSP_timer1__next_FX_upload:
	subq				#1,R2
	jump					ne,(R3)
	addqt			#32,R10





;------------------------------------
; return from interrupt Timer 1
	load	(r31),r12	; return address
	;bset	#10,r13		; clear latch 1 = I2S
	bset	#11,r13		; clear latch 1 = timer 1
	;bset	#12,r13		; clear latch 1 = timer 2
	bclr	#3,r13		; clear IMASK
	addq	#4,r31		; pop from stack
	addqt	#2,r12		; next instruction
	jump	t,(r12)		; return
	store	r13,(r16)	; restore flags

;------------------------------------
;rewind
DSP_LSP_Timer1_r_rewind:
;	movei		#LSPVars,R14
;	load		(R14),R0					; R0 = byte stream
	load		(R14+8),R0			; bouclage : R0 = byte stream / m_byteStreamLoop = 8
	movei		#DSP_LSP_Timer1_process,R12
	load		(R14+9),R3			; m_wordStreamLoop=9
	jump		(R12)
	store		R3,(R14+1)				; m_wordStream=1

;------------------------------------
; change bpm
DSP_LSP_Timer1_r_chgbpm:
	movei		#DSP_LSP_Timer1_process,R12
	loadb		(R0),R11
	store		R11,(R14+7)		; R3=nouveau bpm / m_currentBpm = 7
;application nouveau bpm dans Timer 1
	movei	#60*256,R10
	;shlq	#8,R10				; 16 bits de virgule
	div		R11,R10				; 60/bpm
	movei	#24*65536,R9				; 24=> 5 bits
	or		R10,R10
	;shlq	#16,R9
	div		R10,R9				; R9=
	or		R9,R9
	shrq	#8,R9				; R9=frequence replay
	;move	R9,R11
; frequence du timer 1
	movei	#182150,R10				; 26593900 / 146 = 182150
	div		R9,R10
	or		R10,R10
	move	R10,R14
	subq	#1,R14					; -1 pour parametrage du timer 1
; 26593900 / 50 = 531Â 878 => 2 Ã— 73 Ã— 3643 => 146*3643
	movei	#JPIT1,r10				; F10000
	movei	#145*65536,r9				; Timer 1 Pre-scaler
	;shlq	#16,r12
	or		R14,R9
	store	r9,(r10)				; JPIT1 & JPIT2



	jump		(R12)
	addq		#1,R0


DSP_LSP_routine_interruption_Timer2__shutdown_now:
; return from interrupt Timer 2
	load	(r31),r12	; return address
	bset	#12,r13		; clear latch 1 = timer 2
	store	R1,(R10)			; DSP_FLAG_STOP_DSP=4 => stop D_CTRL
	bclr	#3,r13		; clear IMASK
	bclr	#7,R13		; bit7 = Timer 2 Interrupt Enable Bit
	addq	#4,r31		; pop from stack
	addqt	#2,r12		; next instruction
	jump	t,(r12)		; return
	store	r13,(r16)	; restore flags

; ------------------- N/A ------------------
DSP_LSP_routine_interruption_Timer2:
; ------------------- N/A ------------------

; test shutdown flag
	movei		#DSP_FLAG_STOP_DSP,R10
	load			(R10),R12
	cmpq			#3,R12			; 3 = stop timer 2
	jr				eq,DSP_LSP_routine_interruption_Timer2__shutdown_now
	moveq		#4,R1

;DSP_pad1
;DSP_pad2
; lecture des 2 pads
; Pads : mask = xxxx xxCx xxBx 2580 147* oxAP 369# RLDU
; dispos : R0 Ã  R12
	movei		#DSP_pad1,R14
	movei		#DSP_pad2,R12
	movei		#JOYSTICK,R0

	movei		#%00001111000000000000000000000000,R2		; mask port 1
	movei		#%00000000000000000000000000000011,R3		; mask port 1

	movei		#%11110000000000000000000000000000,R5		; mask port 2
	movei		#%00000000000000000000000000001100,R6		; mask port 2



; row 0
	MOVEI		#$817e,R1			; =81<<8 + 0111 1110 = (A Pause) + (Right Left Down Up) / 81 pour bit 15 pour output + bit 8 pour  conserver le son ON : pad 1 & 2
									; 1110 = row 0 of joypad = Pause A Up Down Left Right
	storew		R1,(R0)				; lecture row 0
	nop
	load		(R0),R1
	;movei		#$F000000C,R3		; mask port 2

; row0 = Pause A Up Down Left Right
; 0000 1111 0000 0000 0000 0000 0000 0011
;      RLDU                            Ap
	move		R1,R10				; stocke pour lecture port 2

	move		R1,R4
	move		R10,R7
	and			R3,R4
	and			R6,R7
	and			R2,R1
	and			R5,R10
	shlq		#8,R4				; R4=Ap xxxx xxxx
	shlq		#6,R7				; R4=Ap xxxx xxxx
	shrq		#24,R1				; R1=RLDU
	shrq		#28,R10				; R10=RLDU
	or			R4,R1
	or			R7,R10
	move		R1,R8
	move		R10,R9



; row 1
	MOVEI		#$81BD,R1			; #($81 << 8)|(%1011 << 4)|(%1101),(a2) ; (B D) + (1 4 7 *)
	storew		R1,(R0)				; lecture row 1
	nop
	load		(R0),R1
; row1 =
; 0000 1111 0000 0000 0000 0000 0000 0011
;      147*                            BD
	move		R1,R10				; stocke pour lecture port 2
;row1 port 1&2

	move		R1,R4
	move		R10,R7
	and			R3,R4
	and			R6,R7
	shlq		#20,R4
	shlq		#18,R7
	and			R2,R1
	and			R5,R10
	shrq		#12,R1				; R1=147*
	shrq		#16,R10				; R10=147*
	or			R1,R4
	or			R7,R10
	or			R4,R8				; R8= BD xxxx 147* xxAp xxxx RLDU
	or			R10,R9


; row 2
	MOVEI		#$81DB,R1			; #($81 << 8)|(%1101 << 4)|(%1011),(a2) ; (C E) + (2 5 8 0)
	storew		R1,(R0)				; lecture row 2
	nop
	load		(R0),R1
	move		R1,R10				; stocke pour lecture port 2

; row2 =
; 0000 1111 0000 0000 0000 0000 0000 0011
;      2580                            CE
; 24,8,22,12
	move		R1,R4
	move		R10,R7
	and			R3,R4
	and			R6,R7
	shlq		#24,R4
	shlq		#22,R7
	and			R2,R1
	and			R5,R10
	shrq		#8,R1				; R1=147*
	shrq		#12,R10				; R10=147*
	or			R1,R4
	or			R7,R10
	or			R4,R8				; R8= BD xxxx 147* xxAp xxxx RLDU
	or			R10,R9



; row 3
	MOVEI		#$81E7,R1			; #($81 << 8)|(%1110 << 4)|(%0111),(a2) ; (Option F) + (3 6 9 #)
	storew		R1,(R0)				; lecture row 3
	nop
	load		(R0),R1
; row3 =
; 0000 1111 0000 0000 0000 0000 0000 0011
;      369#                            oF
; l10,r20,l8,r24
	move		R1,R10				; stocke pour lecture port 2

	move		R1,R4
	move		R10,R7
	and			R3,R4
	and			R6,R7
	shlq		#10,R4
	shlq		#8,R7
	and			R2,R1
	and			R5,R10
	shrq		#20,R1				; R1=147*
	shrq		#24,R10				; R10=147*
	or			R1,R4
	or			R7,R10
	or			R4,R8				; R8= BD xxxx 147* xxAp xxxx RLDU
	or			R10,R9


	not			R8
	not			R9
	store		R8,(R14)

	store		R9,(R12)





;------------------------------------
; return from interrupt Timer 2
	load	(r31),r12	; return address
	;bset	#10,r13		; clear latch 1 = I2S
	;bset	#11,r13		; clear latch 1 = timer 1
	bset	#12,r13		; clear latch 1 = timer 2
	bclr	#3,r13		; clear IMASK
	addq	#4,r31		; pop from stack
	addqt	#2,r12		; next instruction
	jump	t,(r12)		; return
	store	r13,(r16)	; restore flags



;------------------------------------------
;------------------------------------------
; ------------- main DSP ------------------
;------------------------------------------
;------------------------------------------

DSP_routine_init_DSP:
; assume run from bank 1
	movei	#DSP_ISP+(DSP_STACK_SIZE*4),r31			; init isp
	moveq	#0,r1
	moveta	r31,r31									; ISP (bank 0)
	nop
	movei	#DSP_USP+(DSP_STACK_SIZE*4),r31			; init usp

; calculs des frequences deplacÃ© dans DSP
; sclk I2S
	movei	#LSP_DSP_Audio_frequence,R0
	movei	#frequence_Video_Clock_divisee,R1
	load	(R1),R1
	shlq	#8,R1
	div		R0,R1
	or			R1,R1

	movei	#128,R2
	add		R2,R1			; +128 = +0.5
	shrq	#8,R1
	subq	#1,R1
	movei	#DSP_parametre_de_frequence_I2S,r2
	store	R1,(R2)
;calcul inverse
	addq	#1,R1
	add		R1,R1			; *2
	add		R1,R1			; *2
	shlq	#4,R1			; *16
	movei	#frequence_Video_Clock,R0
	load	(R0),R0
	div		R1,R0
	movei	#DSP_frequence_de_replay_reelle_I2S,R2
	store	R0,(R2)


; init I2S
	movei	#SCLK,r10
	movei	#SMODE,r11
	movei	#DSP_parametre_de_frequence_I2S,r12
	movei	#%001101,r13			; SMODE bascule sur RISING
	load	(r12),r12				; SCLK
	store	r12,(r10)
	store	r13,(r11)


; init Timer 1
; frq = 24/(60/bpm)
	movei	#LSP_BPM_frequence_replay,R11
	load	(R11),R11
	movei	#60*256,R10
	;shlq	#8,R10				; 16 bits de virgule
	div		R11,R10				; 60/bpm
	movei	#24*65536,R9				; 24=> 5 bits
	or		R10,R10
	;shlq	#16,R9
	div		R10,R9				; R9=
	or		R9,R9
	shrq	#8,R9				; R9=frequence replay

	move	R9,R11


; frequence du timer 1
	movei	#182150,R10				; 26593900 / 146 = 182150
	div		R11,R10
	or		R10,R10
	move	R10,R13

	subq	#1,R13					; -1 pour parametrage du timer 1



; 26593900 / 50 = 531Â 878 => 2 Ã— 73 Ã— 3643 => 146*3643
	movei	#JPIT1,r10				; F10000
	;movei	#JPIT2,r11				; F10002
	movei	#145*65536,r12				; Timer 1 Pre-scaler
	;shlq	#16,r12
	or		R13,R12

	store	r12,(r10)				; JPIT1 & JPIT2


; init timer 2
	movei	#JPIT3,r10				; F10004
	;movei	#JPIT4,r11				; F10006
	movei	#145*65536,r12			; Timer 1 Pre-scaler
	movei	#955-1,r13				; 951=200hz
	or		R13,R12
	store	r12,(r10)				; JPIT1 & JPIT2


;----------------------------
; variables pour movfa
; R0/R1/R15 : OK
	movei		#$FFFFFFFC,R0									; OK
	movei		#LSP_SOUND_variables_table,R1
	movei		#LSP_variables_table,R15
	moveta		R15,R15
;----------------------------


; registres du son R18 et R19
	moveq	#0,R18
	moveta	R18,R18
	moveta	R18,R19


; enable interrupts
	movei	#D_FLAGS,r30
	movei	#D_I2SENA|D_TIM1ENA|D_TIM2ENA|REGPAGE,r29			; I2S+Timer 1+timer 2
	;movei	#D_I2SENA|D_TIM1ENA|REGPAGE,r29			; I2S+Timer 1
	;movei	#D_I2SENA|REGPAGE,r29					; I2S only
	;movei	#D_TIM1ENA|REGPAGE,r29					; Timer 1 only
	;movei	#D_TIM2ENA|REGPAGE,r29					; Timer 2 only
	store	r29,(r30)


	movei	#DSP_engine_ON,R6
	moveq	#1,R20
	store	R20,(R6)




; ========>>>>> registres bloquÃ©s par movefa : R0/R1/R15

DSP_boucle_centrale:

	movei		#DSP_FLAG_STOP_DSP,R4
	load			(R4),R6
	or				R6,R6
	cmpq			#4,R6				; 4 = stop final
	jr				ne,DSP_boucle_centrale__GO_ON
	nop
	movei		#D_CTRL,R20
	moveq		#0,R6
	store		R6,(R4)				; DSP_FLAG_STOP_DSP=0
	nop
	nop
.wait:
	jr				.wait
	store		R6,(R20)




DSP_boucle_centrale__GO_ON:
	movei	#DSP_boucle_centrale,R28
	jump	(R28)
	nop






;------------------------------------------------------------------------------------------
	.phrase

DSP_LSP_replay_ON:									dc.l			0
DSP_FLAG_STOP_DSP:									dc.l			0


DSP_engine_ON:									dc.l			0				; 1=dsp engine started
DSP_Master_Volume_Music:						dc.l			100									; volume de 0 a 256

DSP_frequence_de_replay_reelle_I2S:					dc.l			0
DSP_UN_sur_frequence_de_replay_reelle_I2S:			dc.l			0
DSP_parametre_de_frequence_I2S:						dc.l			0

; StÃ©reo Amiga:
; les canaux 0 et 3 formant la voie stÃ©rÃ©o gauche et 1 et 2 la voie stÃ©rÃ©o droite

LSP_PAULA:
; variables Paula
; channel 0
LSP_DSP_PAULA_AUD0L:				dc.l			silence<<nb_bits_virgule_offset			; Audio channel 0 location
LSP_DSP_PAULA_AUD0LEN:				dc.l			(silence+4)<<nb_bits_virgule_offset			; en bytes !
LSP_DSP_PAULA_AUD0PER:				dc.l			0				; period , a transformer en increment
LSP_DSP_PAULA_AUD0VOL_left:			dc.l			0				; volume gauche																										+12
LSP_DSP_PAULA_AUD0VOL_right:		dc.l			0				; volume droite																									+12
LSP_DSP_PAULA_AUD0DAT:				dc.l			0				; long word en cours d'utilisation / stockÃ© / buffering
LSP_DSP_PAULA_internal_location0:	dc.l			silence<<nb_bits_virgule_offset				; internal register : location of the sample currently played
LSP_DSP_PAULA_internal_increment0:	dc.l			0				; internal register : increment linked to period 16:16
LSP_DSP_PAULA_internal_length0:		dc.l			(silence+4)<<nb_bits_virgule_offset			; internal register : length of the sample currently played
LSP_DSP_repeat_pointeur0:			dc.l			silence<<nb_bits_virgule_offset
LSP_DSP_repeat_length0:				dc.l			(silence+4)<<nb_bits_virgule_offset
LSP_DSP_panning_left0:				dc.l			0
LSP_DSP_panning_right0:				dc.l			0		;0
; channel 1
LSP_DSP_PAULA_AUD1L:				dc.l			silence<<nb_bits_virgule_offset			; Audio channel 0 location
LSP_DSP_PAULA_AUD1LEN:				dc.l			(silence+4)<<nb_bits_virgule_offset			; en bytes !
LSP_DSP_PAULA_AUD1PER:				dc.l			0				; period , a transformer en increment
LSP_DSP_PAULA_AUD1VOL_left:			dc.l			0				; volume gauche																										+12
LSP_DSP_PAULA_AUD1VOL_right:		dc.l			0				; volume droite																									+12
LSP_DSP_PAULA_AUD1DAT:				dc.l			0				; long word en cours d'utilisation / stockÃ© / buffering
LSP_DSP_PAULA_internal_location1:	dc.l			silence<<nb_bits_virgule_offset				; internal register : location of the sample currently played
LSP_DSP_PAULA_internal_increment1:	dc.l			0				; internal register : increment linked to period 16:16
LSP_DSP_PAULA_internal_length1:		dc.l			(silence+4)<<nb_bits_virgule_offset			; internal register : length of the sample currently played
LSP_DSP_repeat_pointeur1:			dc.l			silence<<nb_bits_virgule_offset
LSP_DSP_repeat_length1:				dc.l			(silence+4)<<nb_bits_virgule_offset
LSP_DSP_panning_left1:				dc.l			0		; 0
LSP_DSP_panning_right1:				dc.l			0
; channel 2
LSP_DSP_PAULA_AUD2L:				dc.l			silence<<nb_bits_virgule_offset			; Audio channel 0 location
LSP_DSP_PAULA_AUD2LEN:				dc.l			(silence+4)<<nb_bits_virgule_offset			; en bytes !
LSP_DSP_PAULA_AUD2PER:				dc.l			0				; period , a transformer en increment
LSP_DSP_PAULA_AUD2VOL_left:			dc.l			0				; volume gauche																										+12
LSP_DSP_PAULA_AUD2VOL_right:		dc.l			0				; volume droite																									+12
LSP_DSP_PAULA_AUD2DAT:				dc.l			0				; long word en cours d'utilisation / stockÃ© / buffering
LSP_DSP_PAULA_internal_location2:	dc.l			silence<<nb_bits_virgule_offset				; internal register : location of the sample currently played
LSP_DSP_PAULA_internal_increment2:	dc.l			0				; internal register : increment linked to period 16:16
LSP_DSP_PAULA_internal_length2:		dc.l			(silence+4)<<nb_bits_virgule_offset			; internal register : length of the sample currently played
LSP_DSP_repeat_pointeur2:			dc.l			silence<<nb_bits_virgule_offset
LSP_DSP_repeat_length2:				dc.l			(silence+4)<<nb_bits_virgule_offset
LSP_DSP_panning_left2:				dc.l			0			; 0
LSP_DSP_panning_right2:				dc.l			0
; channel 3
LSP_DSP_PAULA_AUD3L:				dc.l			silence<<nb_bits_virgule_offset			; Audio channel 0 location																0
LSP_DSP_PAULA_AUD3LEN:				dc.l			(silence+4)<<nb_bits_virgule_offset			; en bytes !																		+4
LSP_DSP_PAULA_AUD3PER:				dc.l			0				; period , a transformer en increment																			+8
LSP_DSP_PAULA_AUD3VOL_left:			dc.l			0				; volume gauche																										+12
LSP_DSP_PAULA_AUD3VOL_right:		dc.l			0				; volume droite																									+12
LSP_DSP_PAULA_AUD3DAT:				dc.l			0				; long word en cours d'utilisation / stockÃ© / buffering															+16
LSP_DSP_PAULA_internal_location3:	dc.l			silence<<nb_bits_virgule_offset				; internal register : location of the sample currently played						+20
LSP_DSP_PAULA_internal_increment3:	dc.l			0				; internal register : increment linked to period 16:16															+24
LSP_DSP_PAULA_internal_length3:		dc.l			(silence+4)<<nb_bits_virgule_offset			; internal register : length of the sample currently played							+28
LSP_DSP_repeat_pointeur3:			dc.l			silence<<nb_bits_virgule_offset																		;							+32
LSP_DSP_repeat_length3:				dc.l			(silence+4)<<nb_bits_virgule_offset																	;							+36
LSP_DSP_panning_left3:				dc.l			0
LSP_DSP_panning_right3:				dc.l			0			;0

; sound engine variables
; sound 3
LSP_DSP_SOUND_AUD3L:				dc.l			silence<<nb_bits_virgule_offset			; Audio channel 0 location																0
LSP_DSP_SOUND_AUD3LEN:				dc.l			(silence+4)<<nb_bits_virgule_offset			; en bytes !																		+4
LSP_DSP_SOUND_AUD3PER:				dc.l			0				; period , a transformer en increment																			+8
LSP_DSP_SOUND_AUD3VOL_left:				dc.l			0				; volume																										+12
LSP_DSP_SOUND_AUD3VOL_right:				dc.l			0				; volume																										+12
LSP_DSP_SOUND_AUD3DAT:				dc.l			0				; long word en cours d'utilisation / stockÃ© / buffering															+16
LSP_DSP_SOUND_internal_location3:	dc.l			silence<<nb_bits_virgule_offset				; internal register : location of the sample currently played						+20
LSP_DSP_SOUND_internal_increment3:	dc.l			0				; internal register : increment linked to period 16:16															+24
LSP_DSP_SOUND_internal_length3:		dc.l			(silence+4)<<nb_bits_virgule_offset			; internal register : length of the sample currently played							+28
LSP_DSP_SOUND_panning_left3:				dc.l			0
LSP_DSP_SOUND_panning_right3:				dc.l			0
; sound 2
LSP_DSP_SOUND_AUD2L:				dc.l			silence<<nb_bits_virgule_offset			; Audio channel 0 location																0
LSP_DSP_SOUND_AUD2LEN:				dc.l			(silence+4)<<nb_bits_virgule_offset			; en bytes !																		+4
LSP_DSP_SOUND_AUD2PER:				dc.l			0				; period , a transformer en increment																			+8
LSP_DSP_SOUND_AUD2VOL_left:				dc.l			0				; volume																										+12
LSP_DSP_SOUND_AUD2VOL_right:				dc.l			0				; volume																										+12
LSP_DSP_SOUND_AUD2DAT:				dc.l			0				; long word en cours d'utilisation / stockÃ© / buffering															+16
LSP_DSP_SOUND_internal_location2:	dc.l			silence<<nb_bits_virgule_offset				; internal register : location of the sample currently played						+20
LSP_DSP_SOUND_internal_increment2:	dc.l			0				; internal register : increment linked to period 16:16															+24
LSP_DSP_SOUND_internal_length2:		dc.l			(silence+4)<<nb_bits_virgule_offset			; internal register : length of the sample currently played							+28
LSP_DSP_SOUND_panning_left2:				dc.l			0
LSP_DSP_SOUND_panning_right2:				dc.l			0
; sound 1
LSP_DSP_SOUND_AUD1L:				dc.l			silence<<nb_bits_virgule_offset			; Audio channel 0 location																0
LSP_DSP_SOUND_AUD1LEN:				dc.l			(silence+4)<<nb_bits_virgule_offset			; en bytes !																		+4
LSP_DSP_SOUND_AUD1PER:				dc.l			0				; period , a transformer en increment																			+8
LSP_DSP_SOUND_AUD1VOL_left:				dc.l			0				; volume																										+12
LSP_DSP_SOUND_AUD1VOL_right:				dc.l			0				; volume																										+12
LSP_DSP_SOUND_AUD1DAT:				dc.l			0				; long word en cours d'utilisation / stockÃ© / buffering															+16
LSP_DSP_SOUND_internal_location1:	dc.l			silence<<nb_bits_virgule_offset				; internal register : location of the sample currently played						+20
LSP_DSP_SOUND_internal_increment1:	dc.l			0				; internal register : increment linked to period 16:16															+24
LSP_DSP_SOUND_internal_length1:		dc.l			(silence+4)<<nb_bits_virgule_offset			; internal register : length of the sample currently played							+28
LSP_DSP_SOUND_panning_left1:				dc.l			0
LSP_DSP_SOUND_panning_right1:				dc.l			0
; sound 0
LSP_DSP_SOUND_AUD0L:				dc.l			silence<<nb_bits_virgule_offset			; Audio channel 0 location																0
LSP_DSP_SOUND_AUD0LEN:				dc.l			(silence+4)<<nb_bits_virgule_offset			; en bytes !																		+4
LSP_DSP_SOUND_AUD0PER:				dc.l			0				; period , a transformer en increment																			+8
LSP_DSP_SOUND_AUD0VOL_left:				dc.l			0				; volume																										+12
LSP_DSP_SOUND_AUD0VOL_right:				dc.l			0				; volume																										+12
LSP_DSP_SOUND_AUD0DAT:				dc.l			0				; long word en cours d'utilisation / stockÃ© / buffering															+16
LSP_DSP_SOUND_internal_location0:	dc.l			silence<<nb_bits_virgule_offset				; internal register : location of the sample currently played						+20
LSP_DSP_SOUND_internal_increment0:	dc.l			0				; internal register : increment linked to period 16:16															+24
LSP_DSP_SOUND_internal_length0:		dc.l			(silence+4)<<nb_bits_virgule_offset			; internal register : length of the sample currently played							+28
LSP_DSP_SOUND_panning_left0:				dc.l			0
LSP_DSP_SOUND_panning_right0:				dc.l			0



;offset_LSP_DSP_PAULA_internal_location0		.equ			((LSP_DSP_PAULA_internal_location0-LSP_PAULA)/4)

LSP_DSP_PAULA_AUD0VOL_original:				dc.l			0				; volume
LSP_DSP_PAULA_AUD1VOL_original:				dc.l			0				; volume
LSP_DSP_PAULA_AUD2VOL_original:				dc.l			0				; volume
LSP_DSP_PAULA_AUD3VOL_original:				dc.l			0				; volume

; tableau des variables
LSP_variables_table:
; channel 3
		dc.l		LSP_DSP_PAULA_internal_location3
		dc.l		LSP_DSP_PAULA_internal_increment3
		dc.l		LSP_DSP_PAULA_internal_length3
		dc.l		LSP_DSP_PAULA_AUD3LEN
		dc.l		LSP_DSP_PAULA_AUD3L
;channel 2
		dc.l		LSP_DSP_PAULA_internal_location2
		dc.l		LSP_DSP_PAULA_internal_increment2
		dc.l		LSP_DSP_PAULA_internal_length2
		dc.l		LSP_DSP_PAULA_AUD2LEN
		dc.l		LSP_DSP_PAULA_AUD2L
;channel 1
		dc.l		LSP_DSP_PAULA_internal_location1
		dc.l		LSP_DSP_PAULA_internal_increment1
		dc.l		LSP_DSP_PAULA_internal_length1
		dc.l		LSP_DSP_PAULA_AUD1LEN
		dc.l		LSP_DSP_PAULA_AUD1L
;channel 0
		dc.l		LSP_DSP_PAULA_internal_location0
		dc.l		LSP_DSP_PAULA_internal_increment0
		dc.l		LSP_DSP_PAULA_internal_length0
		dc.l		LSP_DSP_PAULA_AUD0LEN
		dc.l		LSP_DSP_PAULA_AUD0L

LSP_SOUND_variables_table:
; sound 3
		dc.l		LSP_DSP_SOUND_internal_location3
		dc.l		LSP_DSP_SOUND_internal_increment3
		dc.l		LSP_DSP_SOUND_internal_length3
		dc.l		LSP_DSP_SOUND_AUD3LEN
		dc.l		LSP_DSP_SOUND_AUD3L
; sound 2
		dc.l		LSP_DSP_SOUND_internal_location2
		dc.l		LSP_DSP_SOUND_internal_increment2
		dc.l		LSP_DSP_SOUND_internal_length2
		dc.l		LSP_DSP_SOUND_AUD2LEN
		dc.l		LSP_DSP_SOUND_AUD2L
; sound 1
		dc.l		LSP_DSP_SOUND_internal_location1
		dc.l		LSP_DSP_SOUND_internal_increment1
		dc.l		LSP_DSP_SOUND_internal_length1
		dc.l		LSP_DSP_SOUND_AUD1LEN
		dc.l		LSP_DSP_SOUND_AUD1L
; sound 0
		dc.l		LSP_DSP_SOUND_internal_location0
		dc.l		LSP_DSP_SOUND_internal_increment0
		dc.l		LSP_DSP_SOUND_internal_length0
		dc.l		LSP_DSP_SOUND_AUD0LEN
		dc.l		LSP_DSP_SOUND_AUD0L


LSPVars:
m_byteStream:					dc.l			0	;  0 :  byte stream												0
m_wordStream:					dc.l			0	;  4 :  word stream												1
m_codeTableAddr:			dc.l			0	;  8 :  code table addr										2
m_escCodeRewind:			dc.l			0	; 12 :  rewind special escape code			3
m_escCodeSetBpm:		dc.l			0	; 16 :  set BPM escape code								4
m_lspInstruments:				dc.l			0	; 20 :  LSP instruments table addr			5
m_relocDone:					dc.l			0	; 24 :  reloc done flag										6
m_currentBpm:					dc.l			0	; 28 :  current BPM												7
m_byteStreamLoop:			dc.l			0	; 32 :  byte stream loop point						8
m_wordStreamLoop:		dc.l			0	; 36 :  word stream loop point						9
m_byteStream_end:		dc.l			0	 ; 40 : end address of bytestream				10
m_escCodeGetPos:			dc.l			0	 ; 44	 : escape code get pos							11




LSP_BPM_frequence_replay:		dc.l			125
LSP_pointeur_fin_module:			dc.l			0

compteur_mode_caravan:				dc.l			0


; pads
; Pads : mask = xxxxxxCx xxBx2580 147*oxAP 369#RLDU
; U235 format
;------------------------------------------------------------------------------------------------ Joypad Section

										; Pads : mask = xxxxxxCx xxBx2580 147*oxAP 369#RLDU

; 												Bit numbers for buttons in the mask for testing individual bits
U235SE_BBUT_UP			EQU		0		; Up
U235SE_BBUT_U			EQU		0
U235SE_BBUT_DOWN		EQU		1		; Down
U235SE_BBUT_D			EQU		1
U235SE_BBUT_LEFT		EQU		2		; Left
U235SE_BBUT_L			EQU		2
U235SE_BBUT_RIGHT		EQU		3		; Right
U235SE_BBUT_R			EQU		3
U235SE_BBUT_HASH		EQU		4		; Hash (#)
U235SE_BBUT_9			EQU		5		; 9
U235SE_BBUT_6			EQU		6		; 6
U235SE_BBUT_3			EQU		7		; 3
U235SE_BBUT_PAUSE		EQU		8		; Pause
U235SE_BBUT_A			EQU		9		; A button
U235SE_BBUT_OPTION		EQU		11		; Option
U235SE_BBUT_STAR		EQU		12		; Star
U235SE_BBUT_7			EQU		13		; 7
U235SE_BBUT_4			EQU		14		; 4
U235SE_BBUT_1			EQU		15		; 1
U235SE_BBUT_0			EQU		16		; 0 (zero)
U235SE_BBUT_8			EQU		17		; 8
U235SE_BBUT_5			EQU		18		; 5
U235SE_BBUT_2			EQU		19		; 2
U235SE_BBUT_B			EQU		21		; B button
U235SE_BBUT_C			EQU		25		; C button

; 												Numerical representations
U235SE_BUT_UP			EQU		1		; Up
U235SE_BUT_U			EQU		1
U235SE_BUT_DOWN			EQU		2		; Down
U235SE_BUT_D			EQU		2
U235SE_BUT_LEFT			EQU		4		; Left
U235SE_BUT_L			EQU		4
U235SE_BUT_RIGHT		EQU		8		; Right
U235SE_BUT_R			EQU		8
U235SE_BUT_HASH			EQU		16		; Hash (#)
U235SE_BUT_9			EQU		32		; 9
U235SE_BUT_6			EQU		64		; 6
U235SE_BUT_3			EQU		$80		; 3
U235SE_BUT_PAUSE		EQU		$100	; Pause
U235SE_BUT_A			EQU		$200	; A button
U235SE_BUT_OPTION		EQU		$800	; Option
U235SE_BUT_STAR			EQU		$1000	; Star
U235SE_BUT_7			EQU		$2000	; 7
U235SE_BUT_4			EQU		$4000	; 4
U235SE_BUT_1			EQU		$8000	; 1
U235SE_BUT_0			EQU		$10000	; 0 (zero)
U235SE_BUT_8			EQU		$20000	; 8
U235SE_BUT_5			EQU		$40000	; 5
U235SE_BUT_2			EQU		$80000	; 2
U235SE_BUT_B			EQU		$200000	; B button
U235SE_BUT_C			EQU		$2000000; C button

; xxxxxxCx xxBx2580 147*oxAP 369#RLDU
DSP_pad1:				dc.l		0
DSP_pad2:				dc.l		0


DSP_tableau_upload_FX:
				.rept			8*4				; 4 entrées de 8 valeurs
				dc.l				-1
				.endr
DSP_tableau_upload_FX__fin:
