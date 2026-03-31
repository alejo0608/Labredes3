; broker_udp.asm
; Broker central del sistema pub/sub sobre UDP.
; No hay conexiones persistentes — cada mensaje es un datagrama independiente.
; Los subscribers se registran mandando "S" al broker.
; Los publishers mandan mensajes precedidos de "P".
; Simula perdida: descarta 1 de cada 4 mensajes (drop_counter).
; Compilar: nasm -f elf64 broker_udp.asm -o broker_udp.o
; Linkear:  ld broker_udp.o -o broker_udp

section .data
    AF_INET     equ 2
    SOCK_DGRAM  equ 2
    INADDR_ANY  equ 0
    SOL_SOCKET  equ 1
    SO_REUSEADDR equ 2

    msg_listen      db "[BROKER UDP] Escuchando en puerto 5001...", 10
    msg_listen_len  equ $ - msg_listen
    msg_sub_reg     db "[BROKER UDP] Subscriber registrado", 10
    msg_sub_reg_len equ $ - msg_sub_reg
    msg_forwarded   db "[BROKER UDP] Mensaje reenviado", 10
    msg_forwarded_len equ $ - msg_forwarded
    msg_dropped     db "[BROKER UDP] *** Mensaje DESCARTADO (simulando perdida UDP) ***", 10
    msg_dropped_len equ $ - msg_dropped

section .bss
    sock_fd      resd 1
    opt_val      resd 1
    addr         resb 16
    client_addr  resb 16
    client_len   resd 1
    buf          resb 1024
    bytes_recv   resq 1
    sub_addrs    resb 160
    sub_count    resd 1
    drop_counter resd 1

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

    ; ── 3. Construir sockaddr_in ─────────────────────────
    mov word  [addr],   AF_INET
    mov word  [addr+2], 0x9113
    mov dword [addr+4], INADDR_ANY
    mov qword [addr+8], 0

    ; ── 4. bind() ────────────────────────────────────────
    mov rax, 49
    mov edi, [sock_fd]
    lea rsi, [addr]
    mov rdx, 16
    syscall

    print msg_listen, msg_listen_len

    mov dword [sub_count],    0
    mov dword [drop_counter], 0

recv_loop:
    mov dword [client_len], 16
    mov rax, 45
    mov edi, [sock_fd]
    lea rsi, [buf]
    mov rdx, 1024
    mov r10, 0
    lea r8,  [client_addr]
    lea r9,  [client_len]
    syscall
    mov [bytes_recv], rax

    cmp byte [buf], 0x53
    je  register_subscriber
    cmp byte [buf], 0x50
    je  handle_message
    jmp recv_loop

register_subscriber:
    print msg_sub_reg, msg_sub_reg_len

    mov ecx, [sub_count]
    imul ecx, 16
    lea rdi, [sub_addrs]
    add rdi, rcx
    lea rsi, [client_addr]
    mov rax, [rsi]
    mov [rdi], rax
    mov rax, [rsi+8]
    mov [rdi+8], rax

    inc dword [sub_count]
    jmp recv_loop

handle_message:
    inc dword [drop_counter]
    mov eax, [drop_counter]
    cmp eax, 4
    jne forward_message

    mov dword [drop_counter], 0
    print msg_dropped, msg_dropped_len
    jmp recv_loop

forward_message:
    print msg_forwarded, msg_forwarded_len

    xor r13, r13

broadcast_loop:
    mov eax, [sub_count]
    cmp r13d, eax
    jge recv_loop

    mov eax, r13d
    imul eax, 16
    lea r8, [sub_addrs]
    add r8, rax

    mov rax, 44
    mov edi, [sock_fd]
    lea rsi, [buf]
    mov rdx, [bytes_recv]
    mov r10, 0
    mov r9,  16
    syscall

    inc r13d
    jmp broadcast_loop

exit:
    mov rax, 60
    xor rdi, rdi
    syscall
