// config.h: pines, parámetros del motor y del encoder, y constantes del controlador difuso.
// Todos los archivos usan este mismo archivo.
#pragma once

#include <Arduino.h>

// ===================================================== Pines del ESP32
// Mismo cableado que el proyecto del péndulo; lo único nuevo es el potenciómetro.
const int PIN_ENCODER_A = 32;      // cable verde del encoder
const int PIN_ENCODER_B = 33;      // cable blanco del encoder
const int PIN_STEP = 25;           // pulso de paso al driver DRV8825
const int PIN_DIR = 26;            // dirección al driver
const int PIN_ENABLE = 27;         // habilita el driver (activo en bajo)
const int PIN_POTENCIOMETRO = 34;  // cursor del potenciómetro de 10 kΩ (ADC1, canal 6; pin solo de entrada)

// ===================================================== Potenciómetro (ADC)
// false: sin potenciómetro conectado. El valor de pot se escribe por serial con el comando P
// (por ejemplo "P512"). Con el pin 34 al aire el ADC lee valores al azar y el motor se movería solo.
// true: se lee el potenciómetro real en el pin 34.
const bool USAR_POTENCIOMETRO = false;
const float ADC_MAXIMO = 4095.0;  // ADC de 12 bits
const float POT_MAXIMO = 1023.0;  // escala de la práctica: pot = adc * 1023 / 4095

// ===================================================== Motor (DRV8825 + NEMA 17)
const int MICROPASOS = 8;                           // M0 = M1 = 3.3 V, M2 = GND: 1/8 de paso (sin cambios)
const float PASOS_POR_VUELTA = 200.0 * MICROPASOS;  // 200 pasos del motor x 8 = 1600 pasos/vuelta
const float RPM_MAX = 300.0;   // rpm para pwm = 255. Bajarlo si el motor pierde pasos
const float RPM_MINIMA = 1.0;  // por debajo de esto se detienen los pulsos

// ===================================================== Encoder (acoplado al eje del motor)
const int CUENTAS_POR_VUELTA = 2400;  // 600 PPR x 4 (cuadratura completa)
const int FILTRO_ENCODER = 1023;      // filtro de hardware del PCNT: ignora pulsos < 12.8 us
const bool PULLUP_INTERNA = true;     // pull-ups internas del ESP32, como en el péndulo
const bool ENCODER_INVERTIDO = true;  // true: con el encoder acoplado al motor, rpm_enc salía negativa (prueba en hardware)

// ===================================================== Lazo de velocidad (lazo abierto)
const float T = 0.01;           // periodo de control [s] (10 ms)
const float TAU_FILTRO = 0.2;   // constante de tiempo del filtro de primer orden de la velocidad [s]
const int PERIODOS_POR_REPORTE = 10;  // CSV y medición de rpm cada 10 x 10 ms = 100 ms

// ===================================================== Prueba escalón (comando S)
const float PWM_ESCALON = 200.0;      // pwm de 0 a 200 de golpe
const int MUESTRAS_ESCALON = 200;     // 2 s / 10 ms
const int PERIODOS_REPOSO = 50;       // antes del escalón: 0.5 s con el motor ya detenido

// ===================================================== Controlador difuso (igual al de MATLAB)
const int NUM_CONJUNTOS = 5;  // 5 conjuntos de entrada, 5 de salida y 5 reglas

// Entrada pot, universo [0, 1023]: triangulares [c - 255.75, c, c + 255.75]
const float CENTROS_ENTRADA[NUM_CONJUNTOS] = {0.0, 255.75, 511.5, 767.25, 1023.0};
const float ANCHO_ENTRADA = 255.75;

// Salida pwm, universo [-63.75, 318.75]: triangulares [c - 63.75, c, c + 63.75]
const float CENTROS_SALIDA[NUM_CONJUNTOS] = {0.0, 63.75, 127.5, 191.25, 255.0};
const float ANCHO_SALIDA = 63.75;
const float SALIDA_MINIMA = -63.75;  // universo de salida
const float SALIDA_MAXIMA = 318.75;
const int PUNTOS_CENTROIDE = 101;    // centroide discreto con 101 puntos (lo mismo que usa MATLAB)
const float PWM_MAXIMO = 255.0;      // el resultado se satura a [0, 255]
