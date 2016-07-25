global start

section .data
    sys_write: equ 0x2000004 
    sys_brk: equ 0x2000069

    err_insufficient_args: db "Insufficient arguments", 0xA

section .text
start:
    ; Check for neccesary arguments
    mov rdx, [rsp]
    cmp rdx, 2
    jl insufficient_args

    add rsp, 16 
    call count

    jmp exit

; Count occurences of each character in the string
count:
    push rbp
    mov rbp, rsp
     
    ; Retrieve string argument
    mov rsi, [rbp + 16]


    ; Clear counter register
    xor ecx, ecx

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
