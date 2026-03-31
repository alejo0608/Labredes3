#include "comun.h"
#include <pthread.h> // Necesario para manejar múltiples clientes al tiempo

#define MAX_SUBS 100

// Estructura para registrar a cada suscriptor
typedef struct {
    int socket;
    char partido[30];
} RegistroSub;

RegistroSub tabla_subs[MAX_SUBS];
int total_subs = 0;
pthread_mutex_t candado = PTHREAD_MUTEX_INITIALIZER; // Protege la tabla de suscriptores

void *atender_cliente(void *arg) {
    int sock = *(int*)arg;
    free(arg);
    Mensaje msg;

// Bucle para recibir datos del cliente (sea publicador o suscriptor)
    while (recv(sock, &msg, sizeof(Mensaje), 0) > 0) {
        
        if (msg.tipo == SUSCRIBIR) {
            // Registra al suscritor en la tabla
            pthread_mutex_lock(&candado);
            if (total_subs < MAX_SUBS) {
                tabla_subs[total_subs].socket = sock;
                strcpy(tabla_subs[total_subs].partido, msg.partido);
                total_subs++;
                printf("Broker: Nuevo suscriptor para el partido [%s]\n", msg.partido);
            }
            pthread_mutex_unlock(&candado);
        } 
        else if (msg.tipo == NOTICIA) {
            // Reenvia el gol a los interesados
            printf("Broker: Noticia recibida de [%s]: %s\n", msg.partido, msg.contenido);
            
            pthread_mutex_lock(&candado);
            for (int i = 0; i < total_subs; i++) {
                // Si el partido coincide, le mandamos la noticia
                if (strcmp(tabla_subs[i].partido, msg.partido) == 0) {
                    send(tabla_subs[i].socket, &msg, sizeof(Mensaje), 0);
                }
            }
            pthread_mutex_unlock(&candado);
        }
    }

    close(sock);
    return NULL;
}

int main() {
    int servidor_fd, nuevo_sock;
    struct sockaddr_in direccion;
    int opt = 1;
    int addrlen = sizeof(direccion);

    // Crear socket TCP (SOCK_STREAM)
    servidor_fd = socket(AF_INET, SOCK_STREAM, 0);

    // Configuración para reutilizar el puerto si reinicias el programa rápido
    setsockopt(servidor_fd, SOL_SOCKET, SO_REUSEADDR, &opt, sizeof(opt));

    direccion.sin_family = AF_INET;
    direccion.sin_addr.s_addr = INADDR_ANY; // Escuchar en cualquier IP de la máquina
    direccion.sin_port = htons(PORT);       // Puerto 8080 traducido a Big Endian

    // Atar el socket y ponerse a escuchar
    bind(servidor_fd, (struct sockaddr *)&direccion, sizeof(direccion));
    listen(servidor_fd, 10);

    printf("Broker TCP deportivo iniciado en puerto %d...\n", PORT);

    while (1) {
        // Aceptar conexiones (Handshake TCP) 
        nuevo_sock = accept(servidor_fd, (struct sockaddr *)&direccion, (socklen_t*)&addrlen);
        
        // Crear un hilo para que el Broker no se bloquee con un solo cliente
        pthread_t hilo_id;
        int *p_sock = malloc(sizeof(int));
        *p_sock = nuevo_sock;
        pthread_create(&hilo_id, NULL, atender_cliente, p_sock);
        pthread_detach(hilo_id); // El hilo se libera solo al terminar
    }

    return 0;
}