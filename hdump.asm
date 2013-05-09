;;; name: hexdump2                                             -*- asm -*-
;;; description: a simple hex dump utility that prints hexadecimal
;;; characters and their ASCII representations, when they exist
;;; build it like so:
;;; 	nasm -f elf{32,64} -g -F dwarf hexdump2.asm
;;; 	ld -o hexdump2 hexdump2.asm

SECTION .bss			; uninitialized data

	BUFFLEN equ 10
	Buff resb BUFFLEN

SECTION .data			; initialized data

	;; This data structure implements the text line. 16 bytes in
	;; hex are separated by spaces, followed by a 16-character
	;; line delimited by vertical bar chars.

	DumpLin: db " 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 "
	DUMPLEN equ $-DumpLin
	ASCLin:	 db " ................ ", 10
	ASCLEN equ $-ASCLin
	FULLLEN equ $-DumpLin

	;; The 'HexDigits' table is used to convert numeric values to
	;; their hex equivalents. Index by nybble without a scale:
	;; [HexDigits + eax]
	HexDigits: db "0123456789ABCDEF"

	;; This table is used to create the ASCII character
	;; display. We can use 'xlat' or ordinary memory lookup. The
	;; high 128 (nonprintable) characters of ASCII are translated
	;; as ASCII period (2EH). The non-printable characters in the
	;; low 128 are also displayed as periods, as is char 127.
	DotXlat:
	db 2EH, 2EH, 2EH, 2EH, 2EH, 2EH, 2EH, 2EH, 2EH, 2EH, 2EH, 2EH, 2EH, 2EH, 2EH, 2EH
	db 2EH, 2EH, 2EH, 2EH, 2EH, 2EH, 2EH, 2EH, 2EH, 2EH, 2EH, 2EH, 2EH, 2EH, 2EH, 2EH
	db 20H, 21H, 22H, 23H, 24H, 25H, 26H, 27H, 28H, 29H, 2AH, 2BH, 2CH, 2DH, 2EH, 2FH
	db 30H, 31H, 32H, 33H, 34H, 35H, 36H, 37H, 38H, 39H, 3AH, 3BH, 3CH, 3DH, 3EH, 3FH
	db 40H, 41H, 42H, 43H, 44H, 45H, 46H, 47H, 48H, 49H, 4AH, 4BH, 4CH, 4DH, 4EH, 4FH
	db 50H, 51H, 52H, 53H, 54H, 55H, 56H, 57H, 58H, 59H, 5AH, 5BH, 5CH, 5DH, 5EH, 5FH
	db 60H, 61H, 62H, 63H, 64H, 65H, 66H, 67H, 68H, 69H, 6AH, 6BH, 6CH, 6DH, 6EH, 6FH
	db 70H, 71H, 72H, 73H, 74H, 75H, 76H, 77H, 78H, 79H, 7AH, 7BH, 7CH, 7DH, 7EH, 2FH

	db 2EH, 2EH, 2EH, 2EH, 2EH, 2EH, 2EH, 2EH, 2EH, 2EH, 2EH, 2EH, 2EH, 2EH, 2EH, 2EH
	db 2EH, 2EH, 2EH, 2EH, 2EH, 2EH, 2EH, 2EH, 2EH, 2EH, 2EH, 2EH, 2EH, 2EH, 2EH, 2EH
	db 2EH, 2EH, 2EH, 2EH, 2EH, 2EH, 2EH, 2EH, 2EH, 2EH, 2EH, 2EH, 2EH, 2EH, 2EH, 2EH
	db 2EH, 2EH, 2EH, 2EH, 2EH, 2EH, 2EH, 2EH, 2EH, 2EH, 2EH, 2EH, 2EH, 2EH, 2EH, 2EH
	db 2EH, 2EH, 2EH, 2EH, 2EH, 2EH, 2EH, 2EH, 2EH, 2EH, 2EH, 2EH, 2EH, 2EH, 2EH, 2EH
	db 2EH, 2EH, 2EH, 2EH, 2EH, 2EH, 2EH, 2EH, 2EH, 2EH, 2EH, 2EH, 2EH, 2EH, 2EH, 2EH
	db 2EH, 2EH, 2EH, 2EH, 2EH, 2EH, 2EH, 2EH, 2EH, 2EH, 2EH, 2EH, 2EH, 2EH, 2EH, 2EH
	db 2EH, 2EH, 2EH, 2EH, 2EH, 2EH, 2EH, 2EH, 2EH, 2EH, 2EH, 2EH, 2EH, 2EH, 2EH, 2EH
	
SECTION .text 			; Section containing program code

;;; ClearLine (proc): Clear a hex dump line to 16 0 values
;;; input: n/a
;;; output: n/a
;;; modifies: n/a
;;; calls: `DumpChar'
;;; description: the hex dump line string is cleared by calling
;;; `DumpChar' 16 times, passing it 0 each time

ClearLine:
	push edx		; save caller's gp registers
	push eax
	
	mov edx, 15		; we're clearing 16 chars
.poke: mov eax, 0		; tell `DumpChar' to insert a 0
	call DumpChar		; insert 0 into the hex string
	sub edx, 1		; decrement the line pointer (we'd use
				; `dec', but it doesn't affect `cf'
	jae .poke		; loop back if the line pointer `edx'
				; >= 0
	pop eax			; restore caller's eegisters
	pop edx
	ret

;;; DumpChar (proc): insert a value into the hex dump line string
;;; input: 8-bit char value to be inserted (pass via `eax')
;;; output: n/a
;;; modifies: `eax', `ASCLin', `DumpLin'
;;; calls: n/a
;;; description: value passed in `eax' will be inserted into both the
;;; hex dump and ascii portions at the offset (string pointer) in
;;; `edx'. when the value is not printable, it will be represented in
;;; the ascii version by a period (`.').

DumpChar:
	push ebx		; save caller's `ebx'
	push edi		; save caller's `edi'
	;; first insert the input character into the ascii portion of
	;; the line
	mov bl, byte [DotXlat + eax] ; translate non-printables to `.'
	mov byte [ASCLin + edx + 1], bl ; write to ascii portion
	;; next insert the hex equiv. of char in hex portion of line
	mov ebx, eax		; get 2nd copy of char for upper/lower
				; nybble extraction
	lea edi, [edx * 2 + edx] ; calculate the offset into the
				; string (`edx' * 3)
	;; look up low nybble char and insert into hex portion
	and eax, 0FH 		; mask out all but low nybble
	mov al, byte [HexDigits + eax] ; look up char equiv of nybble
	mov byte [DumpLin + edi + 2], al ; write looked-up char equiv
				; to hex portion of line string
	;; look up high nybble char and insert into hex portion
	and ebx, 0F0H 		; mask all but high nybble
	shr ebx, 4		; shift high nybble to low nybble
	mov bl, byte [HexDigits + ebx] ; look up char equiv of nybble
	mov byte [DumpLin + edi + 1], bl ; write val from char lookup
				; to hex portion of line string
	;; end the procedure: restore caller's registers and return
	pop edi
	pop ebx
	ret

;;; PrintLine (proc): display `DumpLin' to stdout
;;; input: n/a
;;; output: n/a
;;; modifies: n/a
;;; calls: sys_write system call

PrintLine:
	push edx			; save caller's registers
	push ecx
	push ebx
	push eax
	
	mov eax, 4		; ask for sys_write system call
	mov ebx, 1		; ask for file descriptor 1 (stdout)
	mov ecx, DumpLin	; pass  location of line string
	mov edx, FULLLEN	; pass length of line string
	int 80h			; invoke the gods...

	pop eax			; return caller's register values
	pop ebx
	pop ecx
	pop edx
	ret


;;; LoadBuff: fill a buffer from stdin
;;; input: n/a
;;; output: number of bytes read from stdin in `ebp'
;;; modifies: `ecx', `ebp', `Buff'
;;; calls: sys_write

LoadBuff:
	push eax		; save caller's registers
	push ebx
	push edx
	mov eax, 3		; ask for sys_read system call
	mov ebx, 0 		; ask for file descriptor 0, system
				; input
	mov ecx, Buff		; pass location of the buffer
	mov edx, BUFFLEN	; pass # of bytes to read in one pass
	int 80h			; call sys_read
	mov ebp, eax		; save # of bytes read from file (for
				; later)
	xor ecx, ecx		; clear buffer pointer to 0
	pop edx			; restore caller's registers
	pop ebx
	pop eax
	ret

GLOBAL _start

_start:
	nop			; these stop gdb
	nop

	;; whatever intitialization needs doing before the loop scan
	;; starts is here:
	xor esi, esi 		; clear the total byte counter to 0
	call LoadBuff		; read first buffer of data from stdin
	cmp ebp, 0		; if this is 0, sys_read reached eof
				; on stdin
	jbe Exit		; if we've reached eof, quit the program

	;; go through the buffer and convert binary byte values to hex digits
Scan:
	xor eax, eax
	mov al, byte [Buff + ecx] ; load a byte from the buffer
	mov edx, esi		  ; copy total bytes read counter into `edx'
	and edx, 0FH		  ; mask lowest 4 bits of the counter
	call DumpChar		  ; call the `char-insert' procedure

	;; bump the buffer pointer to the next char and see if
	;; buffer's done

	inc esi			; increment total chars processed
				; counter
	inc ecx 		; incf buffer pointer
	cmp ecx, ebp		; compare pointer w/# of chars in
				; buffer
	jb .modTest		; if we've processed all chars in
				; buffer...
	call LoadBuff		; ...go fill buffer again
	cmp ebp, 0		; `LoadBuff' called `sys_read'; if
				; `ebp' == 0, `sys_read' reached EOF
				; on stdin
	jbe Done		; if we did read EOF, we're done

	;; see if we're at the end of a block of 16 and need to
	;; display a line
.modTest:
	test esi, 0FH		; test 4 lowest bits in counter for 0
	jnz Scan		; if counter is not modulo 16, loop
				; back
	call PrintLine		; otherwise, print the line
	call ClearLine		; clear hex dump line to 0's
	jmp Scan		; continue scanning the buffer

	;; all done, let's go home
Done:
	call PrintLine		; print the "leftovers" line

Exit:	
	mov eax, 1		; ask for `exit' syscall
	mov ebx, 0		; ...with a return value of 0
	int 80h			; invoke the gods...
