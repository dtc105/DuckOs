bits 16

section _TEXT class=CODE


; int `10h ah-0Eh
; args: character, page
global _x86_Video_WriteCharTeletype
_x86_Video_WriteCharTeletype:
    ; make new call frame
    push bp         ; save old call frame
    mov bp, sp      ; init new call frame

    ; save bx
    push bx

    ; [bp] - old call frame
    ; [bp + 2] - return address
    ; [bp + 4] - character
    ; [bp + 6] - page
    mov ah, 0Eh
    mov al, [bp + 4]
    mov bh, [bp + 6]

    int 10h

    ; restore bx
    pop bx

    ; restore old call frame
    mov sp, bp
    pop bp
    ret