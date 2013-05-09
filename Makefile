hdump: hdump.o
	ld -o hdump hdump.o
hdump.o: hdump.asm
	nasm -f elf -g -F dwarf hdump.asm
