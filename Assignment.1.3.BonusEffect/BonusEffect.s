	AREA	MotionBlur, CODE, READONLY
	PRESERVE8
	IMPORT	main
	IMPORT	getPicAddr
	IMPORT	putPic
	IMPORT	getPicWidth
	IMPORT	getPicHeight
	EXPORT	start

copyAddress	EQU 0xA1016300
redMask 	EQU 0x00FF0000
greenMask 	EQU 0x0000FF00
blueMask 	EQU 0x000000FF
xhalf		EQU 40
yhalf		EQU 49

getPixel			; address, RGBval = getPixel(row, col)
	; Parameters:
	; R0 = row
	; R1 = column
	; R2 = image address
	; Stack must be cleared by caller
	; Returns:
	; R0 = RGBvalue
	STMFD SP!, {LR}

	BL rowColToIndex		; addressOffset = rowColToIndex(row, col)
	LDR R0, [R2, R0, LSL #2]; RGBvalue = Memmory.word(pictureaddress + addressOffset * 4)
	
	LDMFD SP!, {LR}
	BX LR
	
rowColToIndex
	; converts row and colum to index
	; Parameters
	; R0 = row
	; R1 = col
	; Stack must be cleared by caller
	; Return Values
	; R0 addressIndex
	PUSH {R2, LR}
	MOV R2, R0
	BL getPicWidth
	MLA R0, R2, R0, R1	; addressOffset = row * width + col 
	POP {R2, LR}
	BX LR

putPixel
	; Stores a given RGB to a pixel at row, col
	; Parameters
	; R0 = row
	; R1 = col
	; R2 = picture address
	; R3 = RGB
	; Stack must be cleared by caller

	STMFD SP!, {LR}
	
	BL rowColToIndex		; addressOffset = rowColToIndex(row, col)
	STR R3, [R2, R0, LSL #2]; Memory.word(pictureAddress + addressOffset * 4) = RGB
	
	LDMFD SP!, {LR}
	BX LR
	
adjustPixel
	; adjustedVal = adjustPixel(value, contrast, brightness)
	; Applies a given contrast and brightness value
	; Parameters:
	; R0 = RGB
	; R2 = contrast   (0 <= contrast) contrast has no effect at 16
	; R3 = brightness

	STMFD SP!, {R2, R3, LR} ; save link register and pass paramters contrast and brightness
	
	LDR R1, = redMask; mask = redMask
	BL getValueFromMask	; val = getValueFromMask(RGB, mask)
	BL adjustColor		; val = adjustColor(val, contrast, brightness)
	BL setValueFromMask	; RGB = setValueFromMask(RGB, mask, value)
	
	LDR R1, = greenMask
	BL getValueFromMask
	BL adjustColor
	BL setValueFromMask
	
	LDR R1, = blueMask
	BL getValueFromMask
	BL adjustColor
	BL setValueFromMask

	LDMFD SP!, {R2, R3, LR}
	BX LR
	
adjustColor 
	; val = adjustColor(color, contrast, brightness)
	; applies the brightness contrast formula
	; Paramters:
	; R2 = color
	; Stack > contrast, brightness that order.
	; Return Values
	; R2 = color
	; Stack > contrast, brightness that order.
	STMFD SP!, {R4, R5}
	LDR R4, [SP, #8]	; contrast = stack.getParameter()
	LDR R5, [SP, #12]	; brightness = stack.getParameter()
	MUL R2, R4, R2		; color *= contrast
	LSR R2, R2, #4		; color /= 16
	ADDS R2, R2, R5		; color += brightness
	LDRMI R2, =0		; if (color < 0): color = 0
	CMP R2, #255		; else if (color > 255):
	LDRGT R2, =255		;	color = 255
	LDMFD SP!, {R4, R5}	; restore pointers
	BX LR
	
getValueFromMask
	; Gets the color value under a congruent mask
	; Expects masks of type FF
	; eg mask 00FF0000 will return the value under FF in this case the value of red
	; Parameters
	; R0 = RGB
	; R1 = mask
	; Return Values
	; R1 = mask
	; R0 = colorValue
	AND R0, R0, R1		; value = RGB & mask
	PUSH {R1}
getMaskWhile	
	LSRS R1, R1, #4		; while (mask >> 4 doesn't carry)
	BCS endGetMaskWhile	; {
	LSR R0, R0, #4		;	value >> 4
	B getMaskWhile		; }
endGetMaskWhile			
	POP {R1}
	BX LR
	
setValueFromMask
	; Sets the color value under a congruent mask
	; Expects masks of type FF
	; Takes in a value and a location in form FF
	; Parameters
	; R0 = RGB
	; R1 = mask
	; R2 = colorValue
	; Return Values
	; R0 = RGB
	BIC R0, R0, R1		; RGB = RGB & mask // remove color
setMaskWhile	
	LSRS R1, R1, #4		; while (mask >> 4 doesn't carry)
	BCS endSetMaskWhile	; {
	LSL R2, R2, #4		;	value >> 4
	B setMaskWhile		; }
endSetMaskWhile			;
	ADD R0, R0, R2		; RGB = RGB + value
	BX LR

averageN
	; Takes in five RGB values and computes their blur value.
	; Parameters:
	;	Stack > RGB value count    | 0 < count
	;	Stack > count RGB values
	; Returns:
	;	R0 = average

	LDMFD SP, {R0}
	STMFD SP!, {R1 - R6, LR}
	LDR R4, =7
	MOV R3, R0
	ADD R5, R4, R3
	LDR R6, =0
	LDR R2, =0
	LDR R1, =redMask
	BL averageColor
	LDR R1, =greenMask
	BL averageColor
	LDR R1, =blueMask
	BL averageColor
	MOV R0, R6
	LDMFD SP!, {R1 - R6, LR}
	BX LR

averageColor
forN
	CMP R5, R4
	BEQ endForN
	LDR R0, [SP, R5, LSL #2]
	PUSH {LR}
	BL getValueFromMask
	POP {LR}
	ADD R2, R2, R0
	SUBS R5, R5, #1
	B forN
endForN
	PUSH {R1}
	MOV R0, R2
	MOV R1, R3
	PUSH {LR}
	BL divide
	POP {LR}
	CMP R1, #0
	LDRMI R1, =0
	CMP R1, #255
	LDRGT R1, =255
	MOV R0, R6
	MOV R2, R1
	POP {R1}
	PUSH {LR}
	BL setValueFromMask
	POP {LR}
	MOV R6, R0
	LDR R2, =0
	ADD R5, R4, R3
	BX LR
	
greyScale
	; Converts a pixel to a light intensity value.
	; Paramteters
	;				R0 = RGB
	; Return
	;				R0 = Light intesity
	PUSH {R1, LR}
	MOV R2, R0
	LDR R1, =redMask
	BL getValueFromMask
	LDR R12, =299
	MUL R3, R0, R12
	LDR R12, =587
	LDR R12, =114

; taken from my group work in the labs
divide											;division loop, leaves Quotient in R1 and Remainder in R0
	STMFD SP!, {R2, R3, LR}
	
	LDR R2, =0	; Q								;set temp quotient to 0
	LDR R3, =1	; T								;set placeholder to 1

	CMP R1, #0;									;if Divisor == 0
	LDREQ R0, =-1								;load -1 into remainder
	LDREQ R1, =-1								;load -1 into quotient
	BEQ stop									;stop
	
alignLoop										;else
	CMP R0, R1									;while dividend>divisor
	BLT endAlignLoop							;{
	LSL R1, #1 									;	multiply divisor by 2
	LSL R3, #1									;	multiply placeholder by 2
	B alignLoop									;}
endAlignLoop

THEREVENGEOFTHEALIGNLOOP						;{
	LSR R1, #1 									;divide divisor by 2
	LSRS R3, #1									;divide r3 by 2 and set flag
	BCS THEENDOFTHEREVENGEOFTHEALIGNLOOP		;while carry flag not set{ 
	CMP R0, R1									;	if(dividend>=divisor):
	SUBHS R0, R0, R1							;		subtract dividend from divisor
	ADDHS R2, R2, R3							;		add placeholder to temp quotient
	B THEREVENGEOFTHEALIGNLOOP					;	
THEENDOFTHEREVENGEOFTHEALIGNLOOP				; }
	MOV R1, R2
	LDMFD SP!, {R2, R3, LR}								
	BX LR							
	

start
	BL	getPicAddr	; load the start address of the image in R4
	MOV	R4, R0		; copy destination
	BL	getPicHeight	; load the height of the image (rows) in R5
	MOV	R6, R0

copyImage
	SUB R6, R6, #1
moveLoopI
	BL getPicWidth
	MOVS R7, R0
	SUB R7, R7, #1

moveLoopJ
	MOV R0, R6
	MOV R1, R7

	MOV R2, R4
	BL getPixel
	MOV R3, R0

	MOV R0, R6
	LDR R2, =copyAddress
	BL putPixel 
	
	SUBS R7, R7, #1
	BGE moveLoopJ
endMoveLoopJ

	SUBS R6, R6, #1
	BGE moveLoopI
endMoveLoopI


	;; //////////////////////////////////////////////////////////////////////////
	BL	getPicHeight	; load the height of the image (rows) in R5
	MOV	R6, R0
	
	SUB R6, R6, #1
move2LoopI
	BL getPicWidth
	MOVS R7, R0
	SUB R7, R7, #1

move2LoopJ
	MOV R0, R6		;
	MOV R1, R7		;
	LDR R2, =copyAddress		;
	BL getPixel		;
	MOV R11, R0

	SUB R8, R6, #yhalf
	MOV R9, R8
	MUL R8, R9, R8
	LSR R8, R8, #16
	ADD R8, R8, #1
	MULS R8, R9, R8
	ADDS R8, R8, R6
	BMI finaly
	BL getPicHeight
	CMP R8, R0
	BGE finaly
	
	SUB R9, R7, #xhalf
	MOV R10, R9
	LSR R9, R9, #16
	ADD R9, R9, #1
	MUL R9, R10, R9
	ADDS R9, R9, R7
	BMI finaly
	BL getPicWidth
	CMP R9, R0
	BGE finaly
	
	MOV R0, R8		;
	MOV R1, R9		;
	MOV R2, R4		;
	MOV R3, R11
	BL putPixel		;
	
finaly
	SUBS R7, R7, #1		; column --
	BGE move2LoopJ
endMove2LoopJ

	SUBS R6, R6, #1
	BGE move2LoopI
endMove2LoopI



	BL	putPic		; re-display the updated image
	
stop	B	stop


	AREA Variables, DATA, READWRITE
	
radius DCD 2
	END