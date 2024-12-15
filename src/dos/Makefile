CC = ../compiler/ucc
ASM = ../assembler/uasm

all:
	make -r dos.exe

dos.dmem.hex: dos.exe
dos.pmem.hex: dos.exe

%.exe: %.s
	$(ASM) -o $@ --pmem $*.pmem.hex --dmem $*.dmem.hex $<

%.s: %.c
	$(CC) -o $@ $<

.PHONY: run
run: dos.pmem.hex dos.dmem.hex
	../../tool/uart.py --pmem dos.pmem.hex --dmem dos.dmem.hex --nowait
