global start

section .data
    sys_write: equ 0x2000004 
    sys_mmap: equ 0x20000C5

    err_insufficient_args: db "Insufficient arguments", 0xA

section .text
start:
    ; Check for neccesary arguments
    mov rdx, [rsp]
    cmp rdx, 2
    jl insufficient_args

    ; Skip over argc and argc[0]
    add rsp, 16 
    call count

    jmp exit

; Count occurences of each character in the string
count:
    push rbp
    mov rbp, rsp
     
    ; Allocate memory 
    mov rax, sys_mmap
    xor rdi, rdi
    mov rsi, 0x36   ; 54 bytes
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

count_loop:
    ; Loop through each letter and build map on letter frequencies
    mov dl, [rsi + rcx] ; Fetch current letter to process
    cmp dl, 0    ; Check if null character
    je count_exit

    push rcx             ; Save counter to prepare for inner loop
    xor rcx, rcx         ; Start count at zero

; Search if map has existing entry for this letter
count_search_loop:
    cmp dword [rax], ecx ; Check if reached end of map
    je count_search_add  ; Jump to create new map entry

    ; Calculate address of letter 
    imul rbx, rcx, 0x5
    add rbx, rax 
    add rbx, 0x4

    cmp dl, byte [rbx]     ; Check if letters are equal
    jne count_search_continue

    inc rbx

    ; Found existing map entry for the letter, so add one to the frequency count
    mov r8d, dword [rbx]
    inc r8d 
    mov [rbx], r8d 
    jmp count_search_exit

count_search_continue:
    inc ecx ; Move to next map entry
    jmp count_search_loop

; Create new map entry { char, int }
count_search_add:
    ; Increase map length
    mov ebx, [rax]
    inc ebx
    mov [rax], dword ebx

    imul rbx, rcx, 0x5
    add rbx, rax 
    add rbx, 0x4

    ; Set map entry data
    mov [rbx], dl
    inc rbx
    mov dword [rbx], 0x1

count_search_exit:
    pop rcx ; Restore counter register for outer loop (letters loop)
    inc rcx ; Move to next letter 
    jmp count_loop

count_exit:
    mov rsp, rbp
    pop rbp
    ret

; Create cipher
create_key:

    ret

; Encode string using cipher
encode:

    ret

; Print out error for insufficient arguments 
insufficient_args:
    mov rax, sys_write 
    mov rdi, 1
    mov rsi, err_insufficient_args
    mov rdx, 23
    syscall
    jmp exit

exit:
    mov     rax, 0x2000001 ; exit
    mov     rdi, 0
    syscall
