global start

section .data
    sys_write: equ 0x2000004 
    sys_exit:  equ 0x2000001
    sys_mmap:  equ 0x20000C5

    err_insufficient_args: db "Insufficient arguments", 0xA
    newline: db 0xA

section .text
start:
    ; Check for neccesary arguments
    mov rdx, [rsp]
    cmp rdx, 2
    jl insufficient_args

    ; Skip over argc and argc[0]
    add rsp, 0x10
    call count
    call sort
    call tree
    call encode

    ; Print out results
    mov rsi, r12
    mov rax, sys_write 
    mov rdi, 1 
    mov rdx, r13 
    syscall

   ; Print newline 
    mov rax, sys_write
    mov rsi, newline
    mov rdi, 1
    mov rdx, 1
    syscall

    jmp exit

; Count occurences of each character in the string
count:
    push rbp
    mov rbp, rsp
     
    ; Allocate memory 
    mov rax, sys_mmap
    xor rdi, rdi
    mov rsi, 0x4000 ; 16384 bytes
    mov rdx, 0x3    ; READ and WRITE access
    mov r10, 0x1002 ; PRIVATE and ANON flag 
    mov r8, -0x1    ; No file backing
    xor r9, r9      ; No offset
    syscall

    ; Store zero as starting cipher entries count
    mov dword [rax], 0 

    ; Retrieve string argument
    mov rsi, [rbp + 16]

    ; Set counter register to 0 
    xor rcx, rcx

.loop:
    ; Loop through each letter and build map on letter frequencies
    mov dl, [rsi + rcx] ; Fetch current letter to process
    cmp dl, 0    ; Check if null character
    je .exit

    push rcx             ; Save counter to prepare for inner loop
    xor rcx, rcx         ; Start count at zero

; Search if map has existing entry for this letter
.search_loop:
    cmp dword [rax], ecx ; Check if reached end of map
    je .search_add  ; Jump to create new map entry

    ; Calculate address of letter 
    imul rbx, rcx, 0x6
    add rbx, rax 
    add rbx, 0x4

    cmp dl, byte [rbx + 1]     ; Check if letters are equal
    jne .search_continue

    ; Found existing map entry for the letter, so add one to the frequency count
    mov r8d, dword [rbx + 2]
    inc r8d 
    mov [rbx + 2], r8d 
    jmp .search_exit

.search_continue:
    inc ecx ; Move to next map entry
    jmp .search_loop

; Create new map entry { bool, char, int }
.search_add:
    ; Increase map length
    mov ebx, [rax]
    inc ebx
    mov [rax], dword ebx

    imul rbx, rcx, 0x6
    add rbx, rax 
    add rbx, 0x4

    ; Set map entry data
    mov byte [rbx], 0x0
    mov [rbx + 1], dl
    mov dword [rbx + 2], 0x1

.search_exit:
    pop rcx ; Restore counter register for outer loop (letters loop)
    inc rcx ; Move to next letter 
    jmp .loop

.exit:
    mov rsp, rbp
    pop rbp
    ret

; Insertion sort on the map
sort:
    xor rcx, rcx

.loop:
    inc rcx

    cmp ecx, dword [rax]
    je .exit

    imul r15, rcx, 0x6
    add r15, rax
    add r15, 0x4

    push rcx

.search:
    dec rcx

    cmp rcx, -0x1
    je .search_exit

    imul r14, rcx, 0x6
    add r14, rax
    add r14, 0x4

    mov r13d, dword [r15 + 2]
    cmp r13d, dword [r14 + 2]
    jge .search_exit

    ; Swap map entries at r14 and 15
    mov r12d, [r14 + 2]
    mov [r14 + 2], r13d
    mov [r15 + 2], r12d

    mov r13b, [r15 + 1]
    mov r12b, [r14 + 1]
    mov [r14 + 1], r13b
    mov [r15 + 1], r12b

    mov r15, r14
    jmp .search

.search_exit:
    pop rcx
    jmp .loop

.exit:
    ret

; Build huffman tree
tree:
    xor rcx, rcx ; Set counter register to zero

    ; Determine memory address to build tree
    xor r15, r15
    imul r15d, dword [rax], 0x6
    add r15, rax
    add r15, 0x4

    mov rbx, rax
    add rbx, 0x4

    imul r14d, dword [rax], 0x8
    add r14, r15 

; Create leaves from the frequency map
.base:
    mov [r15 + rcx * 8], rbx
    add rbx, 0x6
    inc rcx

    cmp ecx, dword [rax]
    jne .base 

    ; Check for only one leaf, if so no need to build tree
    cmp rcx, 0x1 
    je .exit

; Start constructing tree from the leaves
.construct:
    push rcx
    ; Load params to tree_create_node
    mov r13, [r15 + 8]
    push r13
    mov r13, [r15]
    push r13

    ; Create node
    call tree_create_node

    ; Clear params
    add rsp, 0x10 

    pop rcx

    ; Load params into tree_get_freq
    push rax

    call tree_get_freq

    ; Save return value to r8
    mov r8d, eax

    pop r11

    add r15, 0x8
    mov [r15], r11

    mov r9, r15

    dec rcx
    cmp rcx, 0x1 
    je .exit

    mov r10, 0x1 

.insert:
    mov rax, [r9 + 8]
    push rax
    call tree_get_freq
    add rsp, 0x8

    cmp eax, r8d
    jg .construct

    mov rax, [r9 + 8]
    mov [r9], rax    
    mov [r9 + 8], r11 

    add r9, 0x8
    inc r10
    cmp r10, rcx
    jne .insert
    jmp .construct

.exit:
    ret

; Create huffman tree node { bool, void*, void*, int }
tree_create_node:
    push rbp
    mov rbp, rsp

    mov byte [r14], 0x1

    ; Store left child
    mov r13, [rbp + 16]
    mov [r14 + 1], r13

    ; Retrieve left child frequency 
    push r13
    call tree_get_freq
    pop r13
    mov rcx, rax

    ; Store right child
    mov r13, [rbp + 24]
    mov [r14 + 9], r13

    ; Retrieve right child frequency
    push r13
    call tree_get_freq
    pop r13
    add rcx, rax

    ; Store total frequency of left and right child
    mov [r14 + 17], ecx

    mov rax, r14
    add r14, 0x15
    mov rsp, rbp
    pop rbp
    ret

; Returns frequency of tree node in eax
tree_get_freq:
    push rbp
    mov rbp, rsp

    ; Load param
    mov rax, [rbp + 16]

    ; Check if node param is non null 
    cmp rax, 0x0
    je .freq_def

    ; Check if node param is a leaf
    cmp byte [rax], 0x0
    jne .node_freq

    ; Get size of leaf
    mov eax, dword [rax + 2]
    jmp .exit 

.node_freq:
    ; Check if node param is not a leaf
    cmp byte [rax], 0x1
    jne .freq_def

    ; Get size of node
    mov eax, dword [rax + 17]
    jmp .exit

.freq_def:
    mov rax, 0x0

.exit:
    mov rsp, rbp
    pop rbp
    ret

; Encode a single char
encode_char:
    push rbp
    mov rbp, rsp

    ; Default retun value of false
    xor rax, rax

    ; Retrieve parameters
    mov rbx, [rbp + 16] ; Retrieve tree node

    ; Check whether is node or leaf
    cmp byte [rbx], 0
    jne .is_node

    cmp byte [rbx + 1], dl
    jne .exit 

    mov rax, 0x1
    jmp .exit

.is_node:
    cmp byte [rbx], 0x1
    jne .exit

    ; Traverse left
    mov byte [r12 + r13], 0x30
    inc r13

    push rbx
    mov rbx, [rbx + 1]
    push rbx
    call encode_char
    add rsp, 0x8 
    pop rbx

    cmp rax, 0x1
    je .exit
    dec r13

    ; Traverse right
    mov byte [r12 + r13], 0x31
    inc r13

    push rbx
    mov rbx, [rbx + 9]
    push rbx
    call encode_char
    add rsp, 0x8
    pop rbx

    cmp rax, 0x1
    je .exit
    dec r13

.exit:
    mov rsp, rbp
    pop rbp
    ret

; Encode string using huffman tree 
encode:

    ; Save register to prepare for syscall
    push rsi

    ; Allocate memory
    mov rax, sys_mmap
    xor rdi, rdi
    mov rsi, 0x1000 ; 4096 bytes
    mov rdx, 0x3    ; READ and WRITE access
    mov r10, 0x1002 ; PRIVATE and ANON flag
    mov r8, -0x1    ; No file backing
    xor r9, r9      ; No offset
    syscall

    ; Restore register after syscall
    pop rsi

    mov r12, rax

    ; Store position for end of string we are building 
    xor r13, r13
    mov r10, 0x100

    xor rcx, rcx ; Clear counter register

    mov r15, [r15]
    push r15

.loop:
    mov dl, byte [rsi + rcx]
    call encode_char

    inc rcx
    cmp byte [rsi + rcx], 0
    jne .loop

.exit:
    pop r15
    ret

; Print out error for insufficient arguments 
insufficient_args:
    mov rax, sys_write 
    mov rdi, 1 
    mov rsi, err_insufficient_args
    mov rdx, 0x17 
    syscall
    jmp exit

exit:
    mov rax, sys_exit ; exit
    mov rdi, 0x0
    syscall
