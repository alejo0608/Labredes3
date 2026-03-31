#include "comun.h"

#define MAX_SUBS 100

typedef struct {
    struct sockaddr_in addr;
    char partido[30];
} RegistroSubUDP;

RegistroSubUDP tabla_subs[MAX_SUBS];
int total_subs = 0;

int main() {
    int sockfd;
    struct sockaddr_in servaddr, cliaddr;
    Mensaje msg;
    socklen_t len = sizeof(cliaddr);

//Crear socket UDP (SOCK_DGRAM) 
    sockfd = socket(AF_INET, SOCK_DGRAM, 0);

    memset(&servaddr, 0, sizeof(servaddr));
    servaddr.sin_family = AF_INET;
    servaddr.sin_addr.s_addr = INADDR_ANY;
    servaddr.sin_port = htons(PORT);

//Atar el socket al puerto
    bind(sockfd, (const struct sockaddr *)&servaddr, sizeof(servaddr));

    printf("Broker UDP deportivo iniciado en puerto %d...\n", PORT);

    while (1) {
        // Recibir cualquier datagrama (recvfrom)
        recvfrom(sockfd, &msg, sizeof(Mensaje), 0, (struct sockaddr *)&cliaddr, &len);

        if (msg.tipo == SUSCRIBIR) {
            // Guardamos la dirección del cliente para saber a dónde enviar noticias después
            tabla_subs[total_subs].addr = cliaddr;
            strcpy(tabla_subs[total_subs].partido, msg.partido);
            total_subs++;
            printf("Broker UDP: Nueva suscripción para [%s]\n", msg.partido);
        } 
        else if (msg.tipo == NOTICIA) {
            printf("Broker UDP: Noticia recibida de [%s]\n", msg.partido);
            // Reenviar noticia a los interesados (sendto)
            for (int i = 0; i < total_subs; i++) {
                if (strcmp(tabla_subs[i].partido, msg.partido) == 0) {
                    sendto(sockfd, &msg, sizeof(Mensaje), 0, 
                           (struct sockaddr *)&tabla_subs[i].addr, len);
                }
            }
        }
    }
    return 0;
}