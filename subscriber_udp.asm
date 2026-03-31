; subscriber_udp.asm
; Suscriptor del sistema pub/sub sobre UDP.
; Se registra en el broker mandando un datagrama con 'S'.
; Escucha en puerto 5002.
; Compilar: nasm -f elf64 subscriber_udp.asm -o subscriber_udp.o
; Linkear:  ld subscriber_udp.o -o subscriber_udp

section .data
    AF_INET      equ 2
    SOCK_DGRAM   equ 2
    SOL_SOCKET   equ 1
    SO_REUSEADDR equ 2
    INADDR_ANY   equ 0

    type_sub      db 'S'

    log_register  db "[SUBSCRIBER UDP] Registrado en broker. Esperando mensajes...", 10
    log_reg_len   equ $ - log_register
    log_received  db "[SUBSCRIBER UDP] Recibido: "
    log_recv_len  equ $ - log_received
    log_closed    db "[SUBSCRIBER UDP] Fin.", 10
    log_closed_len equ $ - log_closed

section .bss
    sock_fd      resd 1
    opt_val      resd 1
    my_addr      resb 16
    broker_addr  resb 16
    sender_addr  resb 16
    sender_len   resd 1
    buf          resb 1024

section .text
    global _start

%macro print 2
    mov rax, 1
    mov rdi, 1
    mov rsi, %1
    mov rdx, %2
    syscall
%endmacro

_start:
    ; ── 1. Crear socket UDP ──────────────────────────────
    mov rax, 41
    mov rdi, AF_INET
    mov rsi, SOCK_DGRAM
    mov rdx, 0
    syscall
    mov [sock_fd], eax

    ; ── 2. setsockopt ────────────────────────────────────
    mov dword [opt_val], 1
    mov rax, 54
    mov edi, [sock_fd]
    mov rsi, SOL_SOCKET
    mov rdx, SO_REUSEADDR
    lea r10, [opt_val]
    mov r8, 4
    syscall

    ; ── 3. Bind en puerto 5002 ───────────────────────────
    mov word  [my_addr],   AF_INET
    mov word  [my_addr+2], 0x8A13
    mov dword [my_addr+4], INADDR_ANY
    mov qword [my_addr+8], 0

    mov rax, 49
    mov edi, [sock_fd]
    lea rsi, [my_addr]
    mov rdx, 16
    syscall

    ; ── 4. Construir sockaddr_in del broker ──────────────
    mov word  [broker_addr],   AF_INET
    mov word  [broker_addr+2], 0x9113
    mov byte  [broker_addr+4], 127
    mov byte  [broker_addr+5], 0
    mov byte  [broker_addr+6], 0
    mov byte  [broker_addr+7], 1
    mov qword [broker_addr+8], 0

    ; ── 5. Registrarse mandando 'S' al broker ────────────
    mov rax, 44
    mov edi, [sock_fd]
    lea rsi, [type_sub]
    mov rdx, 1
    mov r10, 0
    lea r8,  [broker_addr]
    mov r9,  16
    syscall

    print log_register, log_reg_len

recv_loop:
    mov dword [sender_len], 16

    mov rax, 45
    mov edi, [sock_fd]
    lea rsi, [buf]
    mov rdx, 1024
    mov r10, 0
    lea r8,  [sender_addr]
    lea r9,  [sender_len]
    syscall

    cmp rax, 0
    jle recv_done

    mov r12, rax

    print log_received, log_recv_len

    mov rax, 1
    mov rdi, 1
    lea rsi, [buf]
    mov rdx, r12
    syscall

    jmp recv_loop

recv_done:
    print log_closed, log_closed_len

    mov rax, 3
    mov edi, [sock_fd]
    syscall

    mov rax, 60
    xor rdi, rdi
    syscall
