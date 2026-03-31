#include "comun.h"

int main() {
    int sock = 0;
    struct sockaddr_in serv_addr; 
// "serv_addr sirve para guardar los datos críticos (la familia, el puerto, IP)
//sockaddr sirve**** "
    Mensaje msg; // estructura universal q se definio en el intermediario

// Crear el socket usando TCP orientado a conexión
    if ((sock = socket(AF_INET, SOCK_STREAM, 0)) < 0) {
        printf("\n Error en creación de socket \n");
        return -1;
    }

//Configuracon del socket destino se usa una estructura específica
    serv_addr.sin_family = AF_INET; // se define la famlia de direcciones IPv4 que se usarán
    serv_addr.sin_port = htons(PORT); //almacena bytes en formate Big Endian

//Convertir dirección IP a binario. 
    if (inet_pton(AF_INET, "127.0.0.1", &serv_addr.sin_addr) <= 0) {
        printf("\nDirección inválida\n");
        return -1;
    }

//Conectarse al Broker, inicia el 3-Way Handshake
    if (connect(sock, (struct sockaddr *)&serv_addr, sizeof(serv_addr)) < 0) {
        printf("\nConexión fallida\n");
        return -1;
    }

    printf("Conectado al Broker. Enviando noticias...\n");

// Ciclo para enviar los 10 mensajes requeridos
    for (int i = 1; i <= 10; i++) {
        msg.tipo = NOTICIA; // Etiquetamos como periodista [cite: 76]
        strcpy(msg.partido, "Colombia vs Brasil");
        sprintf(msg.contenido, "Evento deportivo #%d: ¡Acción en el campo!", i);

//Enviar la estructura completa
        send(sock, &msg, sizeof(Mensaje), 0);
        
        printf("Enviado: %s\n", msg.contenido);

//Esperamos 1 segundo entre mensajes para que Wireshark los capture bien
        sleep(1); 
    }

//Cerrar conexión
    close(sock);
    printf("Transmisión finalizada.\n");

    return 0;
}