org 0x7c00
stack_base equ 0x7c00

jmp short Start
nop

BS_OEMName DB 'ooo00ooo' ; OEM String, 必须 8 个字节
BPB_BytsPerSec DW 512 ; 每扇区字节数
BPB_SecPerClus DB 1 ; 每簇多少扇区
BPB_RsvdSecCnt DW 1 ; Boot 记录占用多少扇区
BPB_NumFATs DB 2 ; 共有多少 FAT 表
BPB_RootEntCnt DW 224 ; 根目录文件数最大值
BPB_TotSec16 DW 2880 ; 逻辑扇区总数
BPB_Media DB 0xF0 ; 媒体描述符
BPB_FATSz16 DW 9 ; 每FAT扇区数
BPB_SecPerTrk DW 18 ; 每磁道扇区数
BPB_NumHeads DW 2 ; 磁头数(面数)
BPB_HiddSec DD 0 ; 隐藏扇区数
BPB_TotSec32 DD 0 ; 如果 wTotalSectorCount 是 0 由这个值记录扇区数
BS_DrvNum DB 0 ; 中断 13 的驱动器号
BS_Reserved1 DB 0 ; 未使用
BS_BootSig DB 29h ; 扩展引导标记 (29h)
BS_VolID DD 0 ; 卷序列号
BS_VolLab DB 'FlyanxOS' ; 卷标, 必须 11 个字节
BS_FileSysType DB 'FAT12 ' ; 文件系统类型, 必须 8个字节

Start:
    mov ax, cs
    mov ds, ax
    mov ss, ax
    mov sp, stack_base

    ; 清理屏幕
    call clean_scr

    ; 打印字符
    call write_str

    ; 死循环
    jmp $


    message: 
        db "== first boot program =="
    message_len:


; 清屏操作
clean_scr:
    push ax
    push bx
    push cx
    push dx
    mov ah, 06h
    mov al, 00h
    mov bh, 07h
    mov cx, 00h
    mov dh, 25h
    mov dl, 80h
    int 10h

    pop dx 
    pop cx
    pop bx
    pop ax
    ret

; 写入字符串操作
write_str:
    push ax
    push bx
    push cx
    push dx
    push es
    push bp

    mov ah, 13h
    mov al, 01h
    mov bh, 00h
    mov bl, 03h
    mov cx, message_len - message
    mov dx, 0
    push ds
    pop es
    mov bp, message
    int 10h

    pop bp
    pop es
    pop dx
    pop cx
    pop bx
    pop ax

    ret

times 510 - ($ - $$) db 0
dw 0xAA55