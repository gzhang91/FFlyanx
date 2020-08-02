org 0x7c00
stack_base equ 0x7c00

jmp short start
nop

%include "fat12hdr.inc"

start:
    mov ax, cs
    mov ds, ax
    mov ss, ax
    mov sp, stack_base
    mov ax, loader_base
    mov es, ax

    ; 清屏
    call clear_screen

    ; 显示查找
    ;push cx
    ;push es
    ;push bp
    ;mov cx, message_len - message
    ;push ds
    ;pop es
    ;mov bp, message
    ;call write_string
    ;pop bp
    ;pop es
    ;pop cx

    ; 重置驱动器
    call reset_driver

    ; 1. 第一轮循环, 读取根目录的14个扇区
    mov byte [sector_loop_cnt], 14
read_root_sector_loop:
    cmp byte [sector_loop_cnt], 0
    jz NO_FOUND_FILE
    dec byte [sector_loop_cnt]

    mov ax, SectorNoOfRootDirectory
    mov cl, 1
    call read_sector

    ; 2. 现在es:bx中存有根目录的第一个扇区,需要每32字节进行循环查找
    ; 开始在扇区中寻找文件，比较文件名

    mov si, file_name           ; ds:si -> Loader的文件名称
    mov di, loader_offset       ; es:di -> LOADER_SEG:LOADER_OFFSET -> 加载到内存中的扇区数据
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
    mov si, file_name
    jmp read_dir_loop

; 没有找到对应的文件
NO_FOUND_FILE:
    mov cx, no_found_msg_len - no_found_msg
    push ds
    pop es
    mov bp, no_found_msg
    call write_string

    jmp $

FOUND_FILE:
    ;mov cx, found_msg_len - found_msg
    ;push ds
    ;pop es
    ;mov bp, found_msg
    ;call write_string

    ; 找到了文件名,将会读取文件内容
    ; 我们需要根据root的directory信息获取文件数据的第一个簇号
    and di, 0xfff0          ; 先将di移到这个root的目录的首地址
    add di, 0x1a            ; 1a处为簇号
    mov ax, word [es:di]    ; 将该簇号保存到内存中
    mov word [cluster_no], ax

    ; 通过簇号计算它的真正扇区号
    add ax, DeltaSectorNo   ; 簇号 + ( FAT1占用的扇区 + FAT2占用的扇区 + BOOTSEC一个扇区 - 2)
    add ax, RootDirSectors  ; 簇号 + ( FAT1占用的扇区 + FAT2占用的扇区 + BOOTSEC一个扇区 - 2) + ROOT扇区数量 = 数据区的第一个扇区
    mov word [data_start_sector], ax

    ; 准备读取扇区, 这里ax为sector的开始, cl为读取的个数, 读取的数据放到 es:bx 中
    ; 下面将读取的扇区也放到0x9000:000处
    mov ax, loader_base
    mov es, ax
    mov ax, word [data_start_sector]
    mov bx, loader_offset
    
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
    mov bp, loaded_file
    call write_string
    
    jmp loader_base:loader_offset

;;; variable
;message db "loading..."
;message_len:

no_found_msg db "no found ..."
no_found_msg_len:
;found_msg db "found ..."
;found_msg_len:
loaded_file db "loaded"
loaded_file_len:

file_name db "LOADER  BIN",0
file_name_len:

sector_loop_cnt: db 0
root_loop_cnt: db 0
file_name_loop_cnt: db 0
cluster_no: dw 0
data_start_sector: dw 0
is_odd: db 0

;;; const
loader_base equ 0x9000
loader_offset equ 0x0
; 到0x9FC00就是不能操作的内存,中间有9FC00-90000=FC00=63KB
    
%include "common_func.inc"

times 510 - ($ - $$) db 0
dw 0xAA55
