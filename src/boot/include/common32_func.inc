;============================================================================
;   计算内存大小
; CalcMemSize 
; 输入参数: 
;   1. 保存内存地址 mem_base
;   2. 总共有多少个ARDS [mem_cnt]
;   3. mem_size mem_size
;   4. ARDS结构体地址 ards
;   
; 输出参数:
;   eax  
;----------------------------------------------------------------------------
CalcMemSize:
    push ebp
    mov ebp, esp

    push esi
    push ebx
    push edx
    push edi
    
    mov esi, [ebp + 16 + 4]   ; mem_base地址
    ; [ebp + 12 + 4] ; 循环多少次
    ; [ebp + 8 + 4]  ; mem_size地址
    mov ebx, [ebp + 4 + 4]    ; ards结构体

.loop:
    cmp dword [ebp + 12 + 4], 0  ; 循环多少次
    je return
    dec dword [ebp + 12 + 4]
    mov edx, 5
    mov edi, ebx
.2:
    mov eax, dword [esi]
    stosd
    add esi, 4 
    dec edx                
    cmp edx, 0
    jnz .2
    cmp dword [ebx + 16], 1 ; type
    jne .3
    mov eax, [ebx + 0]
    add eax, [ebx + 8] 
    cmp eax, [ebp + 8 + 4]
    jb .3
    mov [ebp + 8 + 4], eax
.3:
    jmp .loop

return:
    mov eax, [ebp + 8 + 4]

    pop edi
    pop edx
    pop ebx
    pop esi
    pop ebp

    ret

;============================================================================
;   打印内存大小(以KB显示)
; PrintMemSize
; 输入参数:
;   1. mem_size
; 输出参数:
;   无
;----------------------------------------------------------------------------
PrintMemSize:
    ;mov ebx, [esp + 4]
    push ebp
    mov ebp, esp
    push eax
    push ebx

    xor eax, eax
    mov eax, mem_size_str - addr_base
    push eax
    call PrintStr
    add esp, 4

    mov eax, [ebp + 4 + 4]
    xor edx, edx
    mov ebx, 1024 * 1024
    div ebx

    push eax
    call PrintInt 
    add esp, 4

    xor eax, eax
    mov eax, kb_str - addr_base
    push eax
    call PrintStr
    add esp, 4

    pop ebx
    pop eax
    pop ebp
    ret

;============================================================================
;   打印函数，它类似与C语言中的printf，但它不支持'%'可变参数
; 函数原型：PrintStr(void* ds:ptr)，ptr指向要打印的字符串，字符串以0结尾
;----------------------------------------------------------------------------
PrintStr:
    push ebp
    mov ebp, esp
    push edi
    push esi

    mov edi, [disp_pos - addr_base]	; 得到显示位置
    mov esi, [ebp + 4 + 4] ; base addr

again:
    cmp byte [ds:esi], 0
    je over

    cmp byte [ds:esi], 10 ; 换行
    je new_line

    mov ah, 0x04
    mov al, [ds:esi]

    mov [gs:edi], ax
    inc esi
    add edi, 2
    jmp again

new_line:
    push ebx
    push edx
    xor edx, edx
    mov eax, edi
    mov ebx, 80 * 2
    div ebx
    ; edx 就是余数, eax 是商 也就是行数
    inc eax 
    mov ebx, 80 * 2
    mul ebx
    mov edi, eax
    pop edx
    pop ebx

    ;mov ah, 0x04
    ;mov al, 'A'
    ;mov [gs:edi], ax
    inc esi
    ;add edi, 2
    jmp again

over:
    mov [disp_pos - addr_base], edi

    pop esi
    pop edi
    pop ebp

    ret
;============================================================================
;   显示一个char类型
; PrintChar
; 输入参数:
;   char data (1个字节)
; 输出参数:
;   无
;----------------------------------------------------------------------------
PrintChar:
    push ebp
    mov ebp, esp
    push edi
    push eax
    push ecx
    push ebx

    mov edi, [disp_pos - addr_base]	; 得到显示位置
    mov eax, [ebp + 4 + 4] ; 1个字节参数

    mov ah, 0x04 ; 黑底红字
    mov bl, al
    shr al, 4
    mov ecx, 2
BEGIN:
    cmp al, 10
    jae A_Z
    add al, '0'
    jmp NEXT
A_Z:
    sub al, 10
    add al, 'A'
NEXT:
    mov [gs:edi], ax
    add edi, 2
    mov al, bl
    and al, 0x0F
    loop BEGIN

    mov [disp_pos - addr_base], edi
    pop ebx
    pop ecx
    pop eax
    pop edi
    pop ebp

	ret
;============================================================================
;   显示一个整形数
; PrintInt
; 输入参数:
;   int data (4个字节)
; 输出参数:
;   无
;----------------------------------------------------------------------------
PrintInt:
    push ebp
    mov ebp, esp
    push eax

    mov eax, [ebp + 4 + 4] ; 1个字节参数

    shr eax, 24
    push eax
    call PrintChar
    add esp, 4

    mov eax, [ebp + 4 + 4]
    shr eax, 16
    and eax, 0xff
    push eax
    call PrintChar
    add esp, 4

    mov eax, [ebp + 4 + 4]
    shr eax, 8
    and eax, 0xff
    push eax
    call PrintChar
    add esp, 4

    mov eax, [ebp + 4 + 4]
    and eax, 0xff
    push eax
    call PrintChar
    add esp, 4

    pop eax
    pop ebp

	ret