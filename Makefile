.PHONY: clean
all: boot.bin

boot.bin: boot0.bin boot1.bin
	@cat boot0.bin boot1.bin > boot.bin
boot0.bin: src/boot0.s
	@echo "Assembling boot0.s"
	@nasm -fbin src/boot0.s -o boot0.bin
boot1.bin: src/boot0.s
	@echo "Assembling boot1.s"
	@nasm -fbin src/boot1.s -o boot1.bin
	
clean:
	@echo "cleaning all bin files..."
	@rm *.bin