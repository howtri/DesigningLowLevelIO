 TITLE Designing low-level I/O procedures

; Description:  This program requires integers to be read in and displayed
; the *hard way. This requires using Irvine's read and write string and 
; manipulating the byte strings to SDWORDS and the SDWORDS back to byte
; arrays. The program is tested with a driver main function that utilizes
; the procedures for low level I/O to read in 10 numbers as strings
; and display stats on them.

INCLUDE Irvine32.inc

; constant for array size based on the max number that can fit in a 32 bit SDWORD
MAX_SIZE = 10

; Macro definitions

; ------------------------------------------------
; Name: mGetString
; Description: A macro that gets user keyboard input using Irvine's ReadString
; and writes the output to the passed string location
; Preconditions: None
; Postconditions: None
; Receives: displayString - info to print to the user, destinationString - the destination
; to write keyboard input, length - the maximum characters than can be read from the user
; Returns: The passed destinationString address will contain the keyboard input of the user
; ------------------------------------------------
mGetString MACRO displayString:REQ, destinationString:REQ, length:REQ
	PUSH	EDX
	PUSH	ECX
	MOV		EDX, displayString
	CALL	WriteString

	mov		edx, destinationString	; buffer to write ascii bytes too
	mov		ecx, length				; max characters to read in
	call	ReadString

	POP		ECX
	POP		EDX
ENDM

; ------------------------------------------------
; Name: mDisplayString
; Description: A macro that writes a string to the user using Irvine's WriteString
; on user input
; Preconditions: None
; Postconditions: None
; Receives: displayString - an address to the first byte location of the string to
; display to the user
; Returns: None
; ------------------------------------------------
mDisplayString MACRO displayString:REQ
	PUSH	EDX
	MOV		EDX, displayString
	CALL	WriteString
	POP		EDX
ENDM

.data

; define variables for all of our introduction, titles, and arrays
intro				BYTE "Designing low-level I/O procedures by Tristan Howell",0
instructions		BYTE "Please provide 10 signed decimal integers. The numbers must be small enough to fit in a 32 bit register. Once thats finished I'll show you some cool stats on them!",0
instructUser		BYTE "Enter a number: ",0
notValid			BYTE "Hey! There's an invalid character or this numbers too large.",0
readInVal			DWORD MAX_SIZE DUP(?) 
userInputArray		DWORD MAX_SIZE DUP(?)
intToString			DWORD MAX_SIZE DUP(?)			
currentNumber		SDWORD 0
titleNumbersIn		BYTE "Presenting the numbers you entered",0
titleSum			BYTE "Presenting the sum of numbers entered",0
titleAvg			BYTE "Presenting the average of numbers entered",0
space				BYTE " ",0
goodbye				BYTE "Goodbye!",0

.code

; ------------------------------------------------
; Name: main
; Description: the driver procedure, this procedure stages parameters on the stack for called procedures
; additionally in this case main is used to test the WriteVal and ReadVal functions by determining statistics based
; on user input
; Preconditions: None
; Postconditions: None
; Receives: None
; Returns: None
; ------------------------------------------------
main PROC
	PUSH	offset intro
	PUSH	offset instructions
	CALL	introduction

; ------------------------------------------------
; Fills an array of sdwords based on input from calling ReadVal 10 times.
; ------------------------------------------------
	MOV		EDI, offset	userInputArray			;Address of first element of arrayData into ESI
	MOV		ECX, LENGTHOF userInputArray		; size of array to loop over (fill)
_fillData:
	PUSH	offset currentNumber	
	PUSH	offset notValid
	PUSH	offset instructUser
	PUSH	offset readInVal
	PUSH	SIZEOF readInVal
	CALL	ReadVal
	CALL	crlf
	MOV		EAX, currentNumber
	MOV		[EDI], EAX
	MOV		EAX, offset currentNumber
	PUSH	ESI
	MOV		ESI, 0							
	MOV		[EAX], ESI							; 0 out the last read in number to not affect values that are smaller than the previously entered
	POP		ESI
	ADD		EDI, 4			
	LOOP	_fillData

	MOV		EDX, offset titleNumbersIn
	CALL	WriteString
	CALL	crlf

; ------------------------------------------------
; Displays the 10 strings entered by users as integers sing the WriteVal procedure
; ------------------------------------------------
	MOV		EDI, offset	userInputArray			;Address of first element of arrayData into ESI
	MOV		ECX, LENGTHOF userInputArray		; size of array to loop over (fill)
_outputEntered:
	MOV		ESI, [EDI] ;n-th element of myArr into ESI      
	ADD		EDI, 4
	MOV		EAX, offset currentNumber
	MOV		[EAX], ESI
	PUSH	currentNumber
	PUSH	offset intToString
	CALL	WriteVal

	MOV		EDX, offset space
	CALL	WriteString
	LOOP	_outputEntered
	CALL	crlf
	
; Calculates the sum by looping over and adding together all numbers in userInputArray
; the calculated sum is displayed with the WriteVal procedure
; EAX is set with the sum and is REQUIRED for the _calculateAvg section to work
; ------------------------------------------------
	MOV		EDI, offset userInputArray
	MOV		ECX, LENGTHOF userInputArray
	MOV		EDX, 0								; track our running average
_calculateSum:
	MOV		ESI, [EDI]							;n-th element of myArr into ESI      
	ADD		EDI, 4
	ADD		EDX, ESI
	LOOP	_calculateSum
	MOV		EAX, EDX							; store sum for average to use
	PUSH	EDX
	PUSH	offset intToString
	MOV		EDX, offset titleSum
	CALL	WriteString
	CALL	crlf

	CALL	WriteVal
	CALL	crlf

; ------------------------------------------------
; Based on the sum passed in EAX from the _calculateSum section the average is calculated
; by dividing based on the length of the number storage array
; the calculated average is dispayed with the WriteVal procedure
; ------------------------------------------------
_calculateAvg:
	; sum is already in EAX, a precondition for IDIV
	CDQ
	MOV		ECX, LENGTHOF userInputArray
	IDIV	ECX
	PUSH	EAX
	PUSH	offset intToString
	MOV		EDX, offset titleAvg
	CALL	WriteString
	CALL	crlf
	CALL	WriteVal
	CALL	crlf

	MOV		EDX, offset goodbye
	CALL	WriteString
	Invoke ExitProcess,0						; exit to operating system
main ENDP


; ------------------------------------------------
; Name: ReadVal
; Description: A procedure that accepts a byte string and translates into a SDWORD
; this is accomplished by dividing by 10 and taking the remainder to move through the
; decimal places
; Preconditions: None
; Postconditions: None
; Receives: Recieves in order the currentNumber - the variable where we store the SDWORD based off the string
; notValid - a string to inform the user a number is not valid, instructUser - prompt for input, 
; readInVal addr - address of the byte string to iterate over to calculate the SDWORD, readInVal size to determine
; times to iterate and multiple existing value
; Returns: A valid SDWORD based off the string input is written to the addrress of currentNumber
; ------------------------------------------------
ReadVal PROC
	PUSH	EBP				
	MOV		EBP, ESP		

	PUSH	EAX
	PUSH	ECX
	PUSH	ESI
	PUSH	EDX
	PUSH	EDI

	MOV		EDI, [ebp + 24]						; use this to count our int value
	MOV		EDI, [EDI]							; value at address of edi into edi so it's recognized as a SDWORD

_readIn:

	MOV		EDX, [ebp + 12]
	mGetString [ebp + 16], [ebp + 12], [ebp + 8]
	MOV		ECX, [ebp + 8]						; str len
	MOV		ESI, EDX							; str first addr into ESI
_loadByte:
	lodsb	; loads into EAX

_validateRange:									; 48 to 57
	CMP		EAX, 45								; -
	JE		_loadByte							; we skip the sign until we check at the end, we want to convert at the end for twos complement of the aggregate
	CMP		EAX, 43								; +
	JE		_loadByte	

	CMP		EAX, 57
	JG		_notValid
	CMP		EAX, 48
	JL		_notValid

_convertAscii:
	SUB		EAX, 48
	
_convertToIntegerValue:

	PUSH	EAX
	PUSH	EBX

	; multiply our current value in EDI by 10 to account for decimal place value
	MOV		EAX, EDI
	MOV		EBX, 10
	MUL		EBX
	MOV		EDI, EAX

	POP		EBX
	POP		EAX

	ADD		EDI, EAX							; add the value we read in this iteration

	LOOP	_loadByte
	
_validateSizeInRange:

_checkIsNegative:

	PUSH	EAX
	PUSH	ECX
	PUSH	EDX
	PUSH	ESI

	MOV		EDX, [ebp + 12]
	MOV		ECX, [ebp + 8]						; str len
	MOV		ESI, EDX							; str first addr into ESI
	lodsb	; loads into EAX

	POP		ESI
	POP		EDX

	MOV		ECX, 45
	CMP		EAX, ECX
	POP		ECX
	POP		EAX
	JE		_twosComplement
	JMP		_complete

_twosComplement:
	NEG		EDI
	JMP		_complete

_notValid:
	CMP		EAX, 0
	JE		_checkIsEmpty						; if the would-be ascii value is 0 then we've reached the end of input or the input was null
_notValidNoCheck:
	MOV		EDX, [ebp + 20]
	CALL	WriteString
	CALL	crlf
	JMP		_readIn

_checkIsEmpty:
	CMP		EDI, 0
	JE		_notValidNoCheck					; value of EAX and EDI is 0 so we have no input from the user, invalid
	JMP		_checkIsNegative					; we reached the end of the user input, check for negative and finalize
_complete:
	MOV		EDX, [ebp + 24]
	MOV		[EDX], EDI

	POP		EDI
	POP		EDX
	POP		ESI
	POP		ECX
	POP		EAX

	POP		EBP
	RET		16
ReadVal ENDP


; ------------------------------------------------
; Name: WriteVal
; Description: A procedure that accepts a SDWORD and translates it to a byte string based off dividing
; for every *decimal number place. This accounts for negatives in a fairly unclever way and duplicates a lot
; of code with small variances to add the negative value and reverse the twos complement calculation. Numbers
; are determined in reverse order - lowest value place to highest and are pushed onto the stack and then popped
; off when all values are calculated and ready to be added to the byte string.
; Preconditions: SDWORD in currentNumber
; Postconditions: None
; Receives: In order currentNumber - the SDWORD to be converted to a byte string array to be displayed using Irvine's WriteString,
; intToString - the address of where to store the byte string based on the conversion from SDWORD
; Returns: None
; ------------------------------------------------
WriteVal PROC
	PUSH	EBP
	MOV		EBP, ESP

	PUSH	EAX
	PUSH	EDX
	PUSH	EBX
	PUSH	EDI
	PUSH	ECX

	MOV		ECX, 1								; the number of bytes we push to the stack, start at 1 and don't add for our highest place value
	MOV		EAX, [ebp + 12]						; current number to translate

	CMP		EAX, 0
	JL		_negativeNumber						; we need to revert our negative numbers from twos complement

_translateInt:

	CMP		EAX, 10								; greater than 10 as our remaining value we divide by 10 again to move *up decimal places
	JE		_exactlyEqualsTen
	JLE		_highestPlaceValue

	MOV		EDX, 0
	MOV		EBX, 10
	DIV		EBX

	ADD		EDX, 48								; remainder after div operation is our current place value, convert to ascii and store
	PUSH	EDX
	ADD		ECX, 1								; number pushed incremented
	JMP		_translateInt

_exactlyEqualsTen:
	MOV		EDX, 0
	MOV		EBX, 10
	DIV		EBX

	ADD		EDX, 48
	PUSH	EDX
	ADD		ECX, 1	

	ADD		EAX, 48								; translate highest place value to ascii
	PUSH	EAX
	JMP		_populateStrArray

_highestPlaceValue:
	MOV		EDX, 0
	MOV		EBX, 10
	DIV		EBX

	ADD		EDX, 48								; translate highest place value to ascii
	PUSH	EDX

	JMP		_populateStrArray

_negativeNumber:
	NEG		EAX									; translate back to *positive
	ADD		ECX, 1								; we also have to load the byte for the negative symbol

_negativeTranslateInt:
	CMP		EAX, 10								; greater than 10 as our remaining value we divide by 10 again to move *up decimal places
	JE		_negativeExactlyEqualsTen
	JLE		_negativeHighestPlaceValue

	MOV		EDX, 0
	MOV		EBX, 10
	DIV		EBX

	ADD		EDX, 48								; remainder after div operation is our current place value, convert to ascii and store
	PUSH	EDX
	ADD		ECX, 1								; number pushed incremented
	JMP		_negativeTranslateInt

_negativeExactlyEqualsTen:
	MOV		EDX, 0
	MOV		EBX, 10
	DIV		EBX

	ADD		EDX, 48
	PUSH	EDX
	ADD		ECX, 1	

	ADD		EAX, 48								; translate highest place value to ascii
	PUSH	EAX
	JMP		_addNegativeSymbol

_negativeHighestPlaceValue:
	MOV		EDX, 0
	MOV		EBX, 10
	DIV		EBX

	ADD		EDX, 48								; translate highest place value to ascii
	PUSH	EDX


_addNegativeSymbol:
	MOV		EDX, 45								; add ascii value for -
	PUSH	EDX
	

_populateStrArray:

	; set up to use STOSB
	MOV		EDI, [ebp + 8]						; array to store our bytes in starting position
	MOV		EAX, 0
	MOV		[EDI], EAX							; reset our d word byte array so our bigger values don't overwrite our smaller
	; ECX is also a requirement but we've already set it and incremented its value for each number on the stack
	CLD
_storeStringArray:
	POP		EAX									; reverse order of our *math to figure out the lowest to highest placee value
	STOSB
	LOOP	_storeStringArray

_displayToUser:
	mDisplayString [ebp + 8]

	POP		ECX
	POP		EDI
	POP		EBX
	POP		EDX
	POP		EAX

	POP		EBP
	RET		4
WriteVal ENDP


; ------------------------------------------------
; Name: introduction
; Description: Displays two strings to the user using Irvine's WriteString, these strings introduce the program
; Preconditions: None
; Postconditions: None
; Receives: In order intro and instructions, both byte strings
; Returns: None
; ------------------------------------------------
introduction PROC
	PUSH	EBP				
	MOV		EBP, ESP		
	MOV		EDX, [EBP + 12]
	CALL	WriteString
	CALL	crlf
	MOV		EDX, [EBP + 8]
	CALL	WriteString
	CALL	crlf
	CALL	crlf
	POP		EBP
	RET		8
introduction ENDP

END main
