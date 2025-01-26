org 0x7C00
bits 16

%define ENDL 0x0D, 0x0A

start:
	jmp main

; Prints a string to the screen
; Params:
;	- ds:si points to a string
puts:
	; save registers to be modified
	push si
	push ax
.loop:
	lodsb		; loads the next char into al
	or al, al	; check if the char is null
	jz .done	; if null go to .done

	mov ah, 0x0e	; call bios interrupt
	mov bh, 0x00
	int 0x10
	jmp .loop
.done:
	pop ax
	pop si
	ret

main:
	; setup data segments
	mov ax, 0
	mov ds, ax
	mov es, ax

	; setup stack
	mov ss, ax
	mov sp, 0x7C00

	; print message
	mov si, message
	call puts
	
	hlt
.halt:
	jmp .halt


message: db 'DuckOs', ENDL, 0


times 510-($-$$) db 0
dw 0AA55h
