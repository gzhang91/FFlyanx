;org 0x7c00
;StackBase equ 0x7c00

; org  0100h
; StackBase		equ	0100h

	jmp short START
	nop

; db定义一个字节, dw 一个字, dd定义一个双字double
BootMessage:
	db "****loader...HELLO WORLD****"
BootMessageEnd:

START:
	mov ax, cs
	mov ds, ax
	mov ss, ax
	; mov sp, StackBase

	mov cx, BootMessageEnd - BootMessage
    mov ax, ds
    mov es, ax
    mov bp, BootMessage
    call write_string

	jmp $

write_string:
    push ax
    push bx
    push dx
    mov ah, 0x13
    mov al, 0x1
    mov bh, 0x0
    mov bl, 0x02
    mov dx, 0x00
    int 0x10

    pop dx
    pop bx
    pop ax
    ret
