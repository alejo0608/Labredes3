; publisher_tcp.asm
; Publicador del sistema pub/sub sobre TCP.
; Se conecta al broker y envía 10 mensajes de noticias deportivas.
; Compilar: nasm -f elf64 publisher_tcp.asm -o publisher_tcp.o
; Linkear:  ld publisher_tcp.o -o publisher_tcp

section .data
    BROKER_PORT equ 5000
    AF_INET     equ 2
    SOCK_STREAM equ 1

    ; IP del broker: 127.0.0.1
    ; En sockaddr_in se guarda como bytes: 127=0x7F, 0, 0, 1
    broker_ip   db 127, 0, 0, 1

    ; Identificador de tipo
    type_pub    db 'P'

    ; Mensajes deportivos (10 mensajes)
    msg0  db "[Partido1] Inicio del partido", 10
    msg0l equ $ - msg0
    msg1  db "[Partido1] Gol de Equipo A al minuto 12", 10
    msg1l equ $ - msg1
    msg2  db "[Partido1] Tarjeta amarilla al numero 7 de Equipo B", 10
    msg2l equ $ - msg2
    msg3  db "[Partido1] Gol de Equipo B al minuto 28 - Empate 1-1", 10
    msg3l equ $ - msg3
    msg4  db "[Partido1] Cambio: jugador 10 entra por jugador 5", 10
    msg4l equ $ - msg4
    msg5  db "[Partido1] Fin del primer tiempo", 10
    msg5l equ $ - msg5
    msg6  db "[Partido1] Inicio del segundo tiempo", 10
    msg6l equ $ - msg6
    msg7  db "[Partido1] Gol de Equipo A al minuto 67 - Equipo A gana 2-1", 10
    msg7l equ $ - msg7
    msg8  db "[Partido1] Tarjeta roja al numero 4 de Equipo B", 10
    msg8l equ $ - msg8
    msg9  db "[Partido1] Fin del partido - Resultado: Equipo A 2 - Equipo B 1", 10
    msg9l equ $ - msg9

    ; Tabla de punteros a mensajes
    msg_table   dq msg0, msg1, msg2, msg3, msg4, msg5, msg6, msg7, msg8, msg9
    len_table   dq msg0l, msg1l, msg2l, msg3l, msg4l, msg5l, msg6l, msg7l, msg8l, msg9l

    log_sending db "[PUBLISHER] Enviando mensaje...", 10
    log_len     equ $ - log_sending
    log_done    db "[PUBLISHER] Todos los mensajes enviados.", 10
    log_done_len equ $ - log_done

section .bss
    sock_fd     resd 1
    addr        resb 16

section .text
    global _start

%macro print 2
    mov rax, 1
    mov rdi, 1
    mov rsi, %1
    mov rdx, %2
    syscall
%endmacro

; sleep(n) usando syscall nanosleep
; Requiere timespec en stack: [segundos, nanosegundos]
%macro sleep_1sec 0
    sub rsp, 16
    mov qword [rsp],   1    ; segundos
    mov qword [rsp+8], 0    ; nanosegundos
    mov rax, 35             ; syscall nanosleep
    mov rdi, rsp
    mov rsi, 0
    syscall
    add rsp, 16
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
    mov word  [addr],   AF_INET     ; sin_family
    mov word  [addr+2], 0x8813      ; sin_port = htons(5000)
    ; sin_addr = 127.0.0.1
    mov byte  [addr+4], 127
    mov byte  [addr+5], 0
    mov byte  [addr+6], 0
    mov byte  [addr+7], 1
    mov qword [addr+8], 0           ; padding

    ; ── 3. connect() al broker ───────────────────────────
    mov rax, 42             ; syscall connect
    mov edi, [sock_fd]
    lea rsi, [addr]
    mov rdx, 16
    syscall

    ; ── 4. Identificarse como Publisher ─────────────────
    mov rax, 1              ; syscall write
    mov edi, [sock_fd]
    lea rsi, [type_pub]
    mov rdx, 1
    syscall

    ; ── 5. Enviar 10 mensajes ────────────────────────────
    xor r12, r12            ; i = 0

send_loop:
    cmp r12, 10
    jge send_done

    print log_sending, log_len

    ; Obtener puntero al mensaje i
    mov rax, r12
    shl rax, 3              ; i * 8 (punteros son 8 bytes)
    lea rbx, [msg_table]
    add rbx, rax
    mov rsi, [rbx]          ; puntero al mensaje

    ; Obtener longitud del mensaje i
    lea rbx, [len_table]
    add rbx, rax
    mov rdx, [rbx]          ; longitud

    ; send() al broker
    mov rax, 1              ; syscall write
    mov edi, [sock_fd]
    syscall

    sleep_1sec              ; esperar 1 segundo

    inc r12
    jmp send_loop

send_done:
    print log_done, log_done_len

    ; ── 6. Cerrar socket ─────────────────────────────────
    mov rax, 3              ; syscall close
    mov edi, [sock_fd]
    syscall

    ; ── 7. Salir ─────────────────────────────────────────
    mov rax, 60
    xor rdi, rdi
    syscall
