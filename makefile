# makefile for kernel

TARGET = target
SRC = src
BOOT_INCLUDE = src/boot/include/
INCLUDE = include/
FLOPPY = gzhang.img
MOUNT_POINT = /media/test

BOOT_BIN = boot.bin 
BOOT_LOADER = loader.bin
KERNEL=

ASM = nasm
CC = gcc
ASM_FLAGS = -I $(BOOT_INCLUDE) -I $(INCLUDE)


.PHONY: nop all image debug run clean realclean

nop:
	@echo "all		编译所有文件，生成目标文件(二进制文件，boot.bin)"
	@echo "image	生成系统镜像文件"
	@echo "debug	打开bochs进行系统的运行和调试"
	@echo "run		提示用于如何将系统安装到虚拟机上运行"
	@echo "clean	清理所有的中间编译文件"
	@echo "realclean	完全清理：清理所有的中间编译文件以及生成的目标文件（二进制文件）"

all: $(TARGET)/$(BOOT_BIN) $(TARGET)/$(BOOT_LOADER) $(TARGET)/$(KERNEL)
	@echo "生成成功 !!!"

image: $(FLOPPY) $(TARGET)/$(BOOT_BIN) $(TARGET)/$(BOOT_LOADER)
	dd if=$(TARGET)/$(BOOT_BIN) of=$(FLOPPY) bs=512 count=1 conv=notrunc
	mount $(FLOPPY) $(MOUNT_POINT)
	\cp -rf $(TARGET)/$(BOOT_LOADER) $(MOUNT_POINT)
	umount $(MOUNT_POINT)

debug:
	bochs -q

run: $(FLOPPY)
	@qemu-system-i386 -drive file=$(FLOPPY),if=floppy
	@echo "你还可以使用Vbox等虚拟机挂载gzhang.img软盘，即可开始运行！"

clean:
	-rm -rf $(TARGET)/*.o

realclean:
	-rm -rf $(TARGET)/*

$(FLOPPY): 
	dd if=/dev/zero of=$(FLOPPY) bs=512 count=2880 

#$(TARGET)/$(BOOT_BIN): $(SRC)/boot/include/common_func.inc 
#$(TARGET)/$(BOOT_BIN): $(SRC)/boot/include/fat12hdr.inc
$(TARGET)/$(BOOT_BIN): $(SRC)/boot/boot_v3.asm 
	$(ASM) $(ASM_FLAGS) -o $@ $^ 

$(TARGET)/$(BOOT_LOADER): $(SRC)/boot/loader_v4.asm
	$(ASM) $(ASM_FLAGS) -o $@ $<

