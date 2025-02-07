org 0x7C00
bits 16

%define ENDL 0x0D, 0x0A

; FAT12 Header
jmp short start
nop

bdb_oem:					db 'MSWIN4.1'			; 8 bytes
bdb_bytes_per_sector:		dw 512
bdb_sectors_per_cluster:	db 1
bdb_reserved_sectors:		dw 1
bdb_fat_count:				db 2
bdb_dir_entries_count:		dw 0E0h
bdb_total_sectors:			dw 2880
bdb_media_descriptor_type:	db 0F0h
bdb_sectors_per_fat:		dw 9
bdb_sectors_per_track:		dw 18
bdb_heads:					dw 2
bdb_hidden_sectors:			dd 0
bdb_large_sector_count:		dd 0

; Extended Boot Record
ebr_drive_number:			db 0
							db 0 					; reserved
ebr_signature:				db 29h
ebr_volume:					db 04h, 20h, 08h, 04h	; serial number
ebr_volume_label:			db 'dtc  DuckOS'		; 11 bytes
ebr_system_id:				db 'FAT12   '			; 8 bytes

; End header

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

	; read floppy disc
	mov [ebr_drive_number], dl
	
	mov ax, 1 					; lba = 1, second sector of disk
	mov cl, 1 					; 1 sector to read
	mov bx, 0x7E00 
	call disk_read

	; print message
	mov si, message_hello
	call puts

	cli
	hlt

floppy_error:
	mov si, message_failed
	call puts
	jmp wait_key_and_reboot

wait_key_and_reboot:
	mov ah, 0
	int 16h			; wait for keypress
	jmp 0FFFFh:0 	; jump to start of BIOS

.halt:
	cli		; diable interrupts
	hlt


; Disk routines

; Converts LBA address to CHS address
; Params:
;	- ax: LBA address
; Returns:
;	- cx [bits 0-5]: sector number
;	- cx [bits 6-15]: cylinder
;	- dh: head
lba_to_chs:

	push ax
	push dx

	xor dx, dx							; dx = 0
	div word [bdb_sectors_per_track]	; ax = LBA / SectorsPerTrack
										; dx = LBA % SectorsPerTrack
	inc dx								; dx = LBA % SectorsPerTrack + 1 = sector
	mov cx,dx							; cx = sector

	xor dx, dx							; dx = 0
	div word [bdb_heads]				; ax = (LBA / SectorsPerTrack) / Heads = cylinder
										; dx = (LBA / SectorsPerTrack) % Heads = head
	mov dh, dl							; dh = head
	mov ch, al							; ch = cylinder (lower 8 bits)
	shl ah, 6
	or cl, ah							; put upper 2 bits of cylinder in cl

	pop ax
	mov dl, al							; restore dl
	pop ax
	ret

; Reads sectors from a disck
; Params:
;	- ax: LBA address
;	- cl: number of sectors to read
;	- dl: drive number
;	- ex:bx: memory address to store read data
disk_read:

	push ax
	push bx
	push cx
	push dx
	push di
	
	push cx								; temp save cl
	call lba_to_chs						; compute chs
	pop ax								; al = number of sectors to read
	
	mov ah, 02h
	mov di, 3							; retry count

.retry:
	pusha								; save all registers
	stc									; set carry flag
	int 13h								; carry flag clear = ok
	jnc .done

	; failed
	popa
	call disk_reset

	dec di
	test di, di
	jnz .retry

.fail:
	; failed to load after n retries
	jmp floppy_error

.done:
	popa

	pop di
	pop dx
	pop cx
	pop bx
	pop ax

	ret

; Resets disk controller
;	- dl: drive number
disk_reset:
	pusha
	mov ah, 0
	stc
	int 13h
	jc floppy_error
	popa
	ret
	

message_hello: 		db 'DuckOs', ENDL, 0
message_failed: 	db 'Failed to load floppy', ENDL, 0


times 510-($-$$) db 0
dw 0AA55h
