# Computing Report

## General Functions

After considering a few of the challenges set out in the assignment I decided to write a suite of subroutines I thought would be universal. This set was mostly complete on the first revision.

In all the *'proper'* functions only the return register is corrupted.

-------

### Pixel Retrieval and Storage

First it was necessary to write subroutines for accessing and setting pixels based on a simple two dimensional system. The main interfaces to this system were the _getPixel_ and _putPixel_ subroutines which take in a *row*, a *column* and a *image address* and returns the value stored in memory at the corresponding offset from the base *image address*. There are no safety checks in these accesses to a row or column that is too large. Such attempts will simply be executed.

Note: Row and col are unsigned integers. A pixel is an RGB color value of form ``00RRGGBB`` in hex.

The images are indexed from the top left corner using a zero based index as shown.

|           | col 0 | col 1 | col 2 | col 3 | col 4 | col 5 |
| :-------: | :---: | :---: | :---: | :---: | :---: | :---: |
| **row 0** | pixel | pixel | pixel | pixel | pixel | pixel |
| **row 1** | pixel | pixel | pixel | pixel | pixel | pixel |
| **row 2** | pixel | pixel | pixel | pixel | pixel | pixel |
| **row 3** | pixel | pixel | pixel | pixel | pixel | pixel |



#### getPixel(*row*, *col*, *imageAddress*)

Retrieves a pixel from the memory address at location (row, col) from the imageAddress.

##### Parameters:

| REGISTER | CONTENT      |
| -------- | ------------ |
| R0       | row          |
| R1       | col          |
| R2       | imageAddress |

##### Return values:

| REGISTER | CONTENT |
| -------- | ------- |
| R0       | pixel   |



#### putPixel(*row*, *col*, *imageAddress*)

Sets a memory address at location (row, col) from the imageAddress to a given pixel.

##### Parameters:

| REGISTER | CONTENT      |
| -------- | ------------ |
| R0       | row          |
| R1       | col          |
| R2       | imageAddress |



#### rowColToIndex(*row*, *col*)

Both *getPixel* and *putPixel* above are dependent on this method which is just a very short wrapper around the ``MLA`` instruction:

````assembly
MLA R0, R2, R0, R1
````

The method gets the the picture width using *getPicWidth* and returns ``row * width + col``. Wrapping this in a branch subroutine spoils this instructions efficiency but since it is used in both *getPixel* and *setPixel* and since it requires a branch to *getPicWidth* I thought it useful in a smaller subroutine.

##### Parameters:

| REGISTER | CONTENT |
| -------- | ------- |
| R0       | row     |
| R1       | col     |

-----

### Color Component Manipulation

Since many of the sections in the assignment would require logic that was dependent on the color components of the pixel I wrote two subroutines which made it easy to retrieve and set a specific *color component* of a given pixel. This made all parts of the assignment much quicker to implement as they are used in many places such as Contrasting, Blurring and Grey-scaling.

A color mask must be provided in the form ``0xFF << 8n | 0 <= n < 3`` where ``n = 0`` is blue, ``n = 1`` is green and ``n = 2`` is red.

The subroutine works with *color components* which lie between the values of 0 and 255 inclusive.



#### getValueFromMask(*pixel*, *colorMask*)

Returns a *color component* determined by a given *color mask*.

Uses ``AND`` to clear everything not under the mask and shifts the component back to the right location. The *'right location'* is found by shifting the mask as well. Since the mask is a series of ones it will set the carry flag if the operation has gone one step too far, which I use as the end condition.

````assembly
; 	R0 = RGB
;	R1 = mask
	AND R0, R0, R1													; value = RGB & mask
getMaskWhile		
	LSRS R1, R1, #4													; while (mask >> 4 doesn't carry)
	BCS endGetMaskWhile												; {
	LSR R0, R0, #4													;	value >> 4
	B getMaskWhile													; }
endGetMaskWhile
````

##### Parameters:

| REGISTER | CONTENT   |
| -------- | --------- |
| R0       | pixel     |
| R1       | colorMask |

##### Return values:

| REGISTER | CONTENT        |
| -------- | -------------- |
| R0       | colorComponent |



#### setValueFromMask(*pixel*, *colorMask*, *colorComponent*)

Sets a *color component*, specified by a given *color mask*, of a pixel and returns that pixel.

The *color component* of the original pixel is cleared using the mask and the provided *color component* is shifted to the correct location using the similar logic to that of the *getValueFromMask* subroutine. The shifted *color component* and the cleared pixel are then simply added together.

##### Parameters:

| REGISTER | CONTENT        |
| -------- | -------------- |
| R0       | pixel          |
| R1       | colorMask      |
| R2       | colorComponent |

##### Return values:

| REGISTER | CONTENT |
| -------- | ------- |
| R0       | pixel   |

----

### Pixel Traversal and Modular Code

This function is particularly cool even though I say so myself. Throughout the entire code I have written only one loop for going through all of the pixels in the image. This is because the function *applyToAll* takes in the address of a function which is executed at each pixel location (row, col) of the image. This is very exciting because it vastly shortened the complexity and the time required to write the other effects. The functions that can be used 