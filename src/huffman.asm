global start

section .data
    sys_write: equ 0x2000004 
    sys_exit:  equ 0x2000001
    sys_mmap:  equ 0x20000C5

    err_insufficient_args: db "Insufficient arguments", 0xA
    .len: equ $ - err_insufficient_args
    err_invalid_action: db "Invalid action", 0xA
    .len: equ $ - err_invalid_action

    newline: db 0xA

section .text

%include "src/syscalls.asm"

start:
    ; Check for neccesary arguments
    mov rdx, [rsp]
    cmp rdx, 3 
    jl insufficient_args

    ; Skip over argc and argv[0]
    add rsp, 0x10
    ; Retrieve action (either encode or decode)
    pop rdx

    ; Check for encode action
    cmp byte [rdx], 0x65
    je .encode

    ; Check for decode action
    cmp byte [rdx], 0x64
    jne invalid_action 
 
.decode:
    call decode
    jmp exit

.encode:
    call encode
    jmp exit

%include "src/tree.asm"
%include "src/encode.asm"
%include "src/decode.asm"

print_line:
    mov r15, 0x1
    push r15
    mov r15, newline
    push r15
    call print
    add rsp, 0x10
    ret


; Print out error for invalid action 
invalid_action:
    mov rax, sys_write 
    mov rdi, 1 
    mov rsi, err_invalid_action
    mov rdx, err_invalid_action.len
    syscall
    jmp exit

; Print out error for insufficient arguments 
insufficient_args:
    mov rax, sys_write 
    mov rdi, 1 
    mov rsi, err_insufficient_args
    mov rdx, err_insufficient_args.len
    syscall
    jmp exit

exit:
    mov rax, sys_exit ; exit
    mov rdi, 0x0
    syscall
