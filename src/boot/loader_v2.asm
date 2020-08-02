jmp LABEL_CODE16

%include "pm.inc"
; $include "common32_func.inc"


; 打印的字符串
get_memory_success_msg: db "get memory ok !"
get_memory_success_msg_end

get_memory_failed_msg: db "get memory failed !"
get_memory_failed_msg_len

[section .code16]
[BITS 16]
LABEL_CODE16:
mov ax, cs
mov ds, ax
mov es, ax
mov ss, ax ; 栈是向下扩展的

mov cx, get_memory_success_msg_end - get_memory_success_msg
mov ax, ds
mov es, ax
mov bp, get_memory_success_msg
call write_string

jmp $

; cx 需要放置字符串的长度
; es:bp 需要放置字符串的首地址
write_string :
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

 