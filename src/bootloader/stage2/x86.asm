bits 16

section _TEXT class=CODE

; args: dividend, divisor, quotientOut, remainderOut
global _x86_div64_32
_x86_div64_32:
    ; make new call frame
    push bp         ; save old call frame
    mov bp, sp      ; init new call frame

    push bx

    mov eax, [bp + 8]   ; eax = upper 32 bits of dividend
    mov ecx, [bp + 12]  ; ecx = divisor
    xor edx, edx
    div ecx             ; eax = quotient, edx = remainder

    ; store upper 32 bits
    mov bx, [bp + 16]
    mov [bx + 4], eax

    ; divide lower 32 bits
    mov eax, [bp + 4]   ; eax = lower 32 bits of dividend
                        ; edx = old remainder
    div ecx
    
    ; store results
    mov [bx], eax
    mov bx, [bp + 18]
    mov [bx], edx

    pop bx

    ; restore old call frame
    mov sp, bp
    pop bp
    ret

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