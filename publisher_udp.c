#include "comun.h"

int main() {
    int sockfd;
    struct sockaddr_in servaddr;
    Mensaje msg;

    sockfd = socket(AF_INET, SOCK_DGRAM, 0);

    memset(&servaddr, 0, sizeof(servaddr));
    servaddr.sin_family = AF_INET;
    servaddr.sin_port = htons(PORT);
    inet_pton(AF_INET, "127.0.0.1", &servaddr.sin_addr);

    for (int i = 1; i <= 10; i++) {
        msg.tipo = NOTICIA;
        strcpy(msg.partido, "Colombia vs Brasil");
        sprintf(msg.contenido, "UDP Gol #%d - ¡Velocidad pura!", i);

        // Enviamos sin necesidad de connect()
        sendto(sockfd, &msg, sizeof(Mensaje), 0, (const struct sockaddr *)&servaddr, sizeof(servaddr));
        printf("Enviado por UDP: %s\n", msg.contenido);
        sleep(1);
    }

    close(sockfd);
    return 0;
}