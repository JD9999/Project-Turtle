; Author: Jamie Douglass
; A UEFI application corresponding to the UEFI Specification version 2.10.
; Thanks to BrianOtto (https://github.com/BrianOtto/nasm-uefi)
; and Charlesap (https://github.com/charlesap/nasm-uefi) for your previous UEFI implementations.
; I have learned much from your code :)

BITS 64
org 0x00400000 ;128KiB stack space








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
dd 1024 ;The size of the data segment
dd 0x0 ;No .bss section. All variables to be initialised.
dd 512 ;The program's entry point
dd 512 ;The program's first instruction. Same as the start of the code execution. Duh.

;*************************************************************
;*** (not) Optional header - (not) Windows Specific Fields ***
;*************************************************************
dq 0x00400000 ;The entry point of the image
dd 0x512 ;The section alignment
dd 0x512 ;The file alignment
dw 0x0 ;No operating system requirements
dw 0x0 ;Stil no operating system requirements
dw 0x0 ;Major image version number
dw 0x1 ;Minor image version number
dw 0x1 ;Major subsystem version. Doesn't matter, as long as it supports UEFI.
dw 0x1 ;Minor subsystem version. Needs to be EFI 1.1+ because of the use of the openProtocol function
dd 0x0 ;A dedicated zero
dd 4096 ;Image size
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
	dd 1536 ;virtual size.
	dd 2560 ;virtual entry point address.
	dd 1536 ;actual size.
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

;Set up necessary boot services functions
add rdx, [OFFSET_SYSTEM_TABLE_BOOT_SERVICES] ;get boot services table
mov rcx, [rdx]
mov [ADDRESS_BOOT_SERVICES], rcx

mov rcx, [ADDRESS_BOOT_SERVICES]
add rcx, [OFFSET_BOOT_EXIT_PROGRAM] ;get exit function from boot services table
mov rdx, [rcx]
mov [ADDRESS_BOOT_SERVICES_EXIT], rdx

mov rcx, [ADDRESS_BOOT_SERVICES]
add rcx, [OFFSET_BOOT_LOAD_IMAGE] ;get load image function from boot services table
mov rdx, [rcx]
mov [ADDRESS_BOOT_SERVICES_LOAD_IMAGE], rdx

mov rcx, [ADDRESS_BOOT_SERVICES]
add rcx, [OFFSET_BOOT_LOCATE_PROTOCOL] ;get locate protocol function from boot services table
mov rdx, [rcx]
mov [ADDRESS_BOOT_SERVICES_LOCATE_PROTOCOL], rdx

mov rcx, [ADDRESS_BOOT_SERVICES]
add rcx, [OFFSET_BOOT_OPEN_PROTOCOL] ;get load image function from boot services table
mov rdx, [rcx]
mov [ADDRESS_BOOT_SERVICES_OPEN_PROTOCOL], rdx

mov rcx, [ADDRESS_BOOT_SERVICES]
add rcx, [OFFSET_BOOT_STALL] ;get open protocol function from boot services table
mov rdx, [rcx]
mov [ADDRESS_BOOT_SERVICES_STALL], rdx

mov rcx, [ADDRESS_BOOT_SERVICES]
add rcx, [OFFSET_BOOT_START_IMAGE] ;get start image function from boot services table
mov rdx, [rcx]
mov [ADDRESS_BOOT_SERVICES_START_IMAGE], rdx

;Set up necessary console functions
mov rdx, [EFI_SYSTEM_TABLE]
add rdx, [OFFSET_SYSTEM_TABLE_ERROR_CONSOLE] ;get error console table
mov rcx, [rdx]
mov [ADDRESS_CONERR], rcx

mov rdx, [EFI_SYSTEM_TABLE]
add rdx, [OFFSET_SYSTEM_TABLE_OUTPUT_CONSOLE] ;get output console table
mov rcx, [rdx]
mov [ADDRESS_CONOUT], rcx

;*************************
;*** MAIN PROGRAM FLOW ***
;*************************
;Print hello string
mov rcx, [ADDRESS_CONOUT]
mov rdx, hello
call printString
cmp rax, [RETURN_SUCCESS]
jne exit

;If there is a different console for error output, print a hello string there too!
mov rcx, [ADDRESS_CONOUT]
mov rdx, [ADDRESS_CONERR]
cmp rcx, rdx
je getImageProtocol

mov rcx, [ADDRESS_CONERR]
mov rdx, CONSTANT_CONSOLE_RED_ON_BLACK
call setConsoleColour
cmp rax, [RETURN_SUCCESS]
je printErrorString
call warnWithError

printErrorString:
mov rdx, errorHello
call printString
cmp rax, [RETURN_SUCCESS]
jne exitWithError

;Now that I have printed with the output and the error console, I will not check for errors on the consoles anymore, just assume that they work

getImageProtocol:
;Get the loaded image protocol for this handle
mov rcx, [EFI_HANDLE]
mov rdx, GUID_EFI_LOADED_IMAGE_PROTOCOL
call getProtocolFromHandle
cmp rax, [RETURN_SUCCESS]
jne exitWithError
mov [ADDRESS_LOADED_IMAGE], rcx

;Get an instance of the device path utilities protocol
mov rcx, GUID_EFI_DEVICE_PATH_UTILITIES_PROTOCOL
call locateProtocol
cmp rax, [RETURN_SUCCESS]
jne exitWithError
mov [ADDRESS_DEVICE_PATH_UTILITIES_PROTOCOL], rcx
mov rcx, [rcx]
mov [ADDRESS_DEVICE_PATH_UTILITIES_PROTOCOL_GET_DEVICE_PATH_SIZE], rcx

;Print the size of the loaded image device path
mov rcx, [ADDRESS_LOADED_IMAGE]
add rcx, [OFFSET_LOADED_IMAGE_DEVICE_PATH]
mov rcx, [rcx]
call getDevicePathSize
cmp rax, [RETURN_SUCCESS]
jne exitWithError
mov r9, rcx
mov rcx, [ADDRESS_CONOUT]
mov rdx, sizeString
call printString
mov rdx, r9
call printNumber
mov rdx, newLine
call printString

;Do not continue with the rest of the code, the device path protocol node is completely broken and will cause the app to crash!
;;Load turtle image
;mov rcx, turtleDevicePathProtocol
;call loadImage
;cmp rax, [RETURN_SUCCESS]
;jne exitWithError

;mov r8, rcx

;Print image loaded message
;mov rcx, [ADDRESS_CONOUT]
;mov rdx, imageLoaded
;call printString

;Start turtle image
;mov rcx, r8
;call startImage
;cmp rax, [RETURN_SUCCESS]
;jne exitWithError

;Print our exit message
mov rcx, [ADDRESS_CONOUT]
mov rdx, goodbye
call printString

;Wait 5 seconds
mov rcx, 5000000
call waitForTime

;Return back to the UEFI with success!
mov rcx, [RETURN_SUCCESS]
call exit

;******************************************************************
;***		USER-ACCESSIBLE HIGH-LEVEL FUNCTIONS		***
;*** Each function label has its own comments concerning the	***
;*** the following three areas:				***
;*** - Definition: what it does				***
;*** - Input: what it needs to do it				***
;*** - Output: What the program can use from it		***
;***								***
;*** Any registers used by the function are saved, excluding	***
;*** rax, output registers, and exit functions.		***
;******************************************************************

;**************************************************************************
;*** exitWithError							***
;*** Definition: Exits the application with a given error code		***
;*** Input: rax is the error code					***
;*** Output: Does not return! Registers are not saved by this function! ***
;**************************************************************************
exitWithError:
	;Print the error message
	and rax, [MASK_IGNORE_TOP_BIT]
	mov r8, rax
	mov rcx, [ADDRESS_CONERR]
	mov rdx, failing
	call printString
	mov rdx, r8
	call printNumber
	mov rdx, exiting
	call printString
	
	;Give the user time to read it before exiting
	mov rcx, 5000000
	call waitForTime
	mov rcx, r8
	call exit
	
	;Shouldn't get here, but just in case
	ret
	
;**************************************************************************
;*** warnWithError							***
;*** Definition: Warns the user of an application error with a given	***
;*** 		 error code.						***
;*** Input: rax is the error code					***
;*** Output: None							***
;**************************************************************************
warnWithError:
	;Push variables that will be used
	push rcx
	push rdx
	push r8
	
	;Print the error message
	and rax, [MASK_IGNORE_TOP_BIT]
	mov r8, rax
	mov rcx, [ADDRESS_CONERR]
	mov rdx, failing
	call printString
	mov rdx, r8
	call printNumber
	mov rdx, warning
	call printString
	
	;Restore variables
	pop r8
	pop rdx
	pop rcx
	ret

;**************************************************************************
;*** printNumber							***
;*** Definition: Prints a 64-bit number to the given console.  	***
;*** 		 The given value must be between			***
;*** 		 -9,223,372,036,854,775,808 (0xffffffffffffffff) and	***
;***             9,223,372,036,854,775,807 (0x7fffffffffffffff)	***
;*** Input: rcx is the console to print to		 		***
;***	    rdx is a signed number (max 64-bit) 			***
;*** Output: none                              			***
;**************************************************************************

;Note: Maximum number is 9,223,372,036,854,775,807 (or 0x7fffffffffffffff),
;      minimum number is -9,223,372,036,854,775,808 (or 0xffffffffffffffff)
printNumber:
	;Push variables that will be used
	push rax
	push rcx
	push rdx
	push r8
	push r9

	;If number is negative, print negative sign and negate
	cmp rdx, 0
	jge PNPositive
	mov r8, rdx
	mov rdx, negativeSign
	call printString
	neg r8
	mov rdx, r8
	
	PNPositive:
	cmp rdx, 9
	jg PNLarge
	add rdx, 0x30
	mov [currentNumberChar], rdx
	mov rdx, currentNumberChar
	call printString
	jmp PNReturn
		
	PNLarge:
	mov r9, rdx
	mov rax, [CONSTANT_MAXIMUM_NUMBER_DIVISOR_64]
	mov r8, 10
	PNReduce:
	cmp rax, r9
	jl PNDigit
	mov rdx, 0
	div r8
	jmp PNReduce
	
	PNDigit: ;rax is the new divisor, r9 is the number
	mov r8, rax
	mov rax, r9
	mov rdx, 0
	div r8
	add rax, 0x30
	mov r9, rdx
	mov [currentNumberChar], rax
	mov rdx, currentNumberChar
	call printString
	
	cmp r8, 1
	je PNReturn

	PNNext:
	;Divide the divisor by 10 and keep going with the next number
	mov rax, r8
	mov rdx, 0
	mov r8, 10
	div r8
	jmp PNDigit

	;Pop variables that were used
	PNReturn:
	pop r9
	pop r8
	pop rdx
	pop rcx
	pop rax
	ret

;******************************************************************
;***		USER-ACCESSIBLE LOW-LEVEL FUNCTIONS		***
;*** Each function label has its own comments concerning the	***
;*** the following three areas:				***
;*** - Definition: what it does				***
;*** - Input: what it needs to do it				***
;*** - Output: What the program can use from it		***
;***								***
;*** Any registers used by the function are saved, excluding	***
;*** rax, output registers, and exit functions.		***
;***								***
;*** Any functions with are [BOOT FUNCTION ONLY] cannot be	***
;*** called once the application exits boot services.		***
;******************************************************************

;******************************************************************
;*** printString						***
;*** Definition: Prints a utf16 string to the output console.	***
;*** Input: rcx is the console to print to			***
;***        rdx is the address of the start of the string 	***
;*** Output: none						***
;******************************************************************
printString:
	;Save registers
	push rcx
	push rdx
	push r8
	push r9
	push r10
	push r11
	
	;Call the function
	mov r8, rcx
	add r8, [OFFSET_CONSOLE_OUTPUT_STRING]
	mov r9, [r8]
	sub rsp, 0x28
	call r9
	add rsp, 0x28
	
	;Restore registers
	pop r11
	pop r10
	pop r9
	pop r8
	pop rdx
	pop rcx
	ret
	
;******************************************************************************************
;*** setConsoleColour									***
;*** Definition: Sets the foreground and background colours of the given console. If	***
;***		 multiple consoles point to this console's address, then all of those	***
;***		 consoles will be changed to these colours as well.			***
;*** Input: rcx is the console								***
;***	    rdx is the foreground and background colour				***
;*** Output: none									***
;******************************************************************************************
setConsoleColour:
	;Save registers
	push rcx
	push rdx
	push r8
	push r9
	push r10
	push r11
	
	;Call the function
	mov r8, rcx
	add r8, [OFFSET_CONSOLE_SET_ATTRIBUTE]
	sub rsp, 0x28
	call [r8]
	add rsp, 0x28

	;Restore registers
	pop r11
	pop r10
	pop r9
	pop r8
	pop rdx
	pop rcx
	ret

;******************************************************************
;*** getProtocolFromHandle [BOOT FUNCTION ONLY]		***
;*** Definition: Gets an instance of the protocol which is	***
;***		 registered to the given image.		***
;*** Input: rcx is the image handle				***
;***        rdx is a pointer to the protocol's GUID		***
;*** Output: rcx is a pointer to the protocol's interface	***
;***	     installed on that handle.				***
;******************************************************************
getProtocolFromHandle:
	;Save registers
	push rdx
	push r8
	push r9
	push r10
	push r11
	
	;Call the function
	mov r8, BUFFER_OPENED_PROTOCOL
	mov r9, [EFI_HANDLE]
	mov r10, 0
	mov r11, [CONSTANT_OPEN_PROTOCOL_GET_PROTOCOL]
	push r11 ;Arguments to the stack must be pushed in reverse order
	push r10 
	sub rsp, 0x20
	call [ADDRESS_BOOT_SERVICES_OPEN_PROTOCOL]

	;Restore registers
	add rsp, 0x20
	pop r10
	pop r11
	pop r11
	pop r10
	pop r9
	pop r8
	pop rdx
	
	;Prepare return values and return
	mov rcx, [BUFFER_OPENED_PROTOCOL]
	ret
	
;**************************************************************************
;*** locateProtocol [BOOT FUNCTION ONLY]				***
;*** Definition: provides an interface to the requested protocol.	***
;*** Input: rcx is the address of the protocol GUID			***
;*** Output: rcx holds a pointer to the interface			***
;**************************************************************************
locateProtocol:
	;Save registers
	push rdx
	push r8
	push r9
	push r10
	push r11
	
	;Call the function
	mov rdx, 0
	mov r8, BUFFER_LOCATED_PROTOCOL
	sub rsp, 0x20
	call [ADDRESS_BOOT_SERVICES_LOCATE_PROTOCOL]

	;Restore registers
	add rsp, 0x20
	pop r11
	pop r10
	pop r9
	pop r8
	pop rdx
	
	;Prepare return values and return
	mov rcx, [BUFFER_LOCATED_PROTOCOL]
	ret
	
;******************************************************************
;*** loadImage [BOOT FUNCTION ONLY]				***
;*** Definition: Load an EFI boot driver from a file		***
;*** Input: rcx is a pointer to a device path protocol to load	***
;*** Output: rcx is the EFI handle				***
;******************************************************************
loadImage:
	;Save registers
	push rdx
	push r8
	push r9
	push r10
	push r11
	
	;Call the function
	mov r8, rcx
	mov rcx, 0
	mov rdx, [EFI_HANDLE]
	mov r9, 0
	mov r10, 0
	mov r11, BUFFER_LOAD_IMAGE
	push r11
	push r10
	sub rsp, 0x20
	call [ADDRESS_BOOT_SERVICES_LOAD_IMAGE]

	;Restore registers
	add rsp, 0x20
	pop r10
	pop r11
	pop r11
	pop r10
	pop r9
	pop r8
	pop rdx
	
	;Return
	mov rcx, [BUFFER_LOAD_IMAGE]
	ret
	
;******************************************************************
;*** startImage [BOOT FUNCTION ONLY]				***
;*** Definition: Start an EFI image				***
;*** Input: rcx is the EFI handle of the image to start	***
;*** Output: rcx is the size of exit data			***
;***	     rdx is a pointer to the exit data string		***
;******************************************************************
startImage:
	;Save registers
	push r8
	push r9
	push r10
	push r11
	
	;Call the function
	mov rdx, BUFFER_START_IMAGE_DATA_SIZE
	mov r8, BUFFER_START_IMAGE_DATA
	sub rsp, 0x28
	call [ADDRESS_BOOT_SERVICES_START_IMAGE]

	;Restore registers
	add rsp, 0x28
	pop r11
	pop r10
	pop r9
	pop r8
	
	;Return
	mov rcx, [BUFFER_START_IMAGE_DATA_SIZE]
	mov rdx, [BUFFER_START_IMAGE_DATA]
	ret
	
;**************************************************************************
;*** getDevicePathSize							***
;*** Definition: gets the total size of all nodes in the device	***
;*** 		 path, including the end-of-path tag			***
;*** Input: rcx is the address of the device path			***
;*** Output: rcx is the size of the device path			***
;**************************************************************************
getDevicePathSize:
	;Save registers
	push rdx
	push r8
	push r9
	push r10
	push r11
	
	;Call the function
	sub rsp, 0x20
	call [ADDRESS_DEVICE_PATH_UTILITIES_PROTOCOL_GET_DEVICE_PATH_SIZE] ;My gosh that's a long pointer name!

	;Restore registers
	add rsp, 0x20
	pop r11
	pop r10
	pop r9
	pop r8
	pop rdx
	
	;Return
	mov rcx, rax
	cmp rax, 0
	jne GDPSgood
	mov rax, [RETURN_INVALID_ARGUMENT] ;DevicePath is either null or something else, so it's invalid :(
	ret
	
	GDPSgood:
	mov rax, [RETURN_SUCCESS]
	ret
	
;*********************************************************************
;*** waitForTime [BOOT FUNCTION ONLY]                              ***
;*** Definition: Stalls all execution for the given amount of time ***
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
	call [ADDRESS_BOOT_SERVICES_STALL]

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

;**********************************************************************************
;*** exit [BOOT FUNCTION ONLY]							***
;*** Definition: Exits the operating system. No registers are saved!		***
;*** Input: rcx is the return code. Please see the UEFI specifications for	***
;***        expected return codes.						***
;*** Output: Does not return! Other registers are modified by this function.	***
;**********************************************************************************
exit:
	;Call the function
	mov rdx, rcx
	mov rcx, [EFI_HANDLE]
	mov r8, 0
	call [ADDRESS_BOOT_SERVICES_EXIT]

;Do the text segment section alignment!
times 2048 - ($-$$) db 0 ;alignment








			;**********************************************
			;**************** DATA SEGMENT ****************
			;*** This tells UEFI where and how to store ***
			;*** the data the program needs to work     ***
			;**********************************************

section .data follows=.text

;**************************
;*** Handover variables ***
;**************************
EFI_HANDLE dq 0
EFI_SYSTEM_TABLE dq 0

;****************************
;*** System Table offsets ***
;****************************
OFFSET_SYSTEM_TABLE_BOOT_SERVICES dq 96
OFFSET_SYSTEM_TABLE_ERROR_CONSOLE dq 80
OFFSET_SYSTEM_TABLE_OUTPUT_CONSOLE dq 64

;****************************************
;*** Boot table addresses and offsets ***
;****************************************
ADDRESS_BOOT_SERVICES dq 0
ADDRESS_BOOT_SERVICES_EXIT dq 0 ;This one exits the program, not just stop boot services!
ADDRESS_BOOT_SERVICES_LOAD_IMAGE dq 0
ADDRESS_BOOT_SERVICES_LOCATE_PROTOCOL dq 0
ADDRESS_BOOT_SERVICES_OPEN_PROTOCOL dq 0
ADDRESS_BOOT_SERVICES_STALL dq 0
ADDRESS_BOOT_SERVICES_START_IMAGE dq 0
OFFSET_BOOT_EXIT_PROGRAM dq 216
OFFSET_BOOT_LOAD_IMAGE dq 200
OFFSET_BOOT_OPEN_PROTOCOL dq 280
OFFSET_BOOT_LOCATE_PROTOCOL dq 320
OFFSET_BOOT_STALL dq 248
OFFSET_BOOT_START_IMAGE dq 208

;*************************************
;*** Console addresses and offsets ***
;*************************************
ADDRESS_CONERR dq 0
ADDRESS_CONOUT dq 0
OFFSET_CONSOLE_OUTPUT_STRING dq 8
OFFSET_CONSOLE_SET_ATTRIBUTE dq 40

;********************************************
;*** Other protocol addresses and offsets ***
;********************************************
ADDRESS_DEVICE_PATH_UTILITIES_PROTOCOL dq 0
ADDRESS_DEVICE_PATH_UTILITIES_PROTOCOL_GET_DEVICE_PATH_SIZE dq 0
ADDRESS_LOADED_IMAGE dq 0
OFFSET_LOADED_IMAGE_DEVICE_PATH dq 32

;*******************************************
;*** Protocol buffers and return storage ***
;*******************************************
BUFFER_LOAD_IMAGE dq 0
BUFFER_LOCATED_PROTOCOL dq 0
BUFFER_OPENED_PROTOCOL dq 0
BUFFER_START_IMAGE_DATA_SIZE dq 0
BUFFER_START_IMAGE_DATA dq 0

;*************
;*** GUIDs ***
;*************
GUID_EFI_DEVICE_PATH_UTILITIES_PROTOCOL	dd 0x0379be4e
						dw 0xd706, 0x437d
						db 0xb0, 0x37, 0xed, 0xb8, 0x2f, 0xb7, 0x72, 0xa4
GUID_EFI_LOADED_IMAGE_PROTOCOL			dd 0x5b1b31a1
						dw 0x9562, 0x11d2
						db 0x8e, 0x3f, 0x00, 0xa0, 0xc9, 0x69, 0x72, 0x3b
GUID_EFI_SIMPLE_TEXT_OUTPUT_PROTOCOL		dd 0x387477c2
						dw 0x69c7, 0x11d2
						db 0x8e, 0x39, 0x00, 0xa0, 0xc9, 0x69, 0x72, 0x3b
                                
;*********************************
;*** EFI function return codes ***
;*********************************
RETURN_SUCCESS dq 0
RETURN_INVALID_ARGUMENT dq 0x8000000000000002

;*********************************
;*** Masks for packed integers ***
;*********************************
MASK_FIRST_BYTE dq 0x00000000000000ff
MASK_SECOND_BYTE dq 0x00000000000ff00
MASK_THIRD_TO_FOURTH_BYTES dq 0x00000000ffff0000
MASK_FIFTH_TO_EIGHTH_BYTES dq 0xffffffff00000000
MASK_FIRST_TO_FOURTH_BYTES dq 0x00000000ffffffff
MASK_IGNORE_TOP_BIT dq 0x7fffffffffffffff

;***************************************
;*** Miscellaneous numeric constants ***f
;***************************************
CONSTANT_MAXIMUM_NUMBER_DIVISOR_64 dq 1000000000000000000 ;largest divisor to get a single-digit number from a 64-bit number
CONSTANT_CONSOLE_RED_ON_BLACK dq 4
CONSTANT_OPEN_PROTOCOL_GET_PROTOCOL dq 2

;***************************************
;*** Friendly hello/goodbye messages ***
;***************************************
hello db __utf16__ `Welcome to Project Turtle!\r\n\0`
errorHello db __utf16__ `If you have an error, it will look like this. Hopefully none of these will happen!\r\n\0`
goodbye db __utf16__ `See you later!\r\n\0`

;**********************
;*** Error messages ***
;**********************
failing db __utf16__ `Instruction failed with exit code \0`
exiting db __utf16__ `. Turtle is stopping!\r\n\0`
warning db __utf16__ `. This is not a critical error, so Turtle is continuing, but certain functionality may be reduced.\r\n\0`

;***********************
;*** Utility strings ***
;***********************
newLine db __utf16__ `\r\n\0`

;*******************************
;*** Number printing strings ***
;*******************************
negativeSign db __utf16__ `-\0`
currentNumberChar db __utf16__ `0\0`
zeroString db __utf16__ `0\0`

;*************************
;*** Debugging strings ***
;*************************
imageLoaded db __utf16__ `The turtle image was loaded!\r\n\0`
debug1 db __utf16__ `Debug 1!\r\n\0`
pathString db __utf16__ `Path:\0`
typeString db __utf16__ `Type:\0`
subtypeString db __utf16__ `Subtype:\0`
lengthString db __utf16__ `Length:\0`
sizeString db __utf16__ `Size is: \0`

;***************************************
;*** Bootloader device path protocol *** ;DELETE THIS, THIS IS COMPLETELY BROKEN!
;***************************************
turtleDevicePathProtocol	db 4
				db 4
				dw 38
				db __utf16__ `0\\EFI\\turtle.efi\0`
				
times 10 db 0 ;alignment

;Do the data segment section alignment!
times 1536 - ($-$$) db 0 ;alignment
