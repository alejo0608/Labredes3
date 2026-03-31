#include "comun.h"

int main() {
    int sockfd;
    struct sockaddr_in servaddr;
    Mensaje msg;
    socklen_t len = sizeof(servaddr);

    sockfd = socket(AF_INET, SOCK_DGRAM, 0);

    memset(&servaddr, 0, sizeof(servaddr));
    servaddr.sin_family = AF_INET;
    servaddr.sin_port = htons(PORT);
    inet_pton(AF_INET, "127.0.0.1", &servaddr.sin_addr);

// Enviar suscripción para que el Broker guarde nuestra dirección
    msg.tipo = SUSCRIBIR;
    strcpy(msg.partido, "Colombia vs Brasil");
    sendto(sockfd, &msg, sizeof(Mensaje), 0, (const struct sockaddr *)&servaddr, len);
    printf("Suscrito vía UDP a: %s\n Esperando noticias...", msg.partido);

// Bucle de escucha
    while (1) {
        recvfrom(sockfd, &msg, sizeof(Mensaje), 0, NULL, NULL);
        printf("\n[UDP NOTICIA] %s: %s\n", msg.partido, msg.contenido);
    }

    close(sockfd);
    return 0;
}