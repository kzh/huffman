# huffman
This is an implementation of the [huffman coding](https://en.wikipedia.org/wiki/Huffman_coding) encoder in x86_64 assembly. The purpose of this project was to dive into assembly programming and learn about the huffman coding algorithm. Being so, the code will contain some poor practices and vunerabilities. The assembly in the repository is targetted to intel based darwin operation systems and uses NASM to be assembled.

# usage
Clone the repository:
```bash
git clone https://github.com/furryfaust/huffman.git
```
Enter the repository and build:
```bash
cd huffman && make
```
Run the binary with the string to be encoded as the second argument:
```bash
./huffman e <string>
```
