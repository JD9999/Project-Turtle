; Author: Jamie Douglass
; A UEFI application corresponding to the UEFI Specification version 2.9.
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
dd 512 ;The size of the code segment
dd 512 ;The size of the data segment
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
dw 0x1 ;Minor subsystem version. Needs to be EFI 1.1+ because of the use of the locateHandleBuffer method
dd 0x0 ;A dedicated zero
dd 1536 ;Image size
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
	dd 512 ;virtual size.
	dd 512 ;virtual entry point address.
	dd 512 ;actual size.
	dd 512 ;actual entry point address.
	dd 0 ;No relocations
	dd 0 ;No line numbers
	dw 0 ;No relocations
	dw 0 ;No line numbers
	dd 0x60000020 ;Contains executable code, can be executed as code, can be read.

.2: ;data section
	dq `.data` ;The name of the data section
	dd 512 ;virtual size.
	dd 1024 ;virtual entry point address.
	dd 512 ;actual size.
	dd 1024 ;actual entry point address.
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

mov rdx, [EFI_SYSTEM_TABLE]
add rdx, [OFFSET_TABLE_OUTPUT_CONSOLE] ;get output console table
mov rcx, [rdx]
mov [CONOUT], rcx

;*************************
;*** MAIN PROGRAM FLOW ***
;*************************
;Print information string
mov rcx, [CONOUT]
lea rdx, [hello]
call printString

;If printing failed, exit
cmp rax, 0
jne error

;Find out if our error console is the same as our normal output console
mov rcx, [CONOUT]
mov rdx, [CONERR]
cmp rcx, rdx
je finish

;Print test error string
mov rcx, COLOUR_RED_ON_BLACK
call setErrorColour
mov rcx, [CONERR]
lea rdx, [errorInfo]
call printString

finish:
;Print final string
mov rcx, [CONOUT]
lea rdx, [goodbye]
call printString

;Return back to the UEFI with success!
mov rcx, [RETURN_SUCCESS]
call exit

error:
;Return back to the UEFI with failing :(
mov rcx, rax
call exit

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
;*** Input: rcx is the console to print to                    ***
;***        rdx is the address of the start of the string     ***
;*** Output: none                                             ***
;****************************************************************
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
	
;*************************************************************************
;*** setErrorColour                                                    ***
;*** Definition: set the colour of the error console. Make sure that   ***
;***             the output console and error console aren't the same  ***
;***             otherwise the output console will be the same colour. ***
;*** Input: rcx is the foreground and background colour                ***
;*** Output: none                                                      ***
;*************************************************************************
setErrorColour:
	;Save registers
	push rcx
	push rdx
	push r8
	push r9
	push r10
	push r11
	
	;Call the function
	mov rdx, rcx
	mov rcx, [CONERR]
	mov r8, [CONERR]
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
times 512 - ($-$$) db 0 ;alignment








			;**********************************************
			;**************** DATA SEGMENT ****************
			;*** This tells UEFI where and how to store ***
			;*** the data the program needs to work     ***
			;**********************************************

section .data follows=.text

;******************************************
;*** System table offsets and addresses ***
;******************************************
OFFSET_TABLE_BOOT_SERVICES dq 96
OFFSET_TABLE_ERROR_CONSOLE dq 80
OFFSET_TABLE_OUTPUT_CONSOLE dq 64
OFFSET_BOOT_EXIT_PROGRAM dq 216
OFFSET_BOOT_STALL dq 248
BOOT_SERVICES dq 0
BOOT_SERVICES_EXIT dq 0 ;This one exits the program, not just stop boot services!
BOOT_SERVICES_STALL dq 0

;******************************************
;*** Console offsets and addresses ***
;******************************************
OFFSET_CONSOLE_OUTPUT_STRING dq 8
OFFSET_CONSOLE_SET_ATTRIBUTE dq 40
CONERR dq 0
CONOUT dq 0

;***************************************
;*** Miscellaneous numeric constants ***
;***************************************
waitTime dq 5000000 ;Five million microseconds, equals five seconds
RETURN_SUCCESS dq 0
COLOUR_RED_ON_BLACK dq 4

;*********************************
;*** Handover variable storage ***
;*********************************
EFI_HANDLE dq 0
EFI_SYSTEM_TABLE dq 0
EFI_RETURN dq 0

;******************************************
;*** User interface information strings ***
;******************************************
hello db __utf16__ `Welcome to Project Turtle!\r\n\0`
errorInfo db __utf16__ `If you have an error, it will look like this. Hopefully none of these will happen!\r\n\0`
goodbye db __utf16__ `See you next time!\r\n\0`

;Do the data segment section alignment!
times 512 - ($-$$) db 0 ;alignment
