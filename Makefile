all: src/huffman.asm
	nasm -f macho64 src/huffman.asm -o huffman.o # Assemble
	ld -o huffman huffman.o       # Link
	rm huffman.o								 # Remove byproduct

clean:
	rm huffman
