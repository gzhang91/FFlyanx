jmp LABEL_CODE16

%include "pm.inc"
; $include "common32_func.inc"

; 全局段描述符GDT
[SECTION .gdt]
; GDT
LABEL_GDT:			Descriptor	0, 0, 0							; 空描述符
LABEL_DESC_CODE32:	Descriptor	0, SegCodeLen - 1, DA_C + DA_32	; 代码段，32位
LABEL_DESC_VIDEO:	Descriptor 	0B8000h, 0ffffh, DA_DRW			; 显存首地址
; GDT结束

GdtLen		equ $ - LABEL_GDT	; GDT 长度
GdtPtr		dw	GdtLen			; GDT 界限
			dd	0				; GDT基地址

; GDT选择子
SelectorCode32		equ LABEL_DESC_CODE32 	- LABEL_GDT
SelectorVideo		equ LABEL_DESC_VIDEO 	- LABEL_GDT

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

; 打印的字符串
get_memory_success_msg db "get memory ok !!!!"
get_memory_success_msg_end:

get_memory_failed_msg db "get memory failed !"
get_memory_failed_msg_len:

[section .code16]
align 16
[BITS 16]
LABEL_CODE16:
mov ax, cs
mov ds, ax
mov es, ax
mov ss, ax ; 栈是向下扩展的

; 清屏
;call clear_screen

mov cx, get_memory_success_msg_end - get_memory_success_msg
mov ax, ds
mov es, ax
mov bp, get_memory_success_msg
call write_string

; 初始化32位代码段描述符
xor eax, eax
mov ax, cs
shl eax, 4
;add eax, LABEL_DESC_CODE32
add eax, LABEL_CODE32
mov word [LABEL_DESC_CODE32 + 2], ax
shr eax, 16
mov byte [LABEL_DESC_CODE32 + 4], al
mov byte [LABEL_DESC_CODE32 + 7], ah

; 为加载 gdtr 做准备
xor eax, eax
mov ax, cs
shl eax, 4
add eax, LABEL_GDT			; eax <- gdt 基地址
mov dword [GdtPtr + 2], eax	; [GdtPtr + 2] <- gdt 基地址

; 加载 gdtr
lgdt	[GdtPtr]

; 关中断
cli	

; 打开地址线A20
in al, 92h
or al, 00000010b
out 92h, al

; 准备切换到保护模式
mov eax, cr0
or 	eax, 1
mov cr0, eax

; 真正进入保护方式，为了更新新的CPU状态
jmp dword SelectorCode32:0		; 执行这一句会把SelectorCode32
                                ; 装入 cs，并跳转到
                                ; SelectorCode32:0 处

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
    mov dl, 0x0 ; column
    mov dh, 0x01 ; row
    int 0x10

    pop dx
    pop bx
    pop ax
    ret
 
clear_screen:
    push ax
    push bx
    push cx
    push dx
    mov ah, 0x07
    mov al, 0x0
    mov bh, 0x0
    mov cx, 0x0
    mov dh, 25
    mov dl, 80
    int 0x10

    pop dx
    pop cx
    pop bx
    pop ax
    ret

[section .code32]
align 32
[BITS 32]
LABEL_CODE32:
mov ax, SelectorVideo
mov gs, ax					; 视频选择子（目的）

mov edi, (80 * 10 + 0) * 2	; 屏幕第 10 行，第 0 列。
mov ah, 0Ch					; 0000：黑底	1100：红字
mov al, 'P'
mov [gs:edi], ax

; 到此停止
jmp $

SegCodeLen equ $ - LABEL_CODE32
