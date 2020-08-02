;org 0x7c00
;StackBase equ 0x7c00

%ifdef	_BOOT_DEBUG_
    org  0100h			; 调试状态, 做成 .COM 文件, 可调试
%else
    org  07c00h			; Boot 状态, Bios 将把 Boot Sector 加载到 0:7C00 处并开始执行
%endif
;================================================================================================
%ifdef	_BOOT_DEBUG_
    StackBase		equ	0100h	; 调试状态下堆栈基地址(栈底, 从这个位置向低地址生长)
%else
    StackBase		equ	07c00h	; Boot状态下堆栈基地址(栈底, 从这个位置向低地址生长)
%endif

	jmp short START
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

; db定义一个字节, dw 一个字, dd定义一个双字double
BootMessage:
	db "****Booting...HELLO WORLD****"
BootMessageEnd:

START:
	mov ax, cs
	mov ds, ax
	mov ss, ax
	mov sp, StackBase


	; 打印字符串
	mov al, 1
	mov bh, 0
	mov bl, 0x02 ; 黑体白字
	mov cx, BootMessageEnd - BootMessage
	mov dh, 0
	mov dh, 0
	push ds
	pop es

	mov bp, BootMessage
	mov ah, 0x13
	int 0x10

	jmp $

; times n m  n: 重复定义多少次, m: 定义的数据
times 510 - ($ - $$) db 0
dw 0xAA55 