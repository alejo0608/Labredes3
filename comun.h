//Evitan q el compilador lea el mismo archivo dos veces
#ifndef COMUN_H
#define COMUN_H

//librerias
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <arpa/inet.h> //Contiene las funciones de red para manejar direcciones IP y sockets en Linux

#define PORT 8080 // Puerto por el q odos los datos entran
#define MAX_TEXT 100 // Límite de letras que puede contener un mensaje

//se definen los roles suscriptor y periodista
typedef enum { SUSCRIBIR, NOTICIA } TipoMsg; //enum etiqueta o sea hace q los primeros bytes le digan al receptor que intención tiene el emisor

typedef struct {
    TipoMsg tipo;
    char partido[30];    // Tema: equipo A vs equipo B
    char evento[MAX_TEXT]; // Contenido: gol al minuto 32
} Mensaje;

#endif

