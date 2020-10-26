; -----------------------------------------------------------------------------------
; Mikrokontroller alapú rendszerek házi feladat
; Készítette: Mihalik Márk
; Neptun code: ST9OKE
; Feladat leírása:
;		Belső memóriában található adott elemű számsorozat (tömb) legnagyobb és 
;		legkisebb elemének kiválasztása. Minden elem 1 bájtos előjel nélküli szám. 
;		Bemenet: tömb kezdőcíme (mutató), elemek száma. Kimenet: az előforduló 
;		legkisebb és legnagyobb elem (2 regiszterben).
; -----------------------------------------------------------------------------------

$NOMOD51 ; a sztenderd 8051 regiszter definíciók nem szükségesek


$INCLUDE (SI_EFM8BB3_Defs.inc) ; regiszter és SFR definiciók

ArrayLength 		EQU R3
OutputMax_Address 	EQU R0
OutputMin_Address 	EQU R1
Temp				EQU R2
; -----------------------------------------------------------------------------------
; Main program előtti inicializáció és keresni kívánt tömb definiálása
; -----------------------------------------------------------------------------------
; Feladat: Tömb elemeinek definiálása
; -----------------------------------------------------------------------------------

; Input tömb regisztrálása a flash memóriában
InputArray SEGMENT CODE
RSEG InputArray
; CSEG InputArray ; Rövidebb megoldás esetleges optimalizálás

Array: DB 215,51,64,74,213,3,11,51 ;Input pálda egy 7 elemű tömb
ArrayEnd:

DSEG AT 0x20
OutputMinRAM: DS 1 ; Data memóriában lefoglalunk 2 regisztert a min és max értékeknek
OutputMaxRAM: DS 1

; Ugrótábla létrehozása
	CSEG AT 0
	SJMP Main

myprog SEGMENT CODE			;saját kódszegmens létrehozása
RSEG myprog 				;saját kódszegmens létrehozása
; ------------------------------------------------------------
; Főprogram
; ------------------------------------------------------------
; Feladata: 
; ------------------------------------------------------------
Main:
	CLR IE_EA ; interruptok tilt�sa watchdog tilt�s idej�re
	MOV WDTCN,#0DEh ; watchdog timer tilt�sa
	MOV WDTCN,#0ADh
	SETB IE_EA ; interruptok enged�lyez�se

	CALL SearchMinMax
	MOV OutputMax_Address, #OutputMaxRAM
	MOV A, @OutputMax_Address
	MOV R6, A
	MOV OutputMin_Address,#OutputMinRAM
	MOV A, @OutputMin_Address
	MOV R7, A
EndLoop:
	JMP $ ; végtelen ciklusban várunk

; -----------------------------------------------------------
; Sample szubrutin
; -----------------------------------------------------------
; Funkció: 		8 bites sz�m maszkol�sa
; Bementek: 	ArrayLength (R3) - maszkoland� sz�m
;			 	Temp - maszk
; Kimenetek:   ArrayLength - maszkolt sz�m
; Regisztereket m�dos�tja:
;				A
; -----------------------------------------------------------
SearchMinMax:
	;
	MOV DPTR, #Array ; Data Pointer-nek átadom a tömb kezdőcímét
	MOV ArrayLength, #(ArrayEnd-Array)+1 ; A Bank0R3 regiszterben eltárolom a tömb elemszámát
							  ; Ez az elemszám lesz később a megmaradt elemek száma
	MOV OutputMax_Address, #OutputMaxRAM ; Az R0-ba eltárolom az OutputMax helyét
	MOV OutputMin_Address, #OutputMinRAM
	MOV @OutputMax_Address, #0h
	MOV @OutputMin_Address, #0xFF
	TestToAllEllementOfTheArray:
		DJNZ ArrayLength, MaxTest ; Megvizsgálom az elemszámot, mert ha 0 akkor visszatérhetünk
		RET
		MaxTest:
			MOV A, #0 ; Kinullázom az A regisztert
			MOVC A, @A+DPTR ; Az A regiszterbe belerakom a DPTR helyen lévő kódmemória értéket
			MOV Temp, A ; Az Temp regisztert egy temp regiszternek használom és belerakom ez az értéket
			INC DPTR ; Következő elemre lépek a tömben
			CheckMax:
				MOV A, @OutputMax_Address
				SUBB A, Temp ; Az A-ban lévő számból kivonom az output maxot
				MOV A, PSW ; A PSW-t előkészítem a vizsgálatra
				ANL A, #80h ;Összeandelem és ha a az OV bit szerint változtatok ugrést
				JZ CheckMin ; Ugrok ha az OV 0 mivel 
				MOV A, Temp ; Temp berakom az a ba
				MOV @R0, A ; R0 on van az output max
			CheckMin:
				MOV A, Temp
				SUBB A, @OutputMin_Address 
				MOV A, PSW ; A PSW-t előkészítem a vizsgálatra
				ANL A, #80h ;Összeandelem és ha a az OV bit szerint változtatok ugrést
				JZ TestToAllEllementOfTheArray ; Ugrok ha az OV 0 mivel
				MOV A, Temp ; Temp berakom az a ba
				MOV @OutputMin_Address, A ; R0 on van az output max
				JMP TestToAllEllementOfTheArray
END
