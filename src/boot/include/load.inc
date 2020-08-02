;; 内核挂载点
; 注意：1、必须与 MAKEFILE 中参数 -Ttext 的值相等!!
;      2、这是个物理地址而非仅仅是个偏移，如果 -Ttext 的值为 0x328000，则它的值也应该是 0x328000。
kernel_entry_point_phy_addr equ 0x1000

; LOADER.BIN 被加载的位置　--- 段地址
loader_base equ 0x9000
; LOADER.BIN 被加载的位置　--- 偏移地址
loader_offset equ 0x100
; LOADER.BIN 被加载到的位置　--- 物理地址　(= LOADER_SEG * 10h)
loader_phy_addr equ loader_base * 10h

; KERNEL.BIN 被加载到的位置 ----  段地址
kernel_base equ 0x7000
; KERNEL.BIN 被加载到的位置 ---- 偏移地址
kernel_offset equ 0
; KERNEL.BIN 被加载到的位置　--- 物理地址　(= KERNEL_SEG * 10h)
kernel_phy_addr equ kernel_base * 10h

;; 为kernel.bin装载保留的内存大小(字节)，内核文件大小不应该超过这个大小！
kernel_have_space   equ loader_phy_addr - kernel_phy_addr

