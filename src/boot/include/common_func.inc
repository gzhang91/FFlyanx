;;; function

; cx 需要放置字符串的长度
; es:bp 需要放置字符串的首地址
; dl: col, dh: row
write_string :
    push ax
    push bx
    push dx
    mov ah, 0x13
    mov al, 0x1
    mov bh, 0x0
    mov bl, 0x02
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

reset_driver:
    push ax
    push dx
    mov ah, 0
    mov dl, 0

    int 0x13

    pop dx
    pop ax
    ret

;  作用:
;  从第 ax 个 Sector 开始, 将 cl 个 Sector 读入 es:bx 中
read_sector:
	; -----------------------------------------------------------------------
	; 怎样由扇区号求扇区在磁盘中的位置 (扇区号 -> 柱面号, 起始扇区, 磁头号)
	; -----------------------------------------------------------------------
	; 设扇区号为 x
	;                           ┌ 柱面号 = y >> 1
	;       x           ┌ 商 y ┤
	; -------------- => ┤      └ 磁头号 = y & 1
	;  每磁道扇区数       │
	;                   └ 余 z => 起始扇区号 = z + 1
	push	bp
	mov	bp, sp
	sub	esp, 2			; 辟出两个字节的堆栈区域保存要读的扇区数: byte [bp-2]

	mov	byte [bp-2], cl
	push	bx			; 保存 bx
	mov	bl, [BPB_SecPerTrk]	; bl: 除数
	div	bl			; y 在 al 中, z 在 ah 中
	inc	ah			; z ++
	mov	cl, ah			; cl <- 起始扇区号
	mov	dh, al			; dh <- y
	shr	al, 1			; y >> 1 (其实是 y/BPB_NumHeads, 这里BPB_NumHeads=2)
	mov	ch, al			; ch <- 柱面号
	and	dh, 1			; dh & 1 = 磁头号
	pop	bx			; 恢复 bx
	; 至此, "柱面号, 起始扇区, 磁头号" 全部得到 ^^^^^^^^^^^^^^^^^^^^^^^^
	mov	dl, [BS_DrvNum]		; 驱动器号 (0 表示 A 盘)
GO_ON_READING:
	mov	ah, 2				; 读
	mov	al, byte [bp-2]		; 读 al 个扇区
	int	13h
	jc	GO_ON_READING		; 如果读取错误 CF 会被置为 1, 这时就不停地读, 直到正确为止

	add	esp, 2
	pop	bp
    ret

; 在光标后打印一个字符, char放到al中
;print_char:
    ;push bx
 ;   mov ah, 0xe
    ;mov bl, 0xf
;   int 0x10
    ;pop bx
;    ret

; 作用：找到簇号为 ax 在 FAT 中的条目，然后将结果放入 ax 中。
; 注意：中间我们需要加载 FAT表的扇区到es:bx处，所以我们需要先保存es:bx
get_pat_entry:
    push es
    push bx

    ; 在加载的段地址处开辟出新的空间用于存放加载的FAT表
    push ax
    mov ax, loader_base - 0x100
    mov es, ax
    pop ax

    ; bp用于判断奇偶
    push bp
    mov bp, 0
    mov bx, 3
    mul bx      ; ax存放低16位, dx存放高16位
    mov bx, 2
    div bx      ; ax存放商，dx存放余数
    cmp dx, 0
    je even
    mov bp, 1
even:
    ; FAT表占 9个扇区 ， 簇号 5 ， 5 / 512 -- 0 .. 5， FAT表中的0扇区， FAT表0扇区中这个簇号所在偏移是5
    ; 570   570 / 512 -- 1 .. 58， FAT表中的1扇区， FAT表1扇区中这个簇号所在偏移是58
    mov dx, 0
    mov bx, [BPB_BytsPerSec]
    div bx      ; dx:ax / 每扇区字节数，ax(商)存放FAT项相对于FAT表中的扇区号; dx(余数)FAT项在相对于FAT表中的扇区的偏移

    push dx                 ; 保存FAT项在相对于FAT表中的扇区的偏移。
    mov bx, 0               ; bx = 0，es:bx --> (LOADER_SEG - 0x100):0
    add ax, SectorNoOfFAT1  ; 此句执行之后的 ax 就是 FATEntry 所在的扇区号
    mov cl, 2               ; 读取两个扇区
    call read_sector         ; 一次读两个，避免发生边界错误问题，因为一个FAT项可能会跨越两个扇区
    pop dx                  ; 恢复FAT项在相对于FAT表中的扇区的偏移。
    add bx, dx              ; bx += FAT项在相对于FAT表中的扇区的偏移，得到FAT项在内存中的偏移地址，因为已经将扇区读取到内存中
    mov ax, [es:bx]         ; ax = 簇号对应的FAT项，但还没完成
    cmp bp, 1               ; 判断是奇数还是偶数
    je odd
    and ax, 0x0fff
    jmp ok
odd:
    shr ax, 4
ok:
    pop bp
    pop bx
	pop es
    ret
