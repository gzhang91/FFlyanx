jmp start
nop

start:
    mov ax, cs
    mov ds, ax
    mov es, ax
    mov sp, ax

    mov ebx, 0
    mov di, memory_addr_base

get_memory:
    mov eax, 0x0000e820
    mov ecx, 20
    mov edx, 0x0534d4150
    int 0x15

    jc get_memory_failed

    ; 记录个数
    inc dword [totol_cnt]

    cmp ebx, 0
    je get_memory_success
    add di, 20

    ; 记录内存值
    add dword [totol_memory], ebx
    
    jmp get_memory

get_memory_failed:
    mov dword [totol_cnt], 0
    mov cx, get_memory_failed_msg_len - get_memory_failed_msg
    mov bp, get_memory_failed_msg
    call write_string
    jmp $

get_memory_success:
    mov cx, get_memory_success_msg_end - get_memory_success_msg
    mov bp, get_memory_success_msg
    call write_string
    jmp $
    
; 32位数据段,可以被内核和16位实模式都可以引用
[section .data32]
align 32
date32:
; 地址总数
totol_memory: dd 0

; 获取的结构体个数
totol_cnt: dd 0

; **地址范围描述符结构**(Address Range Descriptor Structure)
ARDS:
    base_addr_low: dd 0
    base_addr_high: dd 0
    length_low: dd 0
    length_high: dd 0
    type: dd 0

; 将内存放置的地方
memory_addr_base: times 256 db 0

get_memory_success_msg: db "get memory ok !"
get_memory_success_msg_end

get_memory_failed_msg: db "get memory failed !"
get_memory_failed_msg_len


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
