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

;**************************************************************************************************
;*** locateHandlesByProtocol [BOOT FUNCTION ONLY]                                               ***
;*** Definition: provides a list and count of every handle that supports the requested protocol ***
;*** Input: rcx is the address of the protocol GUID                                             ***
;*** Output: rcx holds address to the buffer containing the array of handles found              ***
;***         rdx holds the number of handles with that protocol                                 ***
;**************************************************************************************************
locateHandlesByProtocol:
	;Save registers
	push r8
	push r9
	push r10
	push r11
	
	;Call the function
	mov rdx, rcx
	mov rcx, [LOCATE_PROTOCOL_SEARCH_PROTOCOL]
	mov r8, 0 ;null
	mov r9, LOCATE_PROTOCOL_HANDLE_COUNT
	mov r10, LOCATE_PROTOCOL_BUFFER_ADDRESS
	push r10
	sub rsp, 0x20
	call [BOOT_SERVICES_LOCATE_HANDLE_BUFFER]

	;Restore registers
	add rsp, 0x20
	pop r10
	pop r11
	pop r10
	pop r9
	pop r8
	
	;Prepare return values and return
	mov rcx, [LOCATE_PROTOCOL_BUFFER_ADDRESS]
	mov rdx, [LOCATE_PROTOCOL_HANDLE_COUNT]
	ret

;***************************************************************************
;*** freeBuffer [BOOT FUNCTION ONLY]                                     ***
;*** Definition: Frees all of the memory allocated from the buffer given ***
;*** Input: rcx = pointer to buffer in memory                            ***
;*** Output: None                                                        ***
;***************************************************************************
freeBuffer:
	;Save registers
	push rcx
	push rdx
	push r8
	push r9
	push r10
	push r11
	
	;Call the function
	sub rsp, 0x28
	call [BOOT_SERVICES_FREE_POOL]

	;Restore registers
	add rsp, 0x28
	pop r11
	pop r10
	pop r9
	pop r8
	pop rdx
	pop rcx
	ret

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
OFFSET_BOOT_STALL dq 248
BOOT_SERVICES_STALL dq 0
			
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
EFI_MEDIA_CHANGED dq 0x800000000000000d
EFI_NOT_FOUND dq 0x800000000000000e
EFI_ACCESS_DENIED dq 0x800000000000000f
EFI_INCOMPATIBLE_VERSION dq 0x8000000000000019 ;used in this application to represent unknown errors!
EFI_SECURITY_VIOLATION dq 0x8000000000000001a

;***************************************
;*** Stores addresses for calls      ***
;*** related to the EFI system table ***
;***************************************
BOOT_SERVICES_FREE_POOL dq 0
BOOT_SERVICES_LOCATE_HANDLE_BUFFER dq 0

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
LOCATE_PROTOCOL_SEARCH_PROTOCOL dw 2
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
