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
lensn		EQU 1
lensq		EQU 10



;<--------------Pixel Manipulation-------------->
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

copy
	; Copies between the original and duplicate image locations
	; Parameters:
	; 				R0 = row
	;				R1 = col
	PUSH {R0, R1, R2, R3, R6, R7, LR}
	MOV R6, R0
	MOV R7, R1
	
	BL getPicAddr
	MOV R2, R0
	MOV R0, R6
	MOV R1, R7
	BL getPixel
	
	MOV R3, R0
	MOV R0, R6
	LDR R2, =copyAddress
	BL putPixel 
	
	POP {R0, R1, R2, R3, R6, R7, LR}
	BX LR
	
lensEffectCopy
	PUSH {R0, R1, R2, R3, R4, R6, R7, LR}
	MOV R6, R0		;
	MOV R7, R1		;
	
	BL getPicAddr
	MOV R4, R0
	
	MOV R0, R6		;

	BL applyLens
	LDR R2, =copyAddress;
	BL getPixel		;
		
	MOV R3, R0
	MOV R0, R6		;
	MOV R1, R7		;
	MOV R2, R4
	BL putPixel

	POP {R0, R1, R2, R3, R4, R6, R7, LR}
	BX LR
	
applyGreyScale
	; Wrapper to apply greyscale to original
	; Parameters:
	;				R0 = row
	;				R1 = col
	PUSH {R0, R1, R2, R3, R4, LR}
	MOV R4, R0
	BL getPicAddr
	MOV R2, R0
	MOV R0, R3
	BL getPixel
	BL greyScale
	MOV R3, R0
	MOV R0, R4
	BL putPixel
	POP {R0, R1, R2, R3, R4, LR}
	BX LR
	
applyToAll
	; Loops through all (row, col) combinations and executes the given subroutine.
	; Paramenters:
	;		R0 = routine address
	PUSH {R0, R1, R2, R3, LR}
	MOV R2, R0
	BL getPicWidth
	MOV R1, R0
	BL getPicHeight
	
	SUB R0, R0, #1
row_whl
	MOV R3, R0
	BL getPicWidth
	MOV R1, R0
	MOV R0, R3
	SUB R1, R1, #1
col_whl
	MOV LR, PC
	BX R2
	SUBS R1, R1, #1
	BGE col_whl
end_col_whl
	SUBS R0, R0, #1
	BGE row_whl
end_row_whl
	POP {R0, R1, R2, R3, LR}
	BX LR
	
applyAdjust
	; Parameters:
	;				R0 = row
	;				R1 = col
	
	PUSH {R0, R1, R2, R3, R4, LR}
	MOV R4, R0
	BL getPicAddr
	MOV R2, R0
	MOV R0, R4
	BL getPixel
	BL adjustPixelColor
	
	MOV R3, R0
	BL getPicAddr
	MOV R2, R0
	MOV R0, R4
	BL putPixel
	POP {R0, R1, R2, R3, R4, LR}
	BX LR
	
applyMotionBlur
	; Parameters:
	; 				R0 = row
	;				R1 = col
	
	PUSH {R0, R1, R2, R4, R6, R7, R8, R9, R10, R11, LR}
	
	LDR R9, =1		; count = 1 (current pixel)
	
	LDR R8, =radius
	LDR R8, [R8]
	MOV R10, R0
	MOV R11, R1
	
	MOV R6, R0		;
	MOV R7, R1		;
	
	LDR R2, =copyAddress
		
	BL getPixel		; 
	PUSH {R0}
	CMP R6, #0
topLoop
	BMI endTopLoop
	SUBS R6, R6, #1
	BMI topFinally
	SUBS R7, R7, #1
	BMI topFinally
	MOV R0, R6		
	MOV R1, R7		
	LDR R2, =copyAddress		
	BL getPixel		
	PUSH {R0}
	ADD R9, R9, #1
topFinally
	SUBS R8, R8, #1
	BNE topLoop
endTopLoop

	LDR R8, =radius
	LDR R8, [R8]
	MOV R6, R10
	MOV R7, R11
	
	CMP R6, #0
bottomLoop
	BMI endBottomLoop
	ADD R6, R6, #1
	BL getPicHeight
	CMP R6, R0
	BGE bottomFinally
	ADD R7, R7, #1
	BL getPicWidth
	CMP R7, R0
	BGE bottomFinally
	MOV R0, R6		;
	MOV R1, R7		;
	LDR R2, =copyAddress		;
	BL getPixel		; 
	PUSH {R0}
	ADD R9, R9, #1
bottomFinally
	SUBS R8, R8, #1
	BNE bottomLoop
endBottomLoop

	PUSH {R9}
	BL averageN	
			
	MOV R6, R10
	MOV R7, R11
	
	MOV R3, R0
	BL getPicAddr
	MOV R2, R0
	MOV R0, R6
	MOV R1, R7
	BL putPixel

	POP {R9}
clear_stack
	POP {R12}
	SUBS R9, R9, #1
	BNE clear_stack
	
	POP {R0, R1, R2, R4, R6, R7, R8, R9, R10, R11, LR}
	BX LR
	
;<--------------Effects-------------->
	
adjustPixelColor
	; adjustedVal = adjustPixel(value, contrast, brightness)
	; Applies a given contrast and brightness value
	; Parameters:
	; R0 = RGB
	PUSH {R1, R2, R3, LR}
	LDR R2, =contrast
	LDR R2, [R2]
	LDR R3, =brightness
	LDR R3, [R3]
	PUSH {R2, R3} ; save link register and pass paramters contrast and brightness
	MOV R3, R0
	
	LDR R1, = redMask; mask = redMask
	BL getValueFromMask	; val = getValueFromMask(RGB, mask)
	MOV R2, R0
	BL adjustColor		; val = adjustColor(val, contrast, brightness)
	MOV R0, R3
	BL setValueFromMask	; RGB = setValueFromMask(RGB, mask, value)
	MOV R3, R0
	
	LDR R1, = greenMask
	BL getValueFromMask
	MOV R2, R0
	BL adjustColor
	MOV R0, R3
	BL setValueFromMask
	MOV R3, R0

	
	LDR R1, = blueMask
	BL getValueFromMask
	MOV R2, R0
	BL adjustColor
	MOV R0, R3
	BL setValueFromMask

	POP {R2, R3}
	POP {R1, R2, R3, LR}
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
	PUSH {R1, R2, R3, R4, LR}
	MOV R2, R0
	LDR R3, =0
	
	LDR R1, =redMask
	BL getValueFromMask
	LDR R12, =299
	MOV R1, R0
	MUL R0, R1, R12
	ADD R3, R3, R0
	
	MOV R0, R2
	LDR R1, =greenMask
	BL getValueFromMask
	LDR R12, =587
	MOV R1, R0
	MUL R0, R1, R12
	ADD R3, R3, R0
	
	MOV R0, R2
	LDR R1, =blueMask
	BL getValueFromMask
	LDR R12, =114
	MOV R1, R0	
	MUL R0, R1, R12
	ADD R3, R3, R0
	
	MOV R0, R3
	LDR R1, =1000
	BL divide
	
	MOV R0, R1
	LSL R1, R0, #8
	ADD R1, R1, R0
	LSL R1, R1, #8
	ADD R0, R0, R1
	
	POP {R1, R2, R3, R4, LR}
	BX LR
	
applyLens
	; R0 = y
	; R1 = X
	
normalize_origin
	PUSH {r0, r1, R2, R3, R4, R9, R10, R11, LR}
	
	LDR R4, =lensq
	BL getPicHeight
	LSR R0, R0, #1
	MOV R2, R0
	
	BL getPicWidth
	LSR R0, R0, #1
	MOV R3, R0
	
	POP {r0, r1}
	
	SUB R0, R0, R2		; y -= centery
	SUB R1, R1, R3		; x -= centery
	
	MOV R10, R0			; save y
	MOV R11, R1			; save x
	
	BL distanceSqr
	BL sqrt
	MOV R9, R0
	
	MOV R0, R10
	CMP R4, R9
	MULLT R0, R4, R0
	MULGE R0, R9, R0
	MOV R1, R9
	BL divide
	SUB R10, R10, R1
	
	MOV R0, R11
	CMP R4, R9
	MULLT R0, R4, R0
	MULGE R0, R9, R0
	MOV R1, R9
	BL divide
	SUB R11, R11, R1
	
	BL getPicHeight
	LSR R0, R0, #1
	ADD R10, R10, R0
	
	BL getPicWidth
	LSR R0, R0, #1
	ADD R1, R11, R0
	
	MOV R0, R10
	
	
	POP {R2, R3, R4, R9, R10, R11, LR}
	BX LR
	
	
;<---------------Square root methods---------------->
	
sqrt
	; Finds the square root of a number
	; Parameters:
	;		R0 = number
	; Outputs:
	;		R0 = sqare root
	CMP R0, #1		; if the number is one return one
	BXEQ LR
	
	PUSH {R1, R2, R3, R4, R11, LR}
	MOV R11, R0		; save number
	LDR R3, =0		; temp = 0
	MOV R2, R0 		; x = S
	
find_sqr_whl
	LSR R2, R2, #1	; x /= 2
	SUBS R4, R2, R3
	BEQ end_sqr_whl	;	return x
	CMP R4, #1
	BEQ end_sqr_whl
	MOV R3, R2		; else: temp = x
	MOV R1, R2		; 
	MOV R0, R11		;
	BL divide		; 
	ADD R2, R2, R1	; 	x = x + divide(number, x)
	B find_sqr_whl
end_sqr_whl

	MOV R0, R2
	POP {R1, R2, R3, R4, R11, LR}
	BX LR
	
distanceSqr
	; Parameters:
	; 	R0 = relativex
	; 	R1 = relativey
	; Return:
	; 	R0 = distance^2
	PUSH {R1, R2}
	MOV R2, R0
	MUL R0, R2, R0
	MOV R2, R1
	MUL R1, R2, R1
	ADD R0, R0, R1
	POP {R1, R2}
	BX LR
	
	
	
;<-------------- Division Method -------------->;
; taken from my group work in the labs
divide											;division loop, leaves Quotient in R1 and Remainder in R0
	STMFD SP!, {R2, R3, R4, LR}
	
	LDR	R4, =1									;negative flag
	CMP R0, #0									;if dividend < 0
	NEGMI R4, R4								;	flag *= -1
	NEGMI R0, R0								;	dividend *= -1
	CMP R1, #0									; if divisor < 0
	NEGMI R4, R4								;	flag *= -1
	NEGMI R1, R1								;	divisor *= -1
	
	LDR R2, =0	; Q								;set temp quotient to 0
	LDR R3, =1	; T								;set placeholder to 1

	CMP R1, #0;									;if Divisor == 0
	LDREQ R0, =-1								;load -1 into remainder
	MOVEQ R2, R0								;load -1 into quotient
	BEQ div_zero									;stop
	
alignLoop										;else
	CMP R0, R1									;while dividend>divisor
	BLT endAlignLoop							;{
	LSL R1, #1 									;	multiply divisor by 2
	LSL R3, #1									;	multiply placeholder by 2
	B alignLoop									;}
endAlignLoop

division_whl									;{
	LSR R1, #1 									;divide divisor by 2
	LSRS R3, #1									;divide r3 by 2 and set flag
	BCS end_division_whl						;while carry flag not set{ 
	CMP R0, R1									;	if(dividend>=divisor):
	SUBHS R0, R0, R1							;		subtract dividend from divisor
	ADDHS R2, R2, R3							;		add placeholder to temp quotient
	B division_whl								;	
end_division_whl								; }
div_zero
	MOV R1, R2
	MUL R1, R4, R1								; quotient *= negative flag
	LDMFD SP!, {R2, R3, R4, LR}								
	BX LR							
	
;<-----------------Main---------------->
start

	;LDR R0, =applyAdjust
	;BL applyToAll
	LDR R0, =copy
	BL applyToAll
	;LDR R0, =applyMotionBlur
	;BL applyToAll
	LDR R0, =lensEffectCopy
	BL applyToAll
	;LDR R0, = applyGreyScale
	;BL applyToAll
	BL	putPic		; re-display the updated image
	
stop	B	stop

;<----------------Memory--------------->

	AREA Variables, DATA, READWRITE
	
radius DCD 2
contrast DCD 17
brightness DCD 100

	END