; broker_tcp.asm
; Broker central del sistema pub/sub sobre TCP.
; Acepta conexiones de publishers y subscribers.
; Reenvía cada mensaje de un publisher a todos los subscribers.
; Compilar: nasm -f elf64 broker_tcp.asm -o broker_tcp.o
; Linkear:  ld broker_tcp.o -o broker_tcp

section .data
    PORT        equ 5000          ; Puerto del broker
    MAX_CLIENTS equ 10            ; Máximo de clientes
    BUF_SIZE    equ 1024          ; Tamaño del buffer
    AF_INET     equ 2             ; IPv4
    SOCK_STREAM equ 1             ; TCP
    SOL_SOCKET  equ 1
    SO_REUSEADDR equ 2
    INADDR_ANY  equ 0

    ; Mensajes de log
    msg_listen  db "[BROKER TCP] Escuchando en puerto 5000...", 10
    msg_listen_len equ $ - msg_listen
    msg_publisher db "[BROKER TCP] Publisher conectado", 10
    msg_publisher_len equ $ - msg_publisher
    msg_subscriber db "[BROKER TCP] Subscriber conectado", 10
    msg_subscriber_len equ $ - msg_subscriber
    msg_received db "[BROKER TCP] Mensaje recibido y reenviado", 10
    msg_received_len equ $ - msg_received
    msg_disconnected db "[BROKER TCP] Cliente desconectado", 10
    msg_disconnected_len equ $ - msg_disconnected

section .bss
    server_fd   resd 1            ; File descriptor del servidor
    client_fd   resd 1            ; File descriptor del cliente actual
    opt_val     resd 1            ; Valor para setsockopt
    addr        resb 16           ; sockaddr_in (16 bytes)
    buf         resb 1024         ; Buffer de mensajes
    type_buf    resb 1            ; Buffer para tipo P o S
    ; Lista de subscribers (hasta MAX_CLIENTS)
    sub_list    resd 10
    sub_count   resd 1            ; Cantidad de subscribers activos

section .text
    global _start

; ─── Macro para imprimir string ───────────────────────────
%macro print 2
    mov rax, 1          ; syscall write
    mov rdi, 1          ; stdout
    mov rsi, %1         ; puntero al string
    mov rdx, %2         ; longitud
    syscall
%endmacro

; ─── Macro para llamar socket() ───────────────────────────
; socket(AF_INET, SOCK_STREAM, 0) → syscall 41
%macro make_socket 0
    mov rax, 41
    mov rdi, AF_INET
    mov rsi, SOCK_STREAM
    mov rdx, 0
    syscall
%endmacro

_start:
    ; ── 1. Crear socket TCP ──────────────────────────────
    make_socket
    mov [server_fd], eax        ; guardar fd del servidor

    ; ── 2. setsockopt: reusar puerto ────────────────────
    mov dword [opt_val], 1
    mov rax, 54                 ; syscall setsockopt
    mov edi, [server_fd]
    mov rsi, SOL_SOCKET
    mov rdx, SO_REUSEADDR
    lea r10, [opt_val]
    mov r8, 4
    syscall

    ; ── 3. Construir sockaddr_in ─────────────────────────
    ; struct sockaddr_in: sin_family(2), sin_port(2), sin_addr(4), pad(8)
    mov word [addr],     AF_INET     ; sin_family = 2
    mov word [addr+2],   0x8813      ; sin_port = htons(5000) = 0x1388 → big endian = 0x8813
    mov dword [addr+4],  INADDR_ANY  ; sin_addr = 0
    mov qword [addr+8],  0           ; padding

    ; ── 4. bind() ────────────────────────────────────────
    mov rax, 49                 ; syscall bind
    mov edi, [server_fd]
    lea rsi, [addr]
    mov rdx, 16
    syscall

    ; ── 5. listen() ──────────────────────────────────────
    mov rax, 50                 ; syscall listen
    mov edi, [server_fd]
    mov rsi, MAX_CLIENTS
    syscall

    print msg_listen, msg_listen_len

    ; Inicializar sub_count = 0
    mov dword [sub_count], 0

; ── 6. Bucle principal: accept() ─────────────────────────
accept_loop:
    mov rax, 43                 ; syscall accept
    mov edi, [server_fd]
    mov rsi, 0
    mov rdx, 0
    syscall
    mov [client_fd], eax        ; guardar fd del cliente

    ; ── 7. Leer primer byte: P o S ───────────────────────
    mov rax, 0                  ; syscall read
    mov edi, [client_fd]
    lea rsi, [type_buf]
    mov rdx, 1
    syscall

    ; ── 8. Verificar si es Publisher (P=0x50) ────────────
    cmp byte [type_buf], 0x50   ; 'P'
    je  handle_publisher

    ; ── 9. Si es Subscriber (S=0x53) ────────────────────
    cmp byte [type_buf], 0x53   ; 'S'
    je  handle_subscriber

    jmp accept_loop

; ── Manejo de Publisher ───────────────────────────────────
handle_publisher:
    print msg_publisher, msg_publisher_len

recv_loop:
    ; Recibir mensaje del publisher
    mov rax, 0                  ; syscall read
    mov edi, [client_fd]
    lea rsi, [buf]
    mov rdx, BUF_SIZE
    syscall

    cmp rax, 0                  ; si recibió 0 bytes, publisher cerró
    jle publisher_done

    mov r12, rax                ; guardar longitud del mensaje

    print msg_received, msg_received_len

    ; Reenviar a todos los subscribers
    mov ecx, [sub_count]
    test ecx, ecx
    jz recv_loop                ; si no hay subscribers, seguir recibiendo

    xor r13, r13                ; índice i = 0

broadcast_loop:
    cmp r13d, [sub_count]
    jge recv_loop               ; si i >= sub_count, terminar broadcast

    ; Calcular dirección: sub_list + i*4
    mov eax, r13d
    shl eax, 2                  ; i * 4 (cada fd es 4 bytes)
    lea rsi, [sub_list]
    add rsi, rax
    mov edi, [rsi]              ; fd del subscriber i

    ; send() al subscriber
    mov rax, 1                  ; syscall write
    mov rsi, buf
    mov rdx, r12                ; longitud del mensaje
    syscall

    inc r13d
    jmp broadcast_loop

publisher_done:
    print msg_disconnected, msg_disconnected_len
    ; Cerrar socket del publisher
    mov rax, 3                  ; syscall close
    mov edi, [client_fd]
    syscall
    jmp accept_loop

; ── Manejo de Subscriber ─────────────────────────────────
handle_subscriber:
    print msg_subscriber, msg_subscriber_len

    ; Agregar fd a sub_list
    mov ecx, [sub_count]
    mov eax, ecx
    shl eax, 2                  ; ecx * 4
    lea rsi, [sub_list]
    add rsi, rax
    mov edx, [client_fd]
    mov [rsi], edx              ; sub_list[sub_count] = client_fd

    inc dword [sub_count]       ; sub_count++

    jmp accept_loop             ; volver a aceptar más conexiones

; ── Salida del programa ───────────────────────────────────
exit:
    mov rax, 60                 ; syscall exit
    xor rdi, rdi
    syscall
