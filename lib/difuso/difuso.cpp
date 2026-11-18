// difuso.cpp: controlador difuso Mamdani, implementado a mano (sin librería) para que
// haga exactamente lo mismo que el diseño en MATLAB:
//   fusificación con triangulares -> 5 reglas (conjunto i -> conjunto i) -> implicación min
//   -> agregación max -> centroide discreto con 101 puntos -> saturación a [0, 255].

#include "difuso.h"

#include <math.h>

#include "config.h"

float triangular(float x, float a, float b, float c) {
  if (x <= a || x >= c) return 0.0;      // fuera del triángulo
  if (x <= b) return (x - a) / (b - a);  // lado de subida
  return (c - x) / (c - b);              // lado de bajada
}

float controlDifuso(float pot) {
  // 1) Fusificación: grado de pertenencia de pot a cada conjunto de entrada
  float grado[NUM_CONJUNTOS];
  for (int i = 0; i < NUM_CONJUNTOS; i++) {
    float centro = CENTROS_ENTRADA[i];
    grado[i] = triangular(pot, centro - ANCHO_ENTRADA, centro, centro + ANCHO_ENTRADA);
  }

  // 2) a 4) Se recorre el universo de salida en 101 puntos uniformes. En cada punto x:
  //   - regla i: "si pot es conjunto i, entonces pwm es conjunto i"
  //   - implicación min: el conjunto de salida i se recorta a la altura grado[i]
  //   - agregación max: se queda la mayor de las 5 salidas recortadas
  //   - centroide: suma(x · μ(x)) / suma(μ(x))
  float paso = (SALIDA_MAXIMA - SALIDA_MINIMA) / (PUNTOS_CENTROIDE - 1);  // 3.825
  float numerador = 0.0;
  float denominador = 0.0;
  for (int k = 0; k < PUNTOS_CENTROIDE; k++) {
    float x = SALIDA_MINIMA + k * paso;

    float agregado = 0.0;
    for (int i = 0; i < NUM_CONJUNTOS; i++) {
      float centro = CENTROS_SALIDA[i];
      float pertenencia = triangular(x, centro - ANCHO_SALIDA, centro, centro + ANCHO_SALIDA);
      float recortado = fminf(grado[i], pertenencia);  // implicación min
      agregado = fmaxf(agregado, recortado);            // agregación max
    }

    numerador = numerador + x * agregado;
    denominador = denominador + agregado;
  }

  // 5) Centroide y saturación a [0, 255]
  float pwm = 0.0;
  if (denominador > 0) pwm = numerador / denominador;
  if (pwm < 0) pwm = 0;
  if (pwm > PWM_MAXIMO) pwm = PWM_MAXIMO;
  return pwm;
}
