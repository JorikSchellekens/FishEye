	AREA	Adjust, CODE, READONLY
	PRESERVE8
	IMPORT	main
	IMPORT	getPicAddr
	IMPORT	putPic
	IMPORT	getPicWidth
	IMPORT	getPicHeight
	EXPORT	start

getPixelError
	LDR R0, =-1
	LDR R1, =-1
	B getPixelFinally
getPixel			; address, RGBval = getPixel(row, col)
	; Parameters:
	; R0 = row
	; R1 = column
	; Returns:
	; R0 = RGBvalue
	STMFD SP!, {LR}
	
	;CMP R0, R5		; if (row >= height || col >= width):
	;BHS getPixelError	;	return -1; (throw error)
	;CMP R1, R6
	;BHS getPixelError
	
	B rowColToIndex		; addressOffset = rowColToIndex(row, col)
	LDR R0, [R4, R0, LSL #2]; RGBvalue = Memmory.word(pictureaddress + addressOffset * 4)
getPixelFinally
	LDMFD SP!, {LR}
	BX LR
	
rowColToIndex
	; converts row and colum to index
	; Parameters
	; R0 = row
	; R1 = col
	; Return Values
	; R0 addressIndex
	MUL R0, R1, R0		; addressOffset = row * col
	ADD R0, R0, R1		; addressOffset += col
	BX LR

putPixel
	; Stores a given RGB to an pixel of at row, col
	; Parameters
	; R0 = row
	; R1 = col
	; R2 = RGB
	STMFD SP!, {LR}
	
	B rowColToIndex		; addressOffset = rowColToIndex(row, col)
	STR R2, [R4, R0, LSL #2]; Memory.word(pictureAddress + addressOffset * 4)
	
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
	
	LDR R1, = 0x00FF0000	; mask = redMask
	B getValueFromMask	; val = getValueFromMask(RGB, mask)
	B adjustColor		; val = adjustColor(val, contrast, brightness)
	B setValueFromMask	; RGB = setValueFromMask(RGB, mask, value)
	
	LDR R1, = 0x0000FF00
	B getValueFromMask
	B adjustColor
	B setValueFromMask
	
	LDR R1, = 0x0000FF00
	B getValueFromMask
	B adjustColor
	B setValueFromMask

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
	LDR R4, [SP, #-12]	; contrast = stack.getParameter()
	LDR R5, [SP, #-8]	; brightness = stack.getParameter()
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
	; R2 = colorValue
	BIC R2, R0, R1		; value = RGB & mask
getMaskWhile	
	LSRS R1, R1, #4		; while (mask >> 4 doesn't carry)
	BCS endGetMaskWhile	; {
	LSR R2, R2, #4		;	value >> 4
	B getMaskWhile		; }
endGetMaskWhile			
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
	MVN R1, R1		; invertmask for simplicity
	BIC R0, R0, R1		; RGB = RGB & mask // remove color
setMaskWhile	
	LSRS R1, R1, #4		; while (mask >> 4 doesn't carry)
	BCC endSetMaskWhile		; {
	LSL R2, R2, #4		;	value >> 4
	B setMaskWhile		; }
endSetMaskWhile			;
	ADD R0, R0, R2		; RGB = RGB + value
	BX LR
	
start
	BL	getPicAddr	; load the start address of the image in R4
	MOV	R4, R0
	BL	getPicHeight	; load the height of the image (rows) in R5
	MOV	R5, R0
	BL	getPicWidth	; load the width of the image (columns) in R6
	MOV	R6, R0
	
	LDR R8, =20	; 	Contrast
	LDR R9, = 0	;	Brightness

iLoop
	MOV R7, R6
	SUBS R5, R5, #1
	BMI endiLoop
jLoop
	SUBS R7, R7, #1
	BMI endjLoop
	MOV R0, R5
	MOV R1, R7
	BL getPixel
	MOV R2, R8
	MOV R3, R9
	BL adjustPixel
	MOV R2, R0
	MOV R0, R5
	MOV R1, R7
	BL putPixel
	B jLoop
endjLoop
	B iLoop
endiLoop
	BL putPic
	; re-display the updated image

stop	B	stop


	END	