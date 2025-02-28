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
	; setup data segments
	mov ax, 0
	mov ds, ax
	mov es, ax

	; setup stack
	mov ss, ax
	mov sp, 0x7C00

	push es
	push word .after
	retf
.after:
	; read floppy disc
	mov [ebr_drive_number], dl

	; show loading message
	mov si, message_loading
	call print

	; read drive parameters
	push es
	mov ah, 08h
	int 13h
	jc floppy_error
	pop es

	and cl, 0x3F						; remove top 2 bits
	xor ch, ch
	mov [bdb_sectors_per_track], cx		; sector count

	inc dh
	mov [bdb_heads], dh					; head count
	
	; read FAT root dir
	mov ax, [bdb_sectors_per_fat]		; lba of root dir = reserved + fats * sectors_per_fat
	mov bl, [bdb_fat_count]
	xor bh, bh
	mul bx								; ax = fats * sectors_per_fat
	add ax, [bdb_reserved_sectors]		; ax = lba of root dir
	push ax

	; compute size of root dir = (32 * number_of_entries) / bytes_per_sector
	mov ax, [bdb_dir_entries_count]
	shl ax, 5							; ax *= 32
	xor dx, dx
	div word [bdb_bytes_per_sector]		; number of sectors to read

	test dx, dx							; if dx != 0, add 1
	jz .root_dir_after
	inc ax

.root_dir_after:
	;read root directory
	mov cl, al							; cl = number of sectors to read = size of root dir
	pop ax								; ax = lba of root
	mov dl, [ebr_drive_number]			; dl = drive number
	mov bx, buffer						; es:bx = buffer
	call disk_read

	; search for kernel.bin
	xor bx, bx
	mov di, buffer

.search_kernel:
	mov si, file_stage2_bin
	mov cx, 11							; compare up to 11 chars
	push di
	repe cmpsb							; compare the two bytes
	pop di
	je .found_kernel

	add di, 32
	inc bx
	cmp bx, [bdb_dir_entries_count]
	jl .search_kernel

	jmp kernel_not_found_error

.found_kernel:
	; di should have the address to the entry
	mov ax, [di + 26]
	mov [stage2_cluster], ax

	; load FAT from disk to mem
	mov ax, [bdb_reserved_sectors]
	mov bx, buffer
	mov cl, [bdb_sectors_per_fat]
	mov dl, [ebr_drive_number]
	call disk_read

	; read kernel and process FAT chain
	mov bx, STAGE2_LOAD_SEGMENT
	mov es, bx
	mov bx, STAGE2_LOAD_OFFSET

.load_kernel_loop:
	; read next cluster
	mov ax, [stage2_cluster]
	add ax, 31

	mov cl, 1
	mov dl, [ebr_drive_number]
	call disk_read

	add bx, [bdb_bytes_per_sector]

	; computer location of next cluster
	mov ax, [stage2_cluster]
	mov cx, 3
	mul cx
	mov cx, 2
	div cx

	mov si, buffer
	add si, ax
	mov ax, [ds:si]

	or dx, dx
	jz .even

.odd:
	shr ax, 4
	jmp .next_cluster_after

.even:
	and ax, 0x0FFF

.next_cluster_after:
	cmp ax, 0x0FF8		; end of chain
	jae	.read_finish

	mov [stage2_cluster], ax
	jmp .load_kernel_loop

.read_finish:
	; jump to kernel
	mov dl, [ebr_drive_number]

	mov ax, STAGE2_LOAD_SEGMENT
	mov ds, ax
	mov es, ax

	jmp STAGE2_LOAD_SEGMENT:STAGE2_LOAD_OFFSET

	jmp wait_key_and_reboot

	cli
	hlt


floppy_error:
	mov si, message_failed
	call print
	jmp wait_key_and_reboot

kernel_not_found_error:
    mov si, message_stage2_not_found
    call print
    jmp wait_key_and_reboot

wait_key_and_reboot:
	mov ah, 0
	int 16h			; wait for keypress
	jmp 0FFFFh:0 	; jump to start of BIOS

.halt:
	cli				; diable interrupts
	hlt

; Prints a string to the screen
; Params:
;   - ds:si points to string
print:
    ; save registers we will modify
    push si
    push ax
    push bx

.loop:
    lodsb               ; loads next character in al
    or al, al           ; verify if next character is null?
    jz .done

    mov ah, 0x0E        ; call bios interrupt
    mov bh, 0           ; set page number to 0
    int 0x10

    jmp .loop

.done:
    pop bx
    pop ax
    pop si    
    ret

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
	
message_loading:			db 'Loading...', ENDL, 0
message_failed: 			db 'Failed to load floppy', ENDL, 0
message_stage2_not_found:	db 'STAGE2.BIN not found', ENDL, 0
file_stage2_bin:        	db 'STAGE2  BIN'
stage2_cluster:				dw 0

STAGE2_LOAD_SEGMENT			equ 0x2000
STAGE2_LOAD_OFFSET			equ 0


times 510-($-$$) db 0
dw 0AA55h

buffer: