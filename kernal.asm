; Author: Jamie Douglass
; A UEFI application corresponding to the UEFI Specification version 2.9.
; Thanks to BrianOtto (https://github.com/BrianOtto/nasm-uefi)
; and Charlesap (https://github.com/charlesap/nasm-uefi) for your previous UEFI implementations.
; I have learned much from your code :)

BITS 64
org 0x00100000 ;Space for a small stack?








			;***************************************
			;*************** HEADER ****************
			;*** This gives UEFI the information ***
			;*** it needs to load the file       ***
			;***************************************
section .header

;***************************
;*** DOS header and stub ***
;***************************
dw 0x5a4d ;DOS Magic number
times 29 dw 0 ;Zeroes
dd 0x00000080 ;Address of PE header

; I don't know how to write the stub as text, so you get zeroes
times 32 dw 0

;*****************
;*** PE header ***
;*****************
dd 0x00004550 ;PE Magic number
dw 0x8664 ;Building for x86 architecture
dw 2 ;Two sections (.text, .data)
dd 0x5f73ca80 ;number of seconds between 00:00:00 1st January 1970 and 00:00:00 1st September 2021
dd 0x0 ;No symbol table
dd 0x0 ;No symbols in the non-existent symbol table!
dw oSize ;The size of the entire optional header. See the OPTIONAL_HEADER_END label for the calculation.
dw 0x1002 ;Is a valid image file, is a system file. No other fancy characteristics.

;used to calculate optional header size
oSize equ OPTIONAL_HEADER_END - OPTIONAL_HEADER_STANDARD_FIELDS

;***********************************************
;*** (not) Optional header - Standard Fields ***
;***********************************************
OPTIONAL_HEADER_STANDARD_FIELDS:
dw 0x020b ;PE32+ Executable. I want my 64-bit registers!
dw 0x0 ;What linker?
dd 2048 ;The size of the code segment
dd 2048 ;The size of the data segment
dd 0x0 ;No .bss section. All variables to be initialised.
dd 512 ;The program's entry point
dd 512 ;The program's first instruction. Same as the start of the code execution. Duh.

;*************************************************************
;*** (not) Optional header - (not) Windows Specific Fields ***
;*************************************************************
dq 0x00100000 ;The entry point of the image
dd 0x512 ;The section alignment
dd 0x512 ;The file alignment
dw 0x0 ;No operating system requirements
dw 0x0 ;Stil no operating system requirements
dw 0x0 ;Major image version number
dw 0x1 ;Minor image version number
dw 0x1 ;Major subsystem version. Doesn't matter, as long as it supports UEFI.
dw 0x1 ;Minor subsystem version. Needs to be EFI 1.1+ because of the use of the locateHandleBuffer method
dd 0x0 ;A dedicated zero
dd 4608 ;Image size
dd 512 ;Header size
dd 0x0 ;Checksum //TODO ADD LATER
dw 0x000A ;UEFI application.
dw 0x0 ;Not a DLL, so this can be zero

;Using PE32+ file type, so the following are dqs, not dds
dq 0x8000 ;Amount of stack space to reserve
dq 0x8000 ;Amount of stack space to commit immediately
dq 0x8000 ;Amount of local heap space to reserve
dq 0x0 ;Amount of local heap space to commit immediately. Hopefully not needed.
dd 0x0 ;Another four bytes dedicated to being zeroes
dd 0x0 ;Number of data dictionary entries

;OPTIONAL_HEADER_DATA_DIRECTORIES: ;We don't have any special sections, so this part actually is optional!

OPTIONAL_HEADER_END: ;This label is required for calculating value of oSize

;*********************
;*** Section table ***
;*********************

;as if you don't have enough information already :\
.1: ;text section
	dq `.text` ;The name of the text section
	dd 2048 ;virtual size.
	dd 512 ;virtual entry point address.
	dd 2048 ;actual size.
	dd 512 ;actual entry point address.
	dd 0 ;No relocations
	dd 0 ;No line numbers
	dw 0 ;No relocations
	dw 0 ;No line numbers
	dd 0x60000020 ;Contains executable code, can be executed as code, can be read.

.2: ;data section
	dq `.data` ;The name of the data section
	dd 2048 ;virtual size.
	dd 2560 ;virtual entry point address.
	dd 2048 ;actual size.
	dd 2560 ;actual entry point address.
	dd 0 ;No relocations
	dd 0 ;No line numbers
	dw 0 ;No relocations
	dw 0 ;No line numbers
	dd 0xc0000040 ;Contains initialised data, can be read, can be written to.

;Do the header section alignment!
times 512 - ($-$$) db 0 ;alignment








			;***************************
			;****** TEXT SEGMENT *******
			;*** This gives UEFI the ***
			;*** instructions to run ***
			;***************************

section .text follows=.header

sub rsp, 0x28 ; Align stack, assign shadow space

;*****************************************
;*** Setup EFI system table references ***
;*****************************************
;Start moving handoff variables.
mov [EFI_HANDLE], rcx
mov [EFI_SYSTEM_TABLE], rdx
mov [EFI_RETURN], rsp

;Set up necessary boot services functions
add rdx, [OFFSET_TABLE_BOOT_SERVICES] ;get boot services table
mov rcx, [rdx]
mov [BOOT_SERVICES], rcx
add rcx, [OFFSET_BOOT_FREE_POOL] ;get free pool function from boot services table
mov rdx, [rcx]
mov [BOOT_SERVICES_FREE_POOL], rdx
mov rcx, [BOOT_SERVICES]
add rcx, [OFFSET_BOOT_LOCATE_HANDLE_BUFFER] ;get locate handle function from boot services table
mov rdx, [rcx]
mov [BOOT_SERVICES_LOCATE_HANDLE_BUFFER], rdx
mov rcx, [BOOT_SERVICES]
add rcx, [OFFSET_BOOT_EXIT_PROGRAM] ;get exit function from boot services table
mov rdx, [rcx]
mov [BOOT_SERVICES_EXIT], rdx
mov rcx, [BOOT_SERVICES]
add rcx, [OFFSET_BOOT_STALL] ;get stall function from boot services table
mov rdx, [rcx]
mov [BOOT_SERVICES_STALL], rdx

;Set up necessary console functions
mov rdx, [EFI_SYSTEM_TABLE]
add rdx, [OFFSET_TABLE_ERROR_CONSOLE] ;get error console table
mov rcx, [rdx]
mov [CONERR], rcx
add rcx, [OFFSET_CONSOLE_OUTPUT_STRING] ;get output string function from console table
mov rdx, [rcx]
mov [CONERR_PRINT_STRING], rdx

mov rdx, [EFI_SYSTEM_TABLE]
add rdx, [OFFSET_TABLE_OUTPUT_CONSOLE] ;get output console table
mov rcx, [rdx]
mov [CONOUT], rcx
add rcx, [OFFSET_CONSOLE_OUTPUT_STRING] ;get output string function from console table
mov rdx, [rcx]
mov [CONOUT_PRINT_STRING], rdx

;*************************
;*** MAIN PROGRAM FLOW ***
;*************************
;Make sure we have console support
mov rcx, GUID_EFI_SIMPLE_TEXT_OUTPUT_PROTOCOL
call loadedProtocolCount
cmp rcx, 0
je exitOnZeroCount

;Print information string
lea rcx, [info]
call printString

;Print test error string
lea rcx, [errorInfo]
call printErrorString

;Make sure there is graphics support
mov rcx, GUID_EFI_GRAPHICS_OUTPUT_PROTOCOL
call loadedProtocolCount
cmp rcx, 0
je exitOnZeroCount

;Print graphics info string
push rcx
push rcx
lea rcx, [graphicsInfo]
call printString
pop rcx
pop rcx
call printNumber
mov rcx, protocolsOpen
call printString

;Make sure there is simple file system support
mov rcx, GUID_EFI_SIMPLE_FILE_SYSTEM_PROTOCOL
call loadedProtocolCount
cmp rcx, 0
je exitOnZeroCount

;Print simple file system string
push rcx
push rcx
lea rcx, [fileSystemInfo]
call printString
pop rcx
pop rcx
call printNumber
mov rcx, protocolsOpen
call printString

;Print final string
lea rcx, [gotThere]
call printString

;Return back to the UEFI with success!
mov rcx, [EFI_SUCCESS]
call exit

exitOnZeroCount:
mov rcx, necessaryProtocolMissingError
call printErrorString
mov rcx, [EFI_INCOMPATIBLE_VERSION]
call exit

;****************************************************************
;***           USER-ACCESSIBLE HIGH-LEVEL FUNCTIONS           ***
;***   Each function label has its own comments concerning    ***
;***                the following three areas:                ***
;*** - Definition: what it does                               ***
;*** - Input: what it needs to do it                          ***
;*** - Output: What the program can use from it               ***
;***                                                          ***
;*** If a register is not listed in the output, you can       ***
;***  assume that all other registers have been saved,        ***
;***  except rax, which UEFI uses for function return codes.  ***
;***                                                          ***
;*** Also, since each function does its own error management, ***
;***  Do NOT call a function expecting an error, as some bad  ***
;***  function calls will cause the entire program to exit.   ***
;***                                                          ***
;*** Also, if a function name is followed by                  ***
;*** [BOOT FUNCTION ONLY], then it cannot be called once the  ***
;*** operating system exits boot services.                    ***
;****************************************************************

;****************************************************
;*** printlnNumber                                ***
;*** Definition: prints a number to the console,  ***
;***             and also a new line string       ***
;*** Input: rcx is a signed number (max 64-bit)   ***
;*** Output: none                                 ***
;****************************************************
printlnNumber:
	push rcx
	call printNumber

	lea rcx, [nextLine]
	call printString

	pop rcx
	ret

;**************************************************
;*** printNumber                                ***
;*** Definition: prints a number to the console ***
;*** Input: rcx is a signed number (max 64-bit) ***
;*** Output: none                               ***
;**************************************************

;Note: Maximum number is 9,223,372,036,854,775,807 (or 0x7fffffffffffffff),
;      minimum number is -9,223,372,036,854,775,808 (or 0xffffffffffffffff)
printNumber:
	;Push variables that will be used
	push rcx
	push rdx
	push r8

	;Start with negative sign if number is less than 0
	cmp rcx, 0
	jge PNbigStart
	push rcx
	sub rsp, 8
	lea rcx, [negativeSign]
	call printString
	add rsp, 8
	pop rcx
	neg rcx

	;Remove leading zeroes
	PNbigStart:
	mov rax, [maxDivide]
	mov rdx, 0
	mov r8, 10
	PNbig:
	cmp rcx, rax
	jge PNnormal
	idiv r8 ;rax is a tenth of maxDivide
	jmp PNbig

	;Get number to print
	PNnormal:
	mov rdx, rax
	mov rax, rcx
	mov rcx, rdx
	mov rdx, 0
	idiv rcx

	;Print number digit
	PNprint:
	add rax, 0x30
	mov [currentNumberChar], rax
	mov r8, rcx
	lea rcx, [currentNumberChar]
	call printString

	;Stop printing if there's nothing left to print
	cmp rdx, 0
	je PNend

	;More digits to print. Divide the divider by 10
	mov rcx, rdx
	mov rax, r8
	mov rdx, 0
	mov r8, 10
	idiv r8 ;rax is the new divider, rcx is the new number, rdx should be 0, r8 is 10
	jmp PNnormal

	;Pop variables that were used
	PNend:
	pop r8
	pop rdx
	pop rcx
	ret

;******************************************************************************
;*** loadedProtocolCount [BOOT FUNCTION ONLY]                               ***
;*** Definition: checks if a protocol of the given                          ***
;***             type has been loaded by the system                         ***
;*** Input: rcx is a pointer to the protocol identifier                     ***
;*** Output: rcx is the amount of loaded handles that support that protocol ***
;******************************************************************************
loadedProtocolCount:
	;Call the function
	push rdx
	call locateHandlesByProtocol
	cmp rdx, 0
	je LPCnoFreeBuffer
	call freeBuffer

	LPCnoFreeBuffer:
	mov rcx, rdx
	pop rdx
	ret

;****************************************************************
;***           USER-ACCESSIBLE LOW-LEVEL FUNCTIONS            ***
;***   Each function label has its own comments concerning    ***
;***                the following three areas:                ***
;*** - Definition: what it does                               ***
;*** - Input: what it needs to do it                          ***
;*** - Output: What the program can use from it               ***
;***                                                          ***
;*** If a register is not listed in the output, you can       ***
;***  assume that all other registers have been saved,        ***
;***  except rax, which UEFI uses for function return codes.  ***
;***                                                          ***
;*** Also, since each function does its own error management, ***
;***  Do NOT call a function expecting an error, as some bad  ***
;***  function calls will cause the entire program to exit.   ***
;***                                                          ***
;*** Also, if a function name is followed by                  ***
;*** [BOOT FUNCTION ONLY], then it cannot be called once the  ***
;*** operating system exits boot services.                    ***
;****************************************************************

;****************************************************************
;*** printString                                              ***
;*** Definition: prints a utf16 string to the output console. ***
;*** Input: rcx is the address of the start of the string     ***
;*** Output: none                                             ***
;****************************************************************
printString:
	;Call the function
	push rcx
	push rdx
	push r8
	push r9
	push r10
	push r11
	mov rdx, rcx
	mov rcx, [CONOUT]
	sub rsp, 0x28
	call [CONOUT_PRINT_STRING]

	;Check for errors
	cmp rax, [EFI_SUCCESS]
	je PSend

	cmp rax, [EFI_WARNING_UNKNOWN_GLYPH]
	jne PS1
	mov rcx, unknownGlyphError
	jmp PSerr

	PS1:
	cmp rax, [EFI_UNSUPPORTED]
	jne PS2
	mov rcx, unsupportedError
	jmp PSerrExit

	PS2:
	cmp rax, [EFI_DEVICE_ERROR]
	jne PS3
	mov rcx, deviceError
	jmp PSerrExit

	PS3:
	;Unknown error, let's just end the program here...
	mov rcx, unknownError
	jmp PSerrExit

	PSerr:
	call printErrorString

	;Return
	PSend:
	add rsp, 0x28
	pop r11
	pop r10
	pop r9
	pop r8
	pop rdx
	pop rcx
	ret

	PSerrExit:
	call printErrorString
	mov rcx, rax
	call exit

;***************************************************************
;*** printErrorString                                        ***
;*** Definition: prints a utf16 string to the error console. ***
;*** Input: rcx is the address of the start of the string    ***
;*** Output: none                                            ***
;***************************************************************
printErrorString:
	;Call the function
	push rcx
	push rdx
	push r8
	push r9
	push r10
	push r11
	mov rdx, rcx
	mov rcx, [CONERR]
	sub rsp, 0x28
	call [CONERR_PRINT_STRING]

	;Check for errors
	cmp rax, [EFI_SUCCESS]
	je PESend

	cmp rax, [EFI_WARNING_UNKNOWN_GLYPH]
	jne PES1
	mov rcx, unknownGlyphError
	jmp PESerr

	PES1:
	cmp rax, [EFI_UNSUPPORTED]
	jne PES2
	jmp PESerrExit

	PES2:
	cmp rax, [EFI_DEVICE_ERROR]
	jne PES3
	jmp PESerrExit

	PES3:
	;Unknown error, let's just end the program here...
	jmp PESerrExit

	PESerr:
	call printErrorString

	;Return
	PESend:
	add rsp, 0x28
	pop r11
	pop r10
	pop r9
	pop r8
	pop rdx
	pop rcx
	ret

	PESerrExit:
	mov rcx, rax
	call exit


;**************************************************************************************************
;*** locateHandlesByProtocol [BOOT FUNCTION ONLY]                                               ***
;*** Definition: provides a list and count of every handle that supports the requested protocol ***
;*** Input: rcx is the address of the protocol GUID                                             ***
;*** Output: rcx holds address to the buffer containing the array of handles found              ***
;***         rdx holds the number of handles with that protocol                                 ***
;**************************************************************************************************
locateHandlesByProtocol:
	;Call the function
	push r8
	push r9
	push r10
	push r11
	mov rdx, rcx
	mov rcx, [LOCATE_PROTOCOL_SEARCH_PROTOCOL]
	mov r8, 0 ;null
	mov r9, LOCATE_PROTOCOL_HANDLE_COUNT
	mov r10, LOCATE_PROTOCOL_BUFFER_ADDRESS

	;TODO - Should there be this many push/pop operations?
	push r8
	push r9
	push r10
	sub rsp, 0x20
	call [BOOT_SERVICES_LOCATE_HANDLE_BUFFER]

	;Check for errors
	cmp rax, [EFI_SUCCESS]
	je LHBPend

	cmp rax, [EFI_INVALID_PARAMETER]
	jne LHBP1
	mov rcx, invalidParameterError
	jmp LHBPerrExit

	LHBP1:
	cmp rax, [EFI_OUT_OF_RESOURCES]
	jne LHBP2
	mov rcx, outOfResourcesError
	jmp LHBPerrExit

	LHBP2:
	cmp rax, [EFI_NOT_FOUND]
	jne LHBP3
	mov rcx, notFoundError
	jmp LHBPerr

	LHBP3:
	;Unknown error, let's just end the program here...
	mov rcx, unknownError
	jmp LHBPerrExit

	LHBPerr:
	call printErrorString

	;Return
	LHBPend:
	;TODO - Should there be this many push/pop operations?
	add rsp, 0x20
	pop r10
	pop r9
	pop r8
	mov rcx, [LOCATE_PROTOCOL_BUFFER_ADDRESS]
	mov rdx, [LOCATE_PROTOCOL_HANDLE_COUNT]
	pop r11
	pop r10
	pop r9
	pop r8
	ret

	LHBPerrExit:
	call printErrorString
	mov rcx, rax
	call exit

;***************************************************************************
;*** freeBuffer [BOOT FUNCTION ONLY]                                     ***
;*** Definition: Frees all of the memory allocated from the buffer given ***
;*** Input: rcx = pointer to buffer in memory                            ***
;*** Output: None                                                        ***
;***************************************************************************
freeBuffer:
	;Call the function
	push rcx
	push rdx
	push r8
	push r9
	push r10
	push r11
	sub rsp, 0x28
	call [BOOT_SERVICES_FREE_POOL]

	;Check for errors
	cmp rax, [EFI_SUCCESS]
	je FBend

	cmp rax, [EFI_INVALID_PARAMETER]
	jne FB1
	mov rcx, invalidParameterError
	jmp FBerrExit

	FB1:
	;Unknown error, let's just end the program here...
	mov rcx, unknownError
	jmp FBerrExit

	;Return
	FBend:
	add rsp, 0x28
	pop r11
	pop r10
	pop r9
	pop r8
	pop rdx
	pop rcx
	ret

	FBerrExit:
	call printErrorString
	mov rcx, rax
	call exit

;*********************************************************************
;*** waitForTime [BOOT FUNCTION ONLY]                              ***
;*** Definition: stalls all execution for the given amount of time ***
;*** Input: rcx is the amount of time to wait for, in microseconds ***
;***        (1 millisecond = 1000 microseconds)                    ***
;*** Output: None                                                  ***
;*********************************************************************
waitForTime:
	;Call the function
	push rcx
	push rdx
	push r8
	push r9
	push r10
	push r11
	sub rsp, 0x28
	call [BOOT_SERVICES_STALL]

	;No errors to check for in this function
	;Plus, if there is an error, do I really want to deal with it?

	;Return
	add rsp, 0x28
	pop r11
	pop r10
	pop r9
	pop r8
	pop rdx
	pop rcx
	ret

;*******************************************************************************
;*** exit [BOOT FUNCTION ONLY]                                               ***
;*** Definition: exits the operating system                                  ***
;*** Input: rcx is the return code. Please see the UEFI specifications       ***
;***        or the data segment for expected return codes.                   ***
;*** Output: Does not return! Other registers are modified by this function. ***
;*******************************************************************************
exit:
	;Wait 5 seconds so that the user can read whatever the error message is!
	mov rcx, [waitTime]
	call waitForTime

	;Call the function
	sub rsp, 0x28
	mov rdx, rcx
	mov rcx, [EFI_HANDLE]
	mov r8, 8
	call [BOOT_SERVICES_EXIT]

	;It should not get to this point
	;If it does, just hang for (2^63)-1 seconds. Enough to make a user turn their computer off.
	mov rcx, 0x7fffffffffffffff
	call waitForTime

;Do the text segment section alignment!
times 2048 - ($-$$) db 0 ;alignment








			;**********************************************
			;**************** DATA SEGMENT ****************
			;*** This tells UEFI where and how to store ***
			;*** the data the program needs to work     ***
			;**********************************************

section .data follows=.text

;*************************************
;*** The full list of system table ***
;*** offsets used in this program  ***
;*************************************
OFFSET_TABLE_BOOT_SERVICES dq 96
OFFSET_TABLE_ERROR_CONSOLE dq 80
OFFSET_TABLE_OUTPUT_CONSOLE dq 64
OFFSET_BOOT_FREE_POOL dq 72
OFFSET_BOOT_EXIT_PROGRAM dq 216
OFFSET_BOOT_STALL dq 248
OFFSET_BOOT_LOCATE_HANDLE_BUFFER dq 312
OFFSET_CONSOLE_OUTPUT_STRING dq 8

;************************
;*** Number constants ***
;************************
waitTime dq 5000000 ;Five million microseconds, equals five seconds
maxDivide dq 1000000000000000000 ;highest 64-bit divide
base10 dq 10 ;Dividing by 10 gets a base 10 digit

;*****************************************
;*** The full list of EFI function     ***
;*** return codes used in this program ***
;*****************************************
EFI_SUCCESS dq 0
EFI_WARNING_UNKNOWN_GLYPH dq 1
EFI_INVALID_PARAMETER dq 0x8000000000000002
EFI_UNSUPPORTED dq 0x8000000000000003
EFI_DEVICE_ERROR dq 0x8000000000000007
EFI_OUT_OF_RESOURCES dq 0x8000000000000009
EFI_VOLUME_CORRUPTED dq 0x800000000000000a
EFI_NO_MEDIA dq 0x800000000000000c
EFI_MEDIA_CHANGED dq 0x800000000000000d
EFI_NOT_FOUND dq 0x800000000000000e
EFI_ACCESS_DENIED dq 0x800000000000000f
EFI_INCOMPATIBLE_VERSION dq 0x8000000000000019 ;used in this application to represent unknown errors!

;*********************************
;*** Stores handover variables ***
;*********************************
EFI_HANDLE dq 0
EFI_SYSTEM_TABLE dq 0
EFI_RETURN dq 0

;***************************************
;*** Stores addresses for calls      ***
;*** related to the EFI system table ***
;***************************************
BOOT_SERVICES dq 0
BOOT_SERVICES_EXIT dq 0 ;This one exits the program, not just stop boot services!
BOOT_SERVICES_FREE_POOL dq 0
BOOT_SERVICES_LOCATE_HANDLE_BUFFER dq 0
BOOT_SERVICES_STALL dq 0
CONERR dq 0
CONERR_PRINT_STRING dq 0
CONOUT dq 0
CONOUT_PRINT_STRING dq 0

;**********************************
;*** The full list of protocol  ***
;*** GUIDs used in this program ***
;**********************************
;128-bit GUIDs? 16 bits would've been more than sufficient!
GUID_EFI_SIMPLE_TEXT_OUTPUT_PROTOCOL 	dd 0x387477c2
					dw 0x69c7, 0x11d2
					db 0x8e, 0x39, 0x00, 0xa0, 0xc9, 0x69, 0x72, 0x3b
GUID_EFI_GRAPHICS_OUTPUT_PROTOCOL	dd 0x9042a9de
					dw 0x23dc, 0x4a38
					db 0x96, 0xfb, 0x7a, 0xde, 0xd0, 0x80, 0x51, 0x6a
GUID_EFI_SIMPLE_FILE_SYSTEM_PROTOCOL	dd 0x964e5b22
					dw 0x6459, 0x11d2
					db 0x8e, 0x39, 0x00, 0xa0, 0xc9, 0x69, 0x72, 0x3b

;****************************************
;*** Stores values related to the     ***
;*** UEFI LocateHandleBuffer function ***
;****************************************
LOCATE_PROTOCOL_SEARCH_PROTOCOL dq 2
LOCATE_PROTOCOL_HANDLE_COUNT dq 0
LOCATE_PROTOCOL_BUFFER_ADDRESS dq 0

;**********************************
;*** Strings used for debugging ***
;**********************************
debug1 db __utf16__ `Debug 1!\r\n\0`
debug2 db __utf16__ `Debug 2!\r\n\0`
debug3 db __utf16__ `Debug 3!\r\n\0`
debug4 db __utf16__ `Debug 4!\r\n\0`

;*****************************************
;*** Strings used for printing numbers ***
;*****************************************
nextLine db __utf16__ `\r\n\0`
negativeSign db __utf16__ `-\0`
zeroNumber db 0x30 ;Convert number to character that represents this number
currentNumberChar db __utf16__ `0\0`
db __utf16__ `0\0` ;Needed to allow the following string to exist.

;***************************************
;*** Strings used for displaying     ***
;*** helpful information to the user ***
;***************************************
info db __utf16__ `Hello! This is the output console!\r\n\0`
errorInfo db __utf16__ `And this is the error console! Hopefully you don't see any of these messages!\r\n\0`
graphicsInfo db __utf16__ `We have graphics support: \0`
fileSystemInfo db __utf16__ `We have file system support: \0`
fileSystemOpenInfo db __utf16__ `Opening file systems!\r\n\0`
protocolsOpen db __utf16__ ` protocols open!\r\n\0`
gotThere db __utf16__ `That's all for now. Tune in for more fun in the future!\r\n\0`

;****************************************************
;*** Strings used for unsuccessful function calls ***
;****************************************************
unknownGlyphError db __utf16__ `Cannot display character!\r\n\0`
invalidParameterError db __utf16__ `Invalid parameter!\r\n\0`
unsupportedError db __utf16__ `Command unsupported!\r\n\0`
deviceError db __utf16__ `Hardware error!\r\n\0`
outOfResourcesError db __utf16__ `Out of resources!\r\n\0`
notFoundError db __utf16__ `Result not found!\r\n\0`
unknownError db __utf16__ `An unknown error occurred!\r\n\0`

necessaryProtocolMissingError db __utf16__ `A protocol necessary for the operation of Project Turtle is missing!`

;Do the data segment section alignment!
times 2048 - ($-$$) db 0 ;alignment
