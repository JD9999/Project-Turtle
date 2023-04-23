			;**********************************
			;******** EXTRA FUNCTIONS *********
			;*** Some functions that I have ***
			;*** previously written but     ***
			;*** haven't made it into the   ***
			;*** kernel (yet)               ***
			;**********************************
			
	;**********************************
	;******* REMOVED FUNCTIONS ********
	;*** Not needed at the moment.  ***
	;**********************************

;*******************************************************
;*** loadDriver [BOOT FUNCTION ONLY]                 ***
;*** Definition: Load an EFI boot driver from a file ***
;*** Input: rcx is the device path                   ***
;*** Output: rcx is the EFI handle                   ***
;*******************************************************
loadDriver:
	;Call the function
	push rcx
	push rdx
	push r8
	push r9
	push r10
	push r11
	mov r8, rcx
	mov rcx, 0
	mov rdx, [EFI_HANDLE]
	mov r9, 0
	sub rsp, 0x28
	call [BOOT_SERVICES_LOAD_IMAGE]

	;Check for errors
	cmp rax, [EFI_SUCCESS]
	je LDend
	
	cmp rax, [EFI_LOAD_ERROR]
	jne LD1
	mov rcx, loadError
	jmp LDerrExit

	LD1:
	cmp rax, [EFI_INVALID_PARAMETER]
	jne LD2
	mov rcx, invalidParameterError
	jmp LDerrExit
	
	LD2:
	cmp rax, [EFI_UNSUPPORTED]
	jne LD3
	mov rcx, unsupportedError
	jmp LDerrExit
	
	

	LD8:
	;Unknown error, let's just end the program here...
	mov rcx, unknownError
	jmp LDerrExit
	
	LDerr:
	call printString

	;Return
	LDend:
	add rsp, 0x28
	pop r11
	pop r10
	pop r9
	pop r8
	pop rdx
	pop rcx
	ret

	LDerrExit:
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

	;**********************************
	;******* INSECURE FUNCTIONS *******
	;*** Must be re-written before  ***
	;*** being added into the       ***
	;*** kernel since it does not   ***
	;*** save registers             ***
	;**********************************

;***********************************************************************************
;*** iterateBuffer                                                               ***
;*** Definition: calls a function with each element in the buffer as an argument ***
;***             rcx will contain the integer argument (usually a pointer)       ***
;*** Input: rcx is the amount of elements in the pointer                         ***
;***        rdx is the address of the buffer                                     ***
;***        r8 is the address of the function to call                            ***
;*** Output: none                                                                ***
;***********************************************************************************
iterateBuffer:
	mov r9, 0

	IBloop:
	cmp r9, rcx
	je IBend

	mov r10, rdx
	sub rsp, 0x28	
	push r9
	push r8
	push rdx
	push rcx

	mov rax, 8
	mul r9
	add r10, rax

	mov rcx, [r10]
	call r8

	pop rcx
	pop rdx
	pop r8
	pop r9	
	add rsp, 0x28

	inc r9
	jmp IBloop

	IBend:
	ret
	
;************************************************************************
;*** clearConsoleIfMatch [BOOT FUNCTION ONLY]                         ***
;*** Definition: If the handle's SIMPLE_TEXT_OUTPUT_PROTOCOL is equal ***
;***             to either the output console or the error console    ***
;***             protocols, the output/error console is set to 0      *** 
;*** Input: rcx = the handle                                          ***
;*** Output: None                                                     ***
;************************************************************************
clearConsoleIfMatch:
	sub rsp, 0x28
	call consoleOutputProtocolFromHandle
	cmp rcx, [CONOUT]
	jne CCIMtestErr
	call printNumber
	lea rdx, [debug1]
	call printString
	;mov qword [CONOUT], 0
	CCIMtestErr:
	cmp rcx, [CONERR]
	jne CCIMret
	lea rdx, [debug2]
	call printString
	;mov qword [CONERR], 0
	CCIMret:
	add rsp, 0x28
	ret

;************************************************************************
;*** openConsoleIfMatch [BOOT FUNCTION ONLY]                         ***
;*** Definition: If the handle's SIMPLE_TEXT_OUTPUT_PROTOCOL is equal ***
;***             to either the output console or the error console    ***
;***             protocols, the output/error console is checked to    ***
;***             see if it is opened or not.                          ***
;*** Input: rcx = the handle                                          ***
;*** Output: None                                                     ***
;************************************************************************
openConsoleIfMatch:
	mov [HANDLE_STORE], rcx
	sub rsp, 0x28
	call consoleOutputProtocolFromHandle
	;add rsp, 0x28

	cmp rcx, [CONOUT]
	je OCIMcheckOpen

	OCIMtestErr:
	cmp rcx, [CONERR]
	je OCIMcheckOpen

	jmp OCIMret

	OCIMcheckOpen:
	mov rcx, [HANDLE_STORE]
	mov rdx, GUID_EFI_SIMPLE_TEXT_OUTPUT_PROTOCOL
	mov r8, OPEN_PROTOCOL_INFORMATION_BUFFER_ADDRESS
	mov r9, OPEN_PROTOCOL_INFORMATION_BUFFER_COUNT
	;sub rsp, 0x28
	call [BOOT_SERVICES_OPEN_PROTOCOL_INFORMATION]
	
	;Check for errors
	cmp rax, [EFI_SUCCESS]
	jne OCIM0
	mov rcx, [OPEN_PROTOCOL_INFORMATION_BUFFER_COUNT]
	mov rdx, [OPEN_PROTOCOL_INFORMATION_BUFFER_ADDRESS]
	mov r8, printlnNumber
	call iterateBuffer
	jmp OCIMret

	OCIM0:
	cmp rax, [EFI_NOT_FOUND]
	jne OCIM1
	call _notFoundError
	;call _notFoundErrorAndExit
	jmp OCIMret ;Don't think code is called after this, but just in case...

	OCIM1:
	cmp rax, [EFI_OUT_OF_RESOURCES]
	jne OCIM2
	call _outOfResourcesErrorAndExit
	jmp OCIMret ;Don't think code is called after this, but just in case...

	OCIM2:
	;Unknown error, let's just end the program here...
	call _unknownErrorAndExit
	jmp OCIMret ;Don't think code is called after this, but just in case...	

	OCIMret:
	add rsp, 0x28
	ret

;**************************************************************************
;*** consoleOutputProtocolFromHandle [BOOT FUNCTION ONLY]               ***
;*** Definition: Look up the address of the SIMPLE_TEXT_OUTPUT_PROTOCOL ***
;***             protocol in a registered handler                       ***
;*** Input: rcx = the handle                                            ***
;*** Output: rcx = a pointer to the protocol interface                  ***
;**************************************************************************
consoleOutputProtocolFromHandle:
	sub rsp, 0x28
	mov rdx, GUID_EFI_SIMPLE_TEXT_OUTPUT_PROTOCOL
	call protocolFromHandle
	mov rcx, [HANDLE_PROTOCOL_POINTER_ADDRESS]
	add rsp, 0x28
	ret

;*******************************************************
;*** protocolFromHandle [BOOT FUNCTION ONLY]         ***
;*** Definition: Look up the address of a particular ***
;***             protocol in a registered handler    ***
;*** Input: rcx = the handle                         ***
;***        rdx = the protocol type to search for    ***
;*** Output: None                                    ***
;*******************************************************
protocolFromHandle:
	;Call the function
	sub rsp, 0x28
	mov r8, HANDLE_PROTOCOL_POINTER_ADDRESS
	call [BOOT_SERVICES_HANDLE_PROTOCOL]

	;Check for errors
	cmp rax, [EFI_SUCCESS]
	je PFHend

	cmp rax, [EFI_INVALID_PARAMETER]
	jne PFH1
	call _invalidParameterErrorAndExit
	jmp PFHend ;Don't think code is called after this, but just in case...

	PFH1:
	;Unknown error, let's just end the program here...
	call _unknownErrorAndExit
	jmp PFHend ;Don't think code is called after this, but just in case...	

	;Return
	PFHend:
	add rsp, 0x28
	ret
	
;****************************************************************
;*** _unknownGlyphError (EFI_WARNING_UNKNOWN_GLYPH)           ***
;*** Prints the unknownGlyphError string to the error console ***
;****************************************************************
_unknownGlyphError:
	sub rsp, 0x28
	lea rdx, [unknownGlyphError]
	call printErrorString
	add rsp, 0x28
	ret

;********************************************************************
;*** _invalidParameterError (EFI_INVALID_PARAMETER)               ***
;*** Prints the invalidParameterError string to the error console ***
;********************************************************************
_invalidParameterError:
	sub rsp, 0x28
	lea rdx, [invalidParameterError]
	call printErrorString
	add rsp, 0x28
	ret

;********************************************************************
;*** _invalidParameterErrorAndExit (EFI_INVALID_PARAMETER)        ***
;*** Prints the invalidParameterError string to the error console ***
;*** Also exits the program                                       ***
;********************************************************************
_invalidParameterErrorAndExit:
	sub rsp, 0x28
	lea rdx, [invalidParameterError]
	call printErrorString
	mov rcx, [waitTime]
	call waitForTime
	mov rdx, [EFI_INVALID_PARAMETER]
	call exit
	add rsp, 0x28
	ret

;***************************************************************
;*** _unsupportedErrorAndExit (EFI_UNSUPPORTED)              ***
;*** Prints the unsupportedError string to the error console ***
;*** Also exits the program                                  ***
;***************************************************************
_unsupportedErrorAndExit:
	sub rsp, 0x28
	lea rdx, [unsupportedError]
	call printErrorString
	mov rcx, [waitTime]
	call waitForTime
	mov rdx, [EFI_UNSUPPORTED]
	call exit
	add rsp, 0x28
	ret

;**********************************************************
;*** _deviceErrorAndExit (EFI_DEVICE_ERROR)             ***
;*** Prints the deviceError string to the error console ***
;*** Also exits the program                             ***
;**********************************************************
_deviceErrorAndExit:
	sub rsp, 0x28
	lea rdx, [deviceError]
	call printErrorString
	mov rcx, [waitTime]
	call waitForTime
	mov rdx, [EFI_DEVICE_ERROR]
	call exit
	add rsp, 0x28
	ret

;******************************************************************
;*** _outOfResourcesErrorAndExit (EFI_OUT_OF_RESOURCES)         ***
;*** Prints the outOfResourcesError string to the error console ***
;*** Also exits the program                                     ***
;******************************************************************
_outOfResourcesErrorAndExit:
	sub rsp, 0x28
	lea rdx, [outOfResourcesError]
	call printErrorString
	mov rcx, [waitTime]
	call waitForTime
	mov rdx, [EFI_OUT_OF_RESOURCES]
	call exit
	add rsp, 0x28
	ret

;************************************************************
;*** _notFoundError (EFI_NOT_FOUND)                       ***
;*** Prints the notFoundError string to the error console ***
;************************************************************
_notFoundError:
	sub rsp, 0x28
	lea rdx, [notFoundError]
	call printErrorString
	add rsp, 0x28
	ret

;************************************************************
;*** notFoundErrorAndExit (EFI_NOT_FOUND)                 ***
;*** Prints the notFoundError string to the error console ***
;*** Also exits the program                               ***
;************************************************************
_notFoundErrorAndExit:
	sub rsp, 0x28
	lea rdx, [notFoundError]
	call printErrorString
	mov rcx, [waitTime]
	call waitForTime
	mov rdx, [EFI_NOT_FOUND]
	call exit
	add rsp, 0x28
	ret

;***********************************************************
;*** _unknownErrorAndExit (EFI_INCOMPATIBLE_VERSION)     ***
;*** Prints the unknownError string to the error console ***
;*** Also exits the program                              ***
;***                                                     ***
;*** Since the UEFI specifications have no return code   ***
;*** for an unknown error, this could only result from a ***
;*** dodgy UEFI implementation, which is why             ***
;*** EFI_INCOMPATIBLE_VERSION is the return code.        ***
;***********************************************************
_unknownErrorAndExit:
	sub rsp, 0x28
	lea rdx, [unknownError]
	call printErrorString
	mov rcx, [waitTime]
	call waitForTime
	mov rdx, [EFI_INCOMPATIBLE_VERSION] ;There's no unknown error in the UEFI spec,
					    ;this is not used anywhere else in the application,
					    ;and may be the root cause of this issue.
	call exit
	add rsp, 0x28
	ret
	
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
	
;*****************************************************************************
;*** openFileSystem                                                        *** ;TODO This function does not work yet, don't use it!
;*** Definition: opens a file system for various operations                ***
;*** Input: rcx is a pointer to a EFI_SYSTEM_FILE_SYSTEM_PROTOCOL object   ***
;*** Output: rcx is a pointer to an EFI_FILE_PROTOCOL for that file system ***
;*****************************************************************************
openFileSystem:
	;Call the function
	push rdx
	push r8
	push r9
	push r10
	push r11

	mov r8, rcx
	mov rdx, OPEN_VOLUME_FILE_PROTOCOL_HANDLE_ADDRESS
	add r8, [OFFSET_SIMPLE_FILE_SYSTEM_OPEN_VOLUME]
	sub rsp, 0x20
	call [r8]

	;Check for errors
	cmp rax, [EFI_SUCCESS]
	je OFSend

	cmp rax, [EFI_UNSUPPORTED]
	jne OFS1
	mov rcx, unsupportedError
	jmp OFSerrExit

	OFS1:
	cmp rax, [EFI_NO_MEDIA]
	jne OFS2
	mov rcx, noMediaError
	jmp OFSerr

	OFS2:
	cmp rax, [EFI_DEVICE_ERROR]
	jne OFS3
	mov rcx, deviceError
	jmp OFSerr

	OFS3:
	cmp rax, [EFI_VOLUME_CORRUPTED]
	jne OFS4
	mov rcx, volumeCorruptedError
	jmp OFSerr

	OFS4:
	cmp rax, [EFI_ACCESS_DENIED]
	jne OFS5
	mov rcx, accessDeniedError
	jmp OFSerr

	OFS5:
	cmp rax, [EFI_OUT_OF_RESOURCES]
	jne OFS2
	mov rcx, outOfResourcesError
	jmp OFSerrExit

	OFS6:
	cmp rax, [EFI_MEDIA_CHANGED]
	jne OFS7
	mov rcx, mediaChangedError
	jmp OFSerr

	OFS7:
	;Unknown error, let's just end the program here...
	mov rcx, unknownError
	jmp OFSerrExit

	OFSerr:
	call printErrorString

	;Return
	OFSend:
	add rsp, 0x20
	mov rcx, [OPEN_VOLUME_FILE_PROTOCOL_HANDLE_ADDRESS]
	pop r11
	pop r10
	pop r9
	pop r8
	pop rdx
	ret

	OFSerrExit:
	call printErrorString
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
	
			;**********************************
			;******** EXTRA VARIABLES *********
			;*** Some variables that I have ***
			;*** previously written but     ***
			;*** haven't made it into the   ***
			;*** kernel (yet)               ***
			;**********************************

;*************************************
;*** The full list of system table ***
;*** offsets used in this program  ***
;*************************************
OFFSET_BOOT_FREE_POOL dq 72
OFFSET_BOOT_LOCATE_HANDLE_BUFFER dq 312
OFFSET_SIMPLE_FILE_SYSTEM_OPEN_VOLUME dq 8

;************************
;*** Number constants ***
;************************
maxDivide dq 1000000000000000000 ;highest 64-bit divide
base10 dq 10 ;Dividing by 10 gets a base 10 digit
			
;*****************************************
;*** The full list of EFI function     ***
;*** return codes used in this program ***
;*****************************************
EFI_SUCCESS dq 0
EFI_WARNING_UNKNOWN_GLYPH dq 1
EFI_LOAD_ERROR dq 0x8000000000000001
EFI_INVALID_PARAMETER dq 0x8000000000000002
EFI_UNSUPPORTED dq 0x8000000000000003
EFI_DEVICE_ERROR dq 0x8000000000000007
EFI_OUT_OF_RESOURCES dq 0x8000000000000009
EFI_VOLUME_CORRUPTED dq 0x800000000000000a
EFI_NO_MEDIA dq 0x800000000000000c
EFI_MEDIA_CHANGED dq 0x800000000000000d ;Obviously one of these two is wrong!
EFI_NOT_FOUND dq 0x800000000000000d ;Obviously one of these two is wrong!
EFI_ACCESS_DENIED dq 0x800000000000000e
EFI_INCOMPATIBLE_VERSION dq 0x8000000000000019 ;used in this application to represent unknown errors!
EFI_SECURITY_VIOLATION dq 0x8000000000000001a

;***************************************
;*** Stores addresses for calls      ***
;*** related to the EFI system table ***
;***************************************
BOOT_SERVICES_FREE_POOL dq 0
BOOT_SERVICES_LOCATE_HANDLE_BUFFER dq 0
CONERR_PRINT_STRING dq 0
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
GUID_EFI_EBC_PROTOCOL			dd 0x13AC6DD1
					dw 0x73D0, 0x11D4
					db 0xB0, 0x6B, 0x00, 0xAA, 0x00, 0xBD, 0x6D, 0xE7
					
;****************************************
;*** Stores values related to the     ***
;*** UEFI LocateHandleBuffer function ***
;****************************************
LOCATE_PROTOCOL_SEARCH_PROTOCOL dq 2
LOCATE_PROTOCOL_HANDLE_COUNT dq 0
LOCATE_PROTOCOL_BUFFER_ADDRESS dq 0

;**********************************************
;*** Stores values related to the UEFI      ***
;*** Simple File System openVolume function ***
;**********************************************
OPEN_VOLUME_FILE_PROTOCOL_HANDLE_ADDRESS dq 0

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
info db __utf16__ `Welcome! This is the output console!\r\n\0`
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
volumeCorruptedError db __utf16__ `Volume is corrupted!\r\n\0`
noMediaError db __utf16__ `Media does not exist!\r\n\0`
mediaChangedError db __utf16__ `Media has been changed!\r\n\0`
notFoundError db __utf16__ `Result not found!\r\n\0`
accessDeniedError db __utf16__ `Access denied!\r\n\0`
unknownError db __utf16__ `An unknown error occurred!\r\n\0`

necessaryProtocolMissingError db __utf16__ `A protocol necessary for the operation of Project Turtle is missing!`