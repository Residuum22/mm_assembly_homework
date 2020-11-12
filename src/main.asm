; -----------------------------------------------------------------------------------
; Mikrokontroller alapú rendszerek házi feladat
; Készítette: Mihalik Márk
; Neptun code: ST9OKE
; Feladat leírása:
;		Belső memóriában található adott elemű számsorozat (tömb) legnagyobb és 
;		legkisebb elemének kiválasztása. Minden elem 1 bájtos előjel nélküli szám. 
;		Bemenet: tömb kezdőcíme (mutató), elemek száma. Kimenet: az előforduló 
;		legkisebb és legnagyobb elem (2 regiszterben).
; !!!Megjegyzés!!!
; Elkerülhető lett volna az indirekt címzés használata a programban, de szerettem
; volna ezt gyakorolni így a kódban lesz indirekt címzés.
; -----------------------------------------------------------------------------------

$NOMOD51 ; a sztenderd 8051 regiszter definíciók nem szükségesek


$INCLUDE (SI_EFM8BB3_Defs.inc) ; regiszter és SFR definiciók

OutputMax_Address 	EQU R0
OutputMin_Address 	EQU R1
ArrayLength 		EQU R2
Temp				EQU R3
; -----------------------------------------------------------------------------------
; Main program előtti inicializáció és keresni kívánt tömb definiálása
; -----------------------------------------------------------------------------------
; Feladat: Tömb elemeinek definiálása
; -----------------------------------------------------------------------------------

InputArray SEGMENT CODE ; Input tömb regisztrálása valahol flash memóriában
RSEG InputArray ; és ennek a kiválsztása

Array: DB 215,51,64,74,213,3,11,51 ; Ide kerül a tömb, ne legyen 255 elemnél nagyobb
ArrayEnd:

DSEG AT 0x30	; 30h felett tárolom a bemenő adatot, így kikerülöm a Bankeket és a Bit Adressable regisztereket. 
OutputMinRAM: DS 1 ; Data memóriában lefoglalunk 2 regisztert a min és max értékeknek
OutputMaxRAM: DS 1

; Ugrótábla létrehozása
CSEG AT 0
SJMP Main

myprog SEGMENT CODE	;saját kódszegmens létrehozása
RSEG myprog 		;saját kódszegmens létrehozása
; -----------------------------------------------------------------------------------
; Főprogram
; -----------------------------------------------------------------------------------
; Feladata: Meghívni a Minimum, Maximum kereső szubrutint és a könyebb debugolás
; végett a maximumot lementeni a Bank0 R6 regiszterben és a minimumot a Bank0 R7
; regiszterben, majd egy végtelen ciklusban vár a kontroller.
; -----------------------------------------------------------------------------------
Main:
	CLR IE_EA ; interruptok tiltása watchdog tiltás idejére
	MOV WDTCN,#0DEh ; watchdog timer tiltása
	MOV WDTCN,#0ADh
	SETB IE_EA ; interruptok engedélyezése

	CALL SearchMinMax ; Kereső szubrutin
	MOV OutputMax_Address, #OutputMaxRAM
	MOV A, @OutputMax_Address
	MOV R6, A
	MOV OutputMin_Address,#OutputMinRAM
	MOV A, @OutputMin_Address
	MOV R7, A
EndLoop:
	JMP $ ; végtelen ciklusban várunk

; -----------------------------------------------------------------------------------
; SearchMinMax szubrutin
; -----------------------------------------------------------------------------------
; Funkció: 		A legkisebb és a legnagyobb elem kikeresése a megadott tömbből
; Bementek: 	Array kezdőcíme
; Kimenetek:   	OutputMaxRAM - Legnagyobb elem a DATA memóriában
;				OutputMinRAM - Legkisebb elem a DATA memóriában
; Regisztereket módosítja:
;				A - A regiszter
;				Temp (R3) - Bank0 R3 regiszter
;				OutputMax_Address (R0) - Bank0 R0 regiszter
;				OutputMin_Address (R1) - Bank0 R1 regiszter
;				ArrayLength (R2) - Bank0 R2 regiszter
;				DPTR - Data pointer
;				PSW - Program Status Word
; -----------------------------------------------------------------------------------
SearchMinMax:
	MOV DPTR, #Array ; Data Pointer-nek átadom a tömb kezdőcímét
	MOV ArrayLength, #(ArrayEnd-Array) ; A Bank0 R3 regiszterben eltárolom a tömb elemszámát. Ez az elemszám lesz később a megmaradt elemek száma.
	MOV OutputMax_Address, #OutputMaxRAM ; Az R0-ban eltárolom az OutputMax helyét
	MOV OutputMin_Address, #OutputMinRAM ; Az R1-ben eltárolom az OutputMin helyét
	MOV @OutputMax_Address, #0h ; A legkisebb elem ami lehet 0, szóval betöltöm ezt az értéket, hogy nehogy szemét legyen benne
	MOV @OutputMin_Address, #0xFF ; Ugyan ez a helyezt, csak a legnagyobb 255
	TestToAllEllementOfTheArray:
		MOV A, ArrayLength ; Vizsgáláshoz betöltöm az A-ba az hosszúságot
		JNZ TestSubRoutine ; Ha ez nem 0, akkor elkezdem a tesztelést
		MOV @OutputMax_Address, #0h ; Ha 0 elemszám visszaugrunk 0 maxmummal és minimummal
		MOV @OutputMin_Address, #0h
	Return:	
		RET 
		TestSubRoutine:
			MOV A, ArrayLength ; Ha minden elemet megvizsgáltunk akkor visszatérünk
			JZ Return
			MOV A, #0 ; Kinullázom az A regisztert, hogy DPTR hozzáadva ne legyen falsch érték
			MOVC A, @A+DPTR ; Az A regiszterbe belerakom a DPTR helyen lévő kódmemória értéket
			MOV Temp, A ; A Temp(Bank0R3) regiszterbe töltöm a bementi tömbömnek a feldolgozandó elemét
			INC DPTR ; Következő elemre lépek a tömben, hogy ezt tudjam használni
			DEC ArrayLength ; Csökkentem az elemszámot, hogy időben végére érjen a program
			; -------------------------------------------------------------------------
			; Maximum meghatározó rész
			; -------------------------------------------------------------------------
			; Megvalósítás:
			; Az eddigi legnagyobb értékből kivonom a Temp regiszterben tárolt értéket
			; és vizsgálom hogy alulcsordult-e az A regiszter, amit a CY flag jelez a 
			; PSW regiszterben. Ha igen akkor a Tempben tárolt érték nagyobb mint az
			; eddigi maximum így az új maximum a Temp értéke lesz.
			; OutputMax-Temp
			; -------------------------------------------------------------------------
			CheckMax:
				MOV A, @OutputMax_Address ; Betöltöm a vizsgáláshoz a Max értéket
				SUBB A, Temp ; Az A-ban lévő számból kivonom az output maxot
				JNC CheckMin ; Ha nem történt alulcsordulás akkor ugrok és vizsgálom hogy lehet e még minimum
				MOV A, Temp ; Ha van alulcsordulás CY=1, Temp értékét berakom a Maximum értékének
				MOV @OutputMax_Address, A
			; -------------------------------------------------------------------------
			; Minimum meghatározó rész
			; -------------------------------------------------------------------------
			; Megvalósítás:
			; Hasonlóan működik mint az előző, viszont annyi módosítással, hogy itt 
			; a Temp értékből vonom ki az előző Minimum értékét és ha ez átcsordul, akkor
			; a Temp kisebb, mint a Minimum így be kell tölteni a Temp értékét a Minimumba.
			; Temp-OutputMin
			; -------------------------------------------------------------------------
			CheckMin:
				MOV A, Temp
				SUBB A, @OutputMin_Address
				JNC TestSubRoutine
				MOV A, Temp
				MOV @OutputMin_Address, A
				JMP TestSubRoutine
END
