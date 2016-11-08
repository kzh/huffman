; `create_tree` allocates memory for a tree structure and populates the fields.
; The head of the tree will initially be set to null.
; The memory layout for the tree structure will be:
;
; struct {
;     int usedMemory, allocatedMemory; // 8 bytes
;     struct {
;         bool isNode;        // 1 byte
;         void *left, *right; // 16 bytes
;         int frequency;      // 4 bytes
;     } *head;
;
;     struct {
;         bool isNode; 
;         void *left, *right; // 16 bytes
;     } nodes[];
; }
;
; The memory address of the tree is returned in the rax register.
create_tree:
    ; Allocate memory
    mov r15, 0x1000 ; 4096 bytes / 1 mem page 
    push r15
    call mmap
    add rsp, 8

    mov dword [rax], 0x16        ; Store used memory
    mov dword [rax + 4], 0x1000  ; Store allocated memory
    ret

; `tree_create_node` allocates memory for a tree node structure and returns the memory
; address of the structure in the rax register. Calling this procedure requires a tree 
; structure created by `create_tree` and two tree nodes/leaves structures passed in as
; parameters through the stack.
; The memory layout for the tree node structure will be:
;
; struct {
;     bool isNode;        // 1 byte
;     void *left, *right; // 16 bytes
;     int frequency;      // 4 bytes
; }
;
tree_create_node:
    push rbp
    mov rbp, rsp

    ; Load tree parameter from stack into register
    mov rax, [rbp + 16] 

    mov r15d, dword [rax] ; Retrieve tree used memory
    add r15d, 0x15        ; Add 21 bytes (size of node) to tree used memory
    mov dword [rax], r15d ; Update tree used memory

    cmp r15d, dword [rax + 4] ; Check if tree has enough memory
    jge .enough_mem

    ; Save register to prepare for syscall
    push rax

    ; Load mem page location into parameters for mremap
    mov r15, rax 
    add r15, 0x1000 ; 4096 bytes / 1 mem page
    push r15

    ; Load alloc size into parameters for mremap
    mov r15, 0x1000 ; 4096 bytes / 1 mem page
    push r15

    call mremap
    add rsp, 16     ; Clear parameters off stack

    mov dword [rax + 4], r15d

    ; Restore register after syscall
    pop rax

.enough_mem:
    ; Pinpoint memory location of node
    add eax, dword [rax]
    sub eax, 0x15

    mov byte [rax], 0x1 ; Store node signifier

    sub rsp, 8               ; Reserve space on stack to hold total frequency
    mov dword [rbp - 8], 0x0 ; Store zero as initial total frequency of left and right node

    ; Handle left node parameter
    mov r15, [rbp + 24]      ; Retrieve left node parameter
    push rax                 ; Save rax for upcoming call 
    push r15                 ; Load into parameter for upcoming call
    call tree_node_get_freq  ; Retrieve frequency of left node 
    add dword [rbp - 8], eax ; Add the left node frequency to total frequency
    add rsp, 0x8             ; Clear call parameters off stack
    pop rax                  ; Restore rax after call
    mov [rax + 1], r15       ; Store left node address in parent node

    ; Handle right node parameter
    mov r15, [rbp + 32]      ; Retrieve right node parameter
    push rax                 ; Save rax for upcoming call 
    push r15                 ; Load into parameter for upcoming call
    call tree_node_get_freq  ; Retrieve frequency of right node 
    add dword [rbp - 8], eax ; Add the right node frequency to total frequency
    add rsp, 0x8             ; Clear call parameters off stack
    pop rax                  ; Restore rax after call
    mov [rax + 9], r15       ; Store right node address in parent node

    ; Store total frequnecy in node
    mov r15d, dword [rbp - 8]
    mov [rax + 17], r15d

    ; Release space used to hold total frequency
    add rsp, 0x8

    mov rsp, rbp
    pop rbp
    ret

; `tree_node_get_freq` takes in a tree node/leaf parameter through the stack and returns the 
; frequency of that node/leaf in rax. 
tree_node_get_freq:
    push rbp
    mov rbp, rsp

    ; Load tree/node param
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

; TODO
tree_serialize:
    ret

; `tree_encode_char` is a recursive helper procedure for `tree_encode_str` that encodes a single character
; by traversing the huffman tree. The tree parameter are taken in through the stack while the character
; parameter is passed in through the r14 register.
; 
; This procedure returns a boolean in the rax register based on whether the character has been found or not
; in the tree.
tree_encode_char:
    push rbp
    mov rbp, rsp

    ; Set default return value to false
    xor rax, rax
    
    ; Check if node is a leaf
    mov r15, [rbp + 16]
    cmp byte [r15], 0
    je .is_leaf

    ; Check if string has enough memory before writing to it
    cmp r11, r10
    jl .enough_mem

    push rax ; Save register to prepare for syscall

    ; Allocate more memory
    mov r15, 0x1000
    push r15
    push r10
    call mremap
    add rsp, 0x10 

    pop rax  ; Restore register after syscall

    ; Add 4096 bytes to total allocated bytes
    add r10, 0x1000

.enough_mem:
    ; If not a leaf...
    ; Handle left node
    mov byte [r12 + r11], 0x30 ; Write 0 to string for left node
    inc r11              ; Increase string length

    ; Traverse left node
    mov r15, [rbp + 16]
    mov r15, [r15 + 1]
    push r15
    call tree_encode_char
    add rsp, 0x8

    ; Check if already found character in left node
    cmp rax, 0x1
    je .exit

    ; Handle right node
    mov byte [r12 + r11 - 1], 0x31 ; Overwrite 0 with 1 since character was not found in left node

    ; Traverse right node
    mov r15, [rbp + 16] ; Retrieve node from parameter
    mov r15, [r15 + 9]  ; Retrieve right node of node
    push r15
    call tree_encode_char
    add rsp, 0x8

    cmp rax, 0x1
    je .exit 

    dec r11 ; Decrease string length in the case of character not found in this node
    jmp .exit

.is_leaf:
    mov r15, [rbp + 16]
    cmp byte [r15 + 1], r14b
    jne .exit

    ; Set return value to true since found character
    mov rax, 0x1

.exit:
    mov rsp, rbp
    pop rbp
    ret

tree_encode_str:
    push rbp
    mov rbp, rsp

    mov r13, rax        ; Retrieve tree parameter in r13
    mov rsi, [rbp + 16] ; Retrieve string parameter

    ; Clear counter register
    xor rcx, rcx

    ; Load the tree parameter for `tree_encode_char`
    push r13

; Loop through the string, character by character
.loop:
    mov r14b, byte [rsi + rcx] ; Retrieve current character
    cmp r14b, 0x0              ; Check if reached end of string
    je .exit
     
    ; Encode character in r14b
    call tree_encode_char

    inc rcx ; Move to next character
    jmp .loop

.exit:
    add rsp, 0x8 ; Clear parameter off stack
    mov rax, r12 ; Place the returning string in rax

    mov rsp, rbp
    pop rbp
    ret
