;Author:Mateusz Bieda
;PURPOSE:  use BUFFERED I/O with permissions, proper checks for return statements, 
;         and learns about the circular buffer all the proper words that match up are then written to a file 
;         called results.txt 

section .data
	; system commands
	SYSTEM_OPEN equ 2
	SYSTEM_CLOSE equ 3
	SYSTEM_EXIT equ 60
	SYSTEM_READ equ 0
	SYSTEM_WRITE equ 1
	SYSTEM_CREATE equ 85

	; special files, for input and output 
	STANDARD_IN equ 0
	STANDARD_OUT equ 1
	
	; just for the end program
	SUCCESS  equ 0

	NULL equ 0
	LINEFEED equ 10
	carriage equ 13
	
	; this limits the string length
	stringInputMaxLength equ 20
	MAIN_BUFFER_SIZE equ 1
	
	; Messages for the files and error messages for the input for arguments 
	
	errorIncorrectArguments db "Enter the filename and then the word to search for after ./a.out.", LINEFEED, NULL
	errorOpeningFile db "Failed to open input file.", LINEFEED, NULL
	errorReadingFile db "Error, failed to read file.", LINEFEED, NULL
	errorStringLength db "Input string must be between 1 and 20 characters long.", LINEFEED, NULL
	errorMakingFile db "Failed to create out going file.", LINEFEED, NULL
	
	RESULT_FILE db "results.txt", NULL
	stringPlacement db "Line: 0x00000000 Column: 0x00000000", LINEFEED, NULL
	
	; all these variables have unique uses 
	linePositionPlace equ 6
	columnPositionPlace equ 25
	; used for saving the results and the input book 
	fileDescriptorIn dd 0
	fileDescriptorOut dd 0

	charactersFromBuffersBuffered dd 0
	charactersFromBuffersRead dd 0

	circularIndex dd 0
	
	lineCount dd 1
	columnCount dd 0
	
	endOfFileReached db 0

	charactersFromBuffersInLine db 0
	charactersFromBuffer db 1

	;permissions and accesses
	O_RDONLY equ 000000q
	O_WRONLY equ 000001q
	O_RDWR	equ 000002q
	S_IRUSR equ 00400q
	S_IWUSR equ 00200q

section .bss

	mainBuffer resb 1

	circularBuffer resb stringInputMaxLength
	CIRCULAR_BUFFER_SIZE resb 1

	fileName resb 100
	findInputString resb stringInputMaxLength

section .text
global main
main:
;IMPORTANT PERSONAL NOTE
; rdi = argc (argument count)
; rsi = argv (starting address of argument vector)

	;argument vector (table)
	mov r8, rsi	
	;argument count
	mov r13, rdi

	mov rax, 3					
	cmp rax, r13
	je passArgumentCount

		mov rdi, errorIncorrectArguments	
		call findLength
	
	mov rdx, rax
	mov rsi, rdi
	mov rax, SYSTEM_WRITE
	mov rdi, STANDARD_OUT
	syscall
	; this here is to show and prove that the program is functioning 
	mov rax, SYSTEM_EXIT
	mov rdi, SUCCESS
	syscall
	passArgumentCount:
	; here we have this so that we take from the argumennt vector and 
	; the text file is obtained and stored properly 
		mov rdi, r8
		mov rsi, 1		
		mov rdx, fileName
		call argumentTableGrab
	
		mov rdi, r8
		mov rsi, 2	
		mov rdx, findInputString
		call argumentTableGrab
		; the same happens with getting the argument vector third value and
		;storing it in findINputString
	mov rdi, findInputString
	call findLength
	dec rax 
	cmp rax, stringInputMaxLength
	jle passableStringLength
	; this here finds the length of the input string that will be used to 
	; create the limit for the circular buffer
		mov rdi, errorStringLength
		call findLength
	
	mov rdx, rax
	mov rsi, rdi
	mov rax, SYSTEM_WRITE
	mov rdi, STANDARD_OUT
	syscall
	
	mov rax, SYSTEM_EXIT
	mov rdi, SUCCESS
	syscall
	
	passableStringLength:
	mov byte[CIRCULAR_BUFFER_SIZE], al		
	
	mov rax, SYSTEM_CREATE
	mov rdi, RESULT_FILE
	mov rsi, S_IRUSR | S_IWUSR
	syscall
	; with the proper permissions and commands
 ; the result file is made and we have the descirptor to it
	cmp rax, 0
	jge fileMade
	
		mov rdi, errorMakingFile
		call findLength
	
	mov rdx, rax
	mov rsi, rdi
	mov rax, SYSTEM_WRITE
	mov rdi, STANDARD_OUT
	syscall
	
	mov rax, SYSTEM_EXIT
	mov rdi, SUCCESS
	syscall
	
	fileMade:
	mov dword[fileDescriptorOut], eax	

	mov rax, SYSTEM_OPEN
	mov rdi, fileName
	mov rsi, O_RDONLY
	syscall
	
	cmp rax, 0		
	jge successfulFileOpen
	
		mov rdi, errorOpeningFile
		call findLength
	
	mov rdx, rax
	mov rsi, rdi
	mov rax, SYSTEM_WRITE
	mov rdi, STANDARD_OUT
	syscall
	
	mov rax, SYSTEM_EXIT
	mov rdi, SUCCESS
	syscall
	
	successfulFileOpen:
	mov dword[fileDescriptorIn], eax	

readInMoreData:
		mov rdi, mainBuffer
		mov rsi, charactersFromBuffer
		call getChar			
	
	cmp rax, 0				
	je fileReadAndSearchFinished
	
	mov eax, dword[circularIndex]
	mov rbx, 0
	mov bl, byte[CIRCULAR_BUFFER_SIZE]
	cqo
	div rbx															
	mov dword[circularIndex], edx 		
	; the code above calculates the adjusted index for the circular buffer and manages the storeage of 
	; the charactersFromBuffers below 
	mov rax, circularBuffer
	mov rcx, 0
	mov cl, byte[charactersFromBuffer]
	mov ebx, dword[circularIndex]
	mov byte[rax + rbx], cl			
	
	; this here compares if there is an end line line found, dependent on system of course
	cmp byte[charactersFromBuffer], carriage	
	je readInMoreData
	
	cmp byte[charactersFromBuffer], LINEFEED						
	jne noNewLineNeeded
	
	inc dword[lineCount]
	mov dword[columnCount], 0
	jmp findInCircularBuffer
	
	noNewLineNeeded:
	inc dword[columnCount]

	findInCircularBuffer:
	mov rdi, circularBuffer
	mov rsi, findInputString
	
	mov r14b, byte[CIRCULAR_BUFFER_SIZE]	
	mov rbx, 0			
	mov ecx, dword[circularIndex]		
	add ecx, 1		
	mov rax, rcx
	cqo
	div r14
	mov rcx, rdx 
	
	searchLoop:
		mov al, byte[rsi+ rbx]			
		mov r15b, byte[rdi + rcx]	
		
		cmp al, r15b
		jne endSearch
		
		charactersFromBuffersMatch:
		inc byte[charactersFromBuffersInLine] 
		cmp byte[charactersFromBuffersInLine], r14b 
		je identicalCharactersFound
		
		inc rbx									
		inc rcx	
		mov rax, rcx
		cqo
		div r14
		mov rcx, rdx		
		jmp searchLoop
		
		identicalCharactersFound:
			push rdi
			push rsi
			
				mov edi, dword[lineCount]
				mov rsi, stringPlacement
				add rsi, linePositionPlace
				call convertIntToHex
			
			mov edi, dword[columnCount]
			sub dil, byte[CIRCULAR_BUFFER_SIZE]		
			add dil, 1		
			
				mov rsi, stringPlacement
				add rsi, columnPositionPlace
				call convertIntToHex
			
			pop rsi
			pop rdi
			
					mov rdi, stringPlacement
					call findLength
				
					mov rdx, rax
					mov rax, SYSTEM_WRITE
					mov edi, dword[fileDescriptorOut]
					mov rsi, stringPlacement
					syscall
	
			
		endSearch:
		mov byte[charactersFromBuffersInLine], 0

	inc dword[circularIndex] 					
	
	jmp readInMoreData
		
endProgram:

fileReadAndSearchFinished:	

	mov rax, SYSTEM_CLOSE
	mov rdi, qword[fileDescriptorOut]
	syscall
	
	mov rax, SYSTEM_CLOSE
	mov rdi, qword[fileDescriptorIn]
	syscall

	mov rax, SYSTEM_EXIT
	mov rdi, SUCCESS
	syscall
	


global getChar
getChar:
	charLoop:
	; this here checks if charsRead is less than charsBuffered so that it will keep looping 
	; and storing the charactersFromBuffer into the from the main to the circular
		mov ebx, dword[charactersFromBuffersRead]
		cmp ebx, dword[charactersFromBuffersBuffered]			
		je doNotTake
		mov cl, byte[rdi + rbx]					
		mov byte[charactersFromBuffer], cl
		inc dword[charactersFromBuffersRead]		
		mov rax, 1									
		ret
	
	doNotTake:										
	cmp byte[endOfFileReached], 1		
	jne bufferInsertion
	mov rax, 0										
	ret
	
	bufferInsertion:
	push rdi
	push rsi
	
	mov edi, dword[fileDescriptorIn]
	mov rsi, mainBuffer
	mov rdx, MAIN_BUFFER_SIZE
	
	mov rax, SYSTEM_READ
	syscall	

	cmp rax, 0	
	jge infoReadInCorrecttly
	
		mov rdi, errorReadingFile
		call findLength
	
	mov rdx, rax
	mov rsi, rdi
	mov rax, SYSTEM_WRITE
	mov rdi, STANDARD_OUT
	syscall
	
	mov rax, SYSTEM_EXIT
	mov rdi, SUCCESS
	syscall
	
	infoReadInCorrecttly:
	mov qword[charactersFromBuffersBuffered], rax
	
	pop rsi
	pop rdi
	
	cmp rax, MAIN_BUFFER_SIZE					
	je endFileFalse
	mov byte[endOfFileReached], 1	
	jmp charLoop
	
	endFileFalse:
	mov dword[charactersFromBuffersBuffered], eax	
	mov dword[charactersFromBuffersRead], 0
	jmp charLoop
	
ret

global argumentTableGrab
argumentTableGrab:
	mov rax, qword[rdi + rsi * 8] 
	mov rbx, 0
	
	argumentPlacement:
		cmp byte[rax + rbx], NULL	
		je argumentPlacementFinished
		
		mov cl, byte[rax + rbx]
		mov byte[rdx + rbx], cl
		inc rbx
		loop argumentPlacement

	argumentPlacementFinished:
ret

global convertIntToHex
convertIntToHex:
; arg1 dword int
; arg2 string size 10 byte arr passing by reference
	push rbx
	; these are necessary values that have to be used for the ascii 
	; converting for characters
	mov r10, 16							
	mov r9, 48						
	mov r8, 55					
	mov rbx, 9						
	mov eax, edi						
	mov rdx, 0							
	convertToHex:
		cmp rbx, 1						
		je endConversion
		
		cdq								
		idiv r10d						
		cmp edx, 9				
		jg ontoAlphabet
			add edx, r9d				
			mov byte[rsi + rbx], dl		
			dec rbx
			jmp convertToHex
		ontoAlphabet:
			add edx, r8d				
			mov byte[rsi + rbx], dl		
			dec rbx
			jmp convertToHex
	endConversion:
	
	pop rbx
ret

global findLength
findLength:
; The code in here is from an example that has been provided in a previous assignment
	push rcx
	
	mov rax, 1
	countLettersLoop:
		mov cl, byte[rdi + rax - 1]
		cmp cl, NULL
		je countLettersDone
		
		inc rax
	loop countLettersLoop
	countLettersDone:
	
	pop rcx
	
ret
