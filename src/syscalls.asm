%macro stackpush 0
    push rdi
    push rsi
    push rdx
    push r10
    push r8
    push r9 
    push r11
    push rcx
%endmacro

%macro stackpop 0
    pop rcx
    pop r11
    pop r9
    pop r8
    pop r10
    pop rdx
    pop rsi
    pop rdi
%endmacro

; Call mmap
mmap:
    push rbp
    mov rbp, rsp

    stackpush

    mov rax, sys_mmap
    xor rdi, rdi
    mov rsi, [rbp + 16] ; Retrieve size from arguments
    mov rdx, 0x3       ; READ and WRITE access
    mov r10, 0x1002    ; PRIVATE and ANON flag 
    mov r8, -0x1       ; No file backing
    xor r9, r9         ; No offset
    syscall

    stackpop

    mov rsp, rbp
    pop rbp
    ret

; Expand mmap
mremap:
    push rbp
    mov rbp, rsp

    stackpush

    mov rax, sys_mmap
    mov rdi, [rbp + 16] ; Retrieve mem location from arguments
    mov rsi, [rbp + 24] ; Retrieve size from arguments
    mov rdx, 0x3        ; READ and WRITE access
    mov r10, 0x1002     ; PRIVATE and ANON flag 
    mov r8, -0x1        ; No file backing
    xor r9, r9          ; No offset
    syscall

    stackpop

    mov rsp, rbp
    pop rbp
    ret

; Print
print:
    push rbp
    mov rbp, rsp

    stackpush

    mov rax, sys_write
    mov rdi, 1
    mov rsi, [rbp + 16]
    mov rdx, [rbp + 24]
    syscall

    stackpop

    mov rsp, rbp
    pop rbp
    ret
