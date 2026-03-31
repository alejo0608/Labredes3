; subscriber_tcp.asm
; Suscriptor del sistema pub/sub sobre TCP.
; Se conecta al broker y queda escuchando mensajes indefinidamente.
; Compilar: nasm -f elf64 subscriber_tcp.asm -o subscriber_tcp.o
; Linkear:  ld subscriber_tcp.o -o subscriber_tcp

section .data
    BROKER_PORT equ 5000
    AF_INET     equ 2
    SOCK_STREAM equ 1

    type_sub    db 'S'

    log_connect db "[SUBSCRIBER] Conectado. Esperando mensajes...", 10
    log_connect_len equ $ - log_connect
    log_received db "[SUBSCRIBER] Recibido: "
    log_received_len equ $ - log_received
    log_closed  db "[SUBSCRIBER] Conexion cerrada.", 10
    log_closed_len equ $ - log_closed

section .bss
    sock_fd     resd 1
    addr        resb 16
    buf         resb 1024

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
    ; ── 1. Crear socket TCP ──────────────────────────────
    mov rax, 41             ; syscall socket
    mov rdi, AF_INET
    mov rsi, SOCK_STREAM
    mov rdx, 0
    syscall
    mov [sock_fd], eax

    ; ── 2. Construir sockaddr_in del broker ──────────────
    mov word  [addr],   AF_INET
    mov word  [addr+2], 0x8813      ; htons(5000)
    mov byte  [addr+4], 127
    mov byte  [addr+5], 0
    mov byte  [addr+6], 0
    mov byte  [addr+7], 1
    mov qword [addr+8], 0

    ; ── 3. connect() al broker ───────────────────────────
    mov rax, 42             ; syscall connect
    mov edi, [sock_fd]
    lea rsi, [addr]
    mov rdx, 16
    syscall

    ; ── 4. Identificarse como Subscriber ────────────────
    mov rax, 1              ; syscall write
    mov edi, [sock_fd]
    lea rsi, [type_sub]
    mov rdx, 1
    syscall

    print log_connect, log_connect_len

; ── 5. Bucle de recepción ─────────────────────────────────
recv_loop:
    mov rax, 0              ; syscall read
    mov edi, [sock_fd]
    lea rsi, [buf]
    mov rdx, 1024
    syscall

    cmp rax, 0              ; si recibió 0 bytes, conexión cerrada
    jle recv_done

    mov r12, rax            ; guardar longitud recibida

    ; Imprimir prefijo
    print log_received, log_received_len

    ; Imprimir mensaje recibido
    mov rax, 1
    mov rdi, 1
    lea rsi, [buf]
    mov rdx, r12
    syscall

    jmp recv_loop

recv_done:
    print log_closed, log_closed_len

    ; ── 6. Cerrar socket ─────────────────────────────────
    mov rax, 3
    mov edi, [sock_fd]
    syscall

    ; ── 7. Salir ─────────────────────────────────────────
    mov rax, 60
    xor rdi, rdi
    syscall
