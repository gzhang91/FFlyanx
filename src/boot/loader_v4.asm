jmp LABEL_CODE16

%include "fat12hdr.inc"
%include "load.inc"
%include "pm.inc"

; 全局段描述符GDT
[SECTION .gdt]
; GDT
LABEL_GDT:			Descriptor	0, 0, 0							; 空描述符
LABEL_DESC_CODE32:	Descriptor	0, 0xfffff, DA_C + DA_32	; 代码段，32位
LABEL_DESC_VIDEO:	Descriptor 	0B8000h, 0ffffh, DA_DRW			; 显存首地址
LABEL_DESC_DATA32:  Descriptor  0, 0xfffff, DA_DRW + DA_32            ; 数据段
; GDT结束

GdtLen		equ $ - LABEL_GDT	; GDT 长度
GdtPtr		dw	GdtLen			; GDT 界限
			dd	0				; GDT基地址

; GDT选择子
SelectorCode32 equ LABEL_DESC_CODE32 	- LABEL_GDT
SelectorVideo equ LABEL_DESC_VIDEO 	- LABEL_GDT
SelectorData32 equ LABEL_DESC_DATA32 - LABEL_GDT

[section .code16]
align 16
[BITS 16]
LABEL_CODE16:
    mov ax, cs
    mov ds, ax
    mov es, ax
    mov ss, ax ; 栈是向下扩展的
    mov sp, top_of_stack

    mov ebx, 0
    mov di, mem_addr_base

; 得到内存信息
get_memory:
    mov eax, 0x0e820
    mov ecx, 20
    mov edx, 0x0534d4150
    int 0x15

    jc get_memory_failed

    ; 记录个数
    inc dword [mem_cnt]
    add di, 20

    cmp ebx, 0
    je get_memory_success
    
    jmp get_memory

get_memory_failed:
    mov dword [mem_cnt], 0
    mov cx, get_mem_fail_msg_len - get_mem_fail_msg
    mov bp, get_mem_fail_msg
    push dx
    mov dl, 0
    mov dh, 1
    call write_string
    pop dx
    jmp $

get_memory_success:
    mov cx, get_mem_succ_msg_len - get_mem_succ_msg
    mov bp, get_mem_succ_msg
    push dx
    mov dl, 0
    mov dh, 2
    call write_string
    pop dx

    ; 这里运行ok

; 加载kernel.bin文件
; 重置驱动器
    call reset_driver

    ; 1. 第一轮循环, 读取根目录的14个扇区
    mov byte [sector_loop_cnt], 14
read_root_sector_loop:
    cmp byte [sector_loop_cnt], 0
    jz NO_FOUND_FILE
    dec byte [sector_loop_cnt]

    mov ax, kernel_base
    mov es, ax
    mov ax, SectorNoOfRootDirectory
    mov bx, kernel_offset
    mov cl, 1
    call read_sector

    ; 2. 现在es:bx中存有根目录的第一个扇区,需要每32字节进行循环查找
    ; 开始在扇区中寻找文件，比较文件名

    mov si, kernel_file   ; ds:si -> Loader的文件名称
    mov di, kernel_offset ; es:di -> LOADER_SEG:LOADER_OFFSET -> 加载到内存中的扇区数据
    cld     ; 字符串比较方向，si、di方向向右

    mov byte [root_loop_cnt], 16                  ; 一个扇区512字节，FAT目录项占用32个字节，512/32 = 16，所以一个扇区有16个目录项
read_dir_loop:
    cmp byte [root_loop_cnt], 0
    jz read_root_sector_loop                 ; 16个目录项都查找完了,没有发现,进入下一个扇区读取查找
    dec byte [root_loop_cnt]

    mov byte [file_name_loop_cnt], 11
cmp_file_name:
    cmp byte [file_name_loop_cnt], 0
    jz FOUND_FILE
    dec byte [file_name_loop_cnt]

    lodsb ; ds:si -> al, si++
    cmp al, byte [es:di]    ; 比较字符
    je go_on
    jmp next_dir_loop

go_on:
    inc di
    jmp cmp_file_name

next_dir_loop:
    and di, 0xfff0      ; di &= f0, 11111111 11110000，是为了让它指向本目录项条目的开始。
    add di, 32 
    mov si, kernel_file
    jmp read_dir_loop

; 没有找到对应的文件
NO_FOUND_FILE:
    mov cx, no_found_msg_len - no_found_msg
    push ds
    pop es
    mov bp, no_found_msg
    push dx
    mov dl, 0
    mov dh, 3
    call write_string
    pop dx

    jmp $

FOUND_FILE:
    mov cx, found_msg_len - found_msg
    push ds
    pop es
    mov bp, found_msg
    push dx
    mov dl, 0
    mov dh, 4
    call write_string
    pop dx

    ; 找到了文件名,将会读取文件内容
    ; 我们需要根据root的directory信息获取文件数据的第一个簇号
    and di, 0xfff0          ; 先将di移到这个root的目录的首地址
    add di, 0x1a            ; 1a处为簇号

    mov ax, kernel_base
    mov es, ax
    mov ax, word [es:di]    ; 将该簇号保存到内存中
    mov word [cluster_no], ax

    ; 通过簇号计算它的真正扇区号
    add ax, DeltaSectorNo   ; 簇号 + ( FAT1占用的扇区 + FAT2占用的扇区 + BOOTSEC一个扇区 - 2)
    add ax, RootDirSectors  ; 簇号 + ( FAT1占用的扇区 + FAT2占用的扇区 + BOOTSEC一个扇区 - 2) + ROOT扇区数量 = 数据区的第一个扇区
    mov word [data_start_sector], ax

    ; 准备读取扇区, 这里ax为sector的开始, cl为读取的个数, 读取的数据放到 es:bx 中
    ; 下面将读取的扇区也放到0x7000:0000
    mov ax, word [data_start_sector]
    mov bx, kernel_offset
loading_file:
    push ax
    push bx
    mov al, '*'
    mov ah, 0xe
    mov bl, 0x2
    int 0x10
    pop bx
    pop ax

    ; 读取一个扇区
    mov cl, 1
    call read_sector

    ; 通过簇号获得该文件的下一个FAT项的值
    mov ax, word [cluster_no]
    call get_pat_entry
    cmp ax, 0xff8
    jae FILE_LOADED

    ; FAT项的值 < 0xff8，那么我们继续设置下一次要读取的扇区的参数
    ; 通过簇号计算它的真正扇区号
    mov word [cluster_no], ax  ; 保存新的簇号
    mov dx, RootDirSectors
    add ax, dx
    add ax, DeltaSectorNo       ; 簇号 + 根目录占用空间 + 文件开始扇区号 == 文件数据的扇区
    add bx, [BPB_BytsPerSec]    ; bx += 扇区字节量
    jmp loading_file

FILE_LOADED:
    mov cx, loaded_file_len - loaded_file
    mov ax, ds
    mov es, ax
    push dx
    mov dl, 0
    mov dh, 5
    mov bp, loaded_file
    call write_string
    pop dx

    ; 初始化32位代码段描述符
    xor eax, eax
    mov ax, cs
    shl eax, 4
    add eax, LABEL_CODE32
    mov word [LABEL_DESC_CODE32 + 2], ax
    shr eax, 16
    mov byte [LABEL_DESC_CODE32 + 4], al
    mov byte [LABEL_DESC_CODE32 + 7], ah

    xor eax, eax
    mov ax, cs
    shl eax, 4
    add eax, LABEL_DATA32
    mov word [LABEL_DESC_DATA32 + 2], ax
    shr eax, 16
    mov byte [LABEL_DESC_DATA32 + 4], al
    mov byte [LABEL_DESC_DATA32 + 7], ah

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

%include "common_func.inc"

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

    mov ax, SelectorData32
    mov ds, ax
    mov ss, ax
    mov fs, ax
    mov es, ax
    mov esp, top_of_stack - addr_base

    ;xor eax, eax
    ;add dword [disp_pos - addr_base], 2
    ;mov al, 0x34
    ;push eax
    ;call PrintChar  ; 打印出34
    ;add esp, 4

    xor eax, eax
    mov eax, mem_addr_base - addr_base
    push eax
    mov eax, [mem_cnt - addr_base]
    push eax
    mov eax, mem_size - addr_base
    push eax
    mov eax, ards_base - addr_base
    push eax
    call CalcMemSize
    add esp, 16
    
    mov [mem_size - addr_base], eax
    push eax
    call PrintMemSize
    add esp, 4

    xor eax, eax
    add dword [disp_pos - addr_base], 2
    mov eax, 0xFF891234
    push eax
    call PrintInt
    add esp, 4

    ; 到此停止
    jmp $

%include "common32_func.inc"

[section .data32]
align 32
LABEL_DATA32:
;----------------------------------------------------------------------------
;   16位实模式下使用的数据地址
;----------------------------------------------------------------------------
; 字符串 ---
addr_base: db 0
get_mem_succ_msg: db "check memory success !"
get_mem_succ_msg_len:
get_mem_fail_msg: db "check memory failed !"
get_mem_fail_msg_len:
found_msg: db "found kerner.bin"
found_msg_len:
no_found_msg: db "cannot found kernel.bin"
no_found_msg_len:
loaded_file: db "load kernel file ok !"
loaded_file_len:

sector_loop_cnt: db 0
root_loop_cnt: db 0
file_name_loop_cnt: db 0

kernel_file: db "KERNEL  BIN", 0
mem_size_str: db "Memory Size: ", 0
kb_str: db "MB", 10, 0
data_start_sector: dw 0
cluster_no: dw 0

; 变量 ---
mem_cnt: dd 0        ; 检查完成的ARDS的数量，为0则代表检查失败
mem_size: dd 0        ; 内存大小
disp_pos: dd (80 * 12 + 0) * 2 ; 初始化显示位置为第 12 行第 0 列
; 地址范围描述符结构(Address Range Descriptor Structure)
ards_base:
    base_addr_low: dd 0
    base_addr_high: dd 0
    length_low: dd 0
    length_high: dd 0
    type: dd 0
; 将内存放置的地方
mem_addr_base: times 256 db 0

;----------------------------------------------------------------------------
;   32位保护模式下的数据地址符号
;mem_size_str_32 equ loader_phy_addr + mem_size_str_16
;kb_str_32 equ loader_phy_addr + kb_str_16

;mem_cnt_32 equ loader_phy_addr + mem_cnt_16
;mem_size_32 equ loader_phy_addr + mem_size_16
;disp_pos_32 equ loader_phy_addr + disp_pos_16

;ARDS_32 equ loader_phy_addr + ARDS_16
;    base_addr_low_32 equ loader_phy_addr + base_addr_low_16
;    base_addr_high_32 equ loader_phy_addr + base_addr_high_16
;    length_low_32 equ loader_phy_addr + length_low_16
;    length_high_32 equ loader_phy_addr + length_high_16
;    type_32 equ loader_phy_addr + type_16

;mem_addr_base_32 equ loader_phy_addr + mem_addr_base_16

; 堆栈就在数据段的末尾，一共给这个32位代码段堆栈分配4KB
stack_space: times 0x1000    db 0
top_of_stack equ $     ; 栈顶
;============================================================================