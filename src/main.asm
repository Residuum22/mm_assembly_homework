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

ArrayAddressInData 	EQU R0
//ArrayLength 		EQU R2
Temp				EQU R3
OutputMin			EQU R6
OutputMax			EQU R7
; -----------------------------------------------------------------------------------
; Main program előtti inicializáció és keresni kívánt tömb definiálása
; -----------------------------------------------------------------------------------
; Feladat: Tömb elemeinek definiálása
; -----------------------------------------------------------------------------------

InputArray SEGMENT CODE ; Input tömb regisztrálása valahol flash memóriában
RSEG InputArray ; és ennek a kiválsztása

Array: DB 215,51,64,74,213,3,11,51,1 ; Ide kerül a tömb, ne legyen 80 elemnél nagyobb
ArrayEnd:

DSEG AT 0x30	; 30h felett tárolom a bemenő adatot, így kikerülöm a Bankeket és a Bit Adressable regisztereket. 
ArrayInData: DS (ArrayEnd-Array) ; Lefoglalom a belső memóriábn a helyeket amikre a tömb fog kerülni
ArrayInDataEnd:
ArrayLength: 9

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

	CALL CopyFromCodeToRam ; Meghívom a CODE szegmensből a RAM-ba másoló függvényt
	CALL SearchMinMax ; Kereső szubrutin
EndLoop:
	JMP $ ; végtelen ciklusban várunk

; -----------------------------------------------------------------------------------
; SearchMinMax szubrutin
; -----------------------------------------------------------------------------------
; Funkció: 		A legkisebb és a legnagyobb elem kikeresése a megadott tömbből
; Bementek: 	Array kezdőcíme
;				Array hossza
; Kimenetek:   	OutputMin - Legnagyobb elem a DATA memóriában
;				OutputMax - Legkisebb elem a DATA memóriában
; Regisztereket módosítja:
;				A - A regiszter
;				Temp (R3) - Bank0 R3 regiszter
;				OutputMax_Address (R0) - Bank0 R0 regiszter
;				OutputMin_Address (R1) - Bank0 R1 regiszter
;				ArrayLength - In DATA memory
;				DPTR - Data pointer
;				PSW - Program Status Word
; -----------------------------------------------------------------------------------
SearchMinMax:
	MOV ArrayAddressInData, #ArrayInData ; A kezdőcímét a tömb ram-bani helyének elmentem
	MOV OutputMax, #0h ; A legkisebb elem ami lehet 0, szóval betöltöm ezt az értéket, hogy nehogy szemét legyen benne
	MOV OutputMin, #0xFF ; Ugyan ez a helyezt, csak a legnagyobb 255
	TestToAllEllementOfTheArray:
		MOV A, ArrayLength ; Vizsgáláshoz betöltöm az A-ba az hosszúságot
		JNZ CheckSubRutine ; Ha ez nem 0, akkor elkezdem a tesztelést
		RET
		CheckSubRutine:
			MOV A, @ArrayAddressInData
			MOV Temp, A
			INC ArrayAddressInData
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
				MOV A, OutputMax ; Betöltöm a vizsgáláshoz a Max értéket
				SUBB A, Temp ; Az A-ban lévő számból kivonom az output maxot
				JNC CheckMin ; Ha nem történt alulcsordulás akkor ugrok és vizsgálom hogy lehet e még minimum
				MOV A, Temp ; Ha van alulcsordulás CY=1, Temp értékét berakom a Maximum értékének
				MOV OutputMax, A
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
				SUBB A, OutputMin
				JNC CheckSubRutineEnd
				MOV A, Temp
				MOV OutputMin, A
			CheckSubRutineEnd:
				DJNZ ArrayLength, CheckSubRutine
				RET
; -----------------------------------------------------------------------------------
; CopyFromCodeToRam szubrutin
; -----------------------------------------------------------------------------------
; Funkció: 		A Code memóriából bemásolja a tömb elemeit a belső memóriában lefoglalt helyre
; Bementek: 	Array kezdőcíme
; Kimenetek:   	ArrayAddressInData (R0) - Ramban tárolt array kezdőcíme
; Regisztereket módosítja:
;				A - A regiszter
;				ArrayLength (R2) - Bank0 R2 regiszter ami a tömb hosszát tárolja és ciklus számlálóként is működik
;				DPTR - Data pointer
; -----------------------------------------------------------------------------------
CopyFromCodeToRam:
	MOV ArrayAddressInData, #ArrayInData ; A kezdőcímét a tömb ram-bani helyének elmentem
	MOV DPTR, #Array ; Data Pointer-nek átadom a tömb kezdőcímét
	MOV ArrayLength, #(ArrayEnd-Array) ; A Bank0 R3 regiszterben eltárolom a tömb elemszámát. Ez az elemszám lesz később a megmaradt elemek száma.
	MOV A, ArrayLength ; Vizsgáláshoz betöltöm az A-ba az hosszúságot
	JNZ Copying ; Ha ez nem 0, akkor elkezdem a másolást
	RET
	Copying:
		MOV A, #0 ; Kinullázom az A regisztert, hogy DPTR hozzáadva ne legyen falsch érték
		MOVC A, @A+DPTR ; Az A regiszterbe belerakom a DPTR helyen lévő kódmemória értéket
		MOV @ArrayAddressInData, A ; Bemásolom a RAM addressre a Code szegmensből az Array i-edik elemszámát
		INC ArrayAddressInData ; Incrementálom a belső memóriába mutató countert, hogy a következő helyre másolja majd az elemet az új ciklusban
		INC DPTR ; Következő elemre lépek a tömben, hogy ezt tudjam használni
		DJNZ ArrayLength, Copying ; Ciklus végi ellenörzés, hogy minden elemet feldolgoztunk-e
		RET
END
