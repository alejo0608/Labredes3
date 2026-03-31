#include "comun.h"

int main() {
    int sock = 0;
    struct sockaddr_in serv_addr;
    Mensaje msg; // Estructura universal de comun.h

// Crear el socket TCP (SOCK_STREAM)
    if ((sock = socket(AF_INET, SOCK_STREAM, 0)) < 0) {
        printf("\n Error en la creación del socket \n");
        return -1;
    }

// Configurar el "sobre" (serv_addr)
    serv_addr.sin_family = AF_INET;
    serv_addr.sin_port = htons(PORT); // traducción a Big Endian

// Traduce IP de texto a binario 
    if (inet_pton(AF_INET, "127.0.0.1", &serv_addr.sin_addr) <= 0) {
        printf("\nDirección IP inválida o no soportada \n");
        return -1;
    }

    // Conectar al Broker (Inicia el 3-Way Handshake)
    if (connect(sock, (struct sockaddr *)&serv_addr, sizeof(serv_addr)) < 0) {
        printf("\nConexión fallida. ¿Está el Broker encendido?\n");
        return -1;
    }

//PASO CLAVE: Suscribirse a un partido
    msg.tipo = SUSCRIBIR; // etiqueta con el rol de Suscriptor
    strcpy(msg.partido, "Colombia vs Brasil");
    memset(msg.contenido, 0, MAX_TEXT); // contenido vacío, solo nos interesa el "Tema" 

    send(sock, &msg, sizeof(Mensaje), 0);
    printf("Suscrito con éxito al partido: %s\n", msg.partido);
    printf("Esperando actualizaciones en vivo...\n");

// Bucle de recepción: El hincha se queda "escuchando el radio"
    // recv() se bloquea hasta que el Broker mande una noticia 
    while (recv(sock, &msg, sizeof(Mensaje), 0) > 0) {
        if (msg.tipo == NOTICIA) {
            printf("\n--- NUEVA ACTUALIZACIÓN --- \n");
            printf("Partido: %s\n", msg.partido);
            printf("Evento:  %s\n", msg.contenido);
            printf("---------------------------\n");
        }
    }

    // Si recv devuelve 0 o menor, significa que el Broker cerró la conexión
    printf("\nConexión perdida con el Broker.\n");
    close(sock);

    return 0;
}