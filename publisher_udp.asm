; publisher_udp.asm
; Publicador del sistema pub/sub sobre UDP.
; No establece conexion — envia datagramas directamente al broker.
; Compilar: nasm -f elf64 publisher_udp.asm -o publisher_udp.o
; Linkear:  ld publisher_udp.o -o publisher_udp

section .data
    AF_INET     equ 2
    SOCK_DGRAM  equ 2

    msg0  db "P[Partido2] Inicio del partido", 10
    msg0l equ $ - msg0
    msg1  db "P[Partido2] Gol de Equipo C al minuto 8", 10
    msg1l equ $ - msg1
    msg2  db "P[Partido2] Tarjeta amarilla al numero 3 de Equipo D", 10
    msg2l equ $ - msg2
    msg3  db "P[Partido2] Gol de Equipo D al minuto 35 - Empate 1-1", 10
    msg3l equ $ - msg3
    msg4  db "P[Partido2] Cambio: jugador 9 entra por jugador 11", 10
    msg4l equ $ - msg4
    msg5  db "P[Partido2] Fin del primer tiempo", 10
    msg5l equ $ - msg5
    msg6  db "P[Partido2] Inicio del segundo tiempo", 10
    msg6l equ $ - msg6
    msg7  db "P[Partido2] Gol de Equipo C al minuto 71 - Equipo C gana 2-1", 10
    msg7l equ $ - msg7
    msg8  db "P[Partido2] Tarjeta roja al numero 2 de Equipo D", 10
    msg8l equ $ - msg8
    msg9  db "P[Partido2] Fin del partido - Resultado: Equipo C 2 - Equipo D 1", 10
    msg9l equ $ - msg9

    msg_table  dq msg0, msg1, msg2, msg3, msg4, msg5, msg6, msg7, msg8, msg9
    len_table  dq msg0l, msg1l, msg2l, msg3l, msg4l, msg5l, msg6l, msg7l, msg8l, msg9l

    log_sending  db "[PUBLISHER UDP] Enviando mensaje...", 10
    log_send_len equ $ - log_sending
    log_done     db "[PUBLISHER UDP] Todos los mensajes enviados.", 10
    log_done_len equ $ - log_done

section .bss
    sock_fd     resd 1
    broker_addr resb 16

section .text
    global _start

%macro print 2
    mov rax, 1
    mov rdi, 1
    mov rsi, %1
    mov rdx, %2
    syscall
%endmacro

%macro sleep_1sec 0
    sub rsp, 16
    mov qword [rsp],   1
    mov qword [rsp+8], 0
    mov rax, 35
    mov rdi, rsp
    mov rsi, 0
    syscall
    add rsp, 16
%endmacro

_start:
    mov rax, 41
    mov rdi, AF_INET
    mov rsi, SOCK_DGRAM
    mov rdx, 0
    syscall
    mov [sock_fd], eax

    mov word  [broker_addr],   AF_INET
    mov word  [broker_addr+2], 0x9113
    mov byte  [broker_addr+4], 127
    mov byte  [broker_addr+5], 0
    mov byte  [broker_addr+6], 0
    mov byte  [broker_addr+7], 1
    mov qword [broker_addr+8], 0

    xor r12, r12

send_loop:
    cmp r12, 10
    jge send_done

    print log_sending, log_send_len

    mov rax, r12
    shl rax, 3
    lea rbx, [msg_table]
    add rbx, rax
    mov rsi, [rbx]

    lea rbx, [len_table]
    add rbx, rax
    mov rdx, [rbx]

    mov rax, 44
    mov edi, [sock_fd]
    mov r10, 0
    lea r8,  [broker_addr]
    mov r9,  16
    syscall

    sleep_1sec

    inc r12
    jmp send_loop

send_done:
    print log_done, log_done_len

    mov rax, 3
    mov edi, [sock_fd]
    syscall

    mov rax, 60
    xor rdi, rdi
    syscall
