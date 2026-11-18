# Control difuso de velocidad de un motor a pasos (ESP32 + DRV8825 + NEMA 17)

Práctica de Control Avanzado, Unidad 3: control difuso. Proyecto independiente: **no** mezclar con el
repositorio del péndulo invertido. Solo se reutiliza el mismo hardware y cableado.

## Reglas del código

- Framework Arduino en PlatformIO (`board = esp32dev`; la placa es una NodeMCU-32S).
- C++ sencillo y explicable, estilo Arduino: funciones normales, variables globales claras.
  Sin clases propias, plantillas, lambdas ni memoria dinámica.
- Nombres y comentarios en español. Cada constante con un comentario de dónde sale.
- El controlador difuso se implementa a mano (sin librería), idéntico al de MATLAB.

## Hardware (sin cambios respecto al péndulo)

| Elemento | Detalle |
|---|---|
| Microcontrolador | ESP32 NodeMCU-32S |
| Driver | DRV8825, Vref ≈ 0.66 V (≈ 1.3 A), micropaso 1/8 (M0 = M1 = 3.3 V, M2 = GND) |
| Motor | NEMA 17 17HS4401: 200 × 8 = **1600 pasos/vuelta** |
| Encoder | LPD3806-600BM, 600 PPR × 4 = **2400 cuentas/vuelta**, pull-ups internas a 3.3 V |
| Montaje | Encoder acoplado al eje del motor; banda GT2 quitada |
| Potenciómetro | 10 kΩ, extremos a 3.3 V y GND, cursor a GPIO 34 (ADC1) |

| Señal | GPIO |
|---|---|
| Encoder A (verde) | 32 |
| Encoder B (blanco) | 33 |
| STEP | 25 |
| DIR | 26 |
| ENABLE (activo en bajo) | 27 |
| Potenciómetro (cursor) | 34 |

## Especificación de la práctica (lazo abierto; el encoder solo mide)

1. Potenciómetro en ADC1, 12 bits escalados a 0–1023: `pot = adc * 1023 / 4095`.
2. Controlador difuso Mamdani, idéntico al de MATLAB:
   - Entrada pot [0, 1023]: 5 triangulares, centros 0, 255.75, 511.5, 767.25, 1023; cada una [c − 255.75, c, c + 255.75].
   - Salida pwm, universo [−63.75, 318.75]: 5 triangulares, centros 0, 63.75, 127.5, 191.25, 255; cada una [c − 63.75, c, c + 63.75].
   - 5 reglas: conjunto i de entrada → conjunto i de salida.
   - Implicación min, agregación max, centroide discreto con 101 puntos en [−63.75, 318.75]. Saturar a [0, 255].
   - Valores de validación: pot 0→0.0, 150→36.3, 300→77.4, 450→109.6, 600→151.4, 700→172.0, 850→213.9, 1023→255.0.
3. `rpm_obj = pwm/255 · RPM_MAX`, con RPM_MAX = 300 (bajarlo si el motor pierde pasos). Frecuencia de pasos con 1600 pasos/vuelta.
4. Filtro de primer orden, τ = 0.2 s, T = 10 ms: `rpm_cmd += (rpm_obj − rpm_cmd)·T/τ`. Pulsos STEP sin bloquear.
   Con rpm_cmd muy baja se detienen los pulsos. Un solo sentido de giro.
5. RPM reales con el encoder cada 100 ms.
6. Serial a 115200, cada 100 ms, CSV: `t_ms,pot,pwm,rpm_cmd,rpm_enc`.
7. Comando `S`: prueba escalón (pwm 0 → 200 de golpe), registro cada 10 ms durante 2 s, para identificar K y τ.

## Decisiones de implementación

- Pulsos con FastAccelStepper en modo **DRIVER_RMT**: el modo MCPWM+PCNT usa el mismo PCNT que el encoder
  y le borraba la cuenta (problema ya visto en el péndulo).
- En cada periodo se pide al motor llegar a rpm_cmd con la aceleración justa para hacerlo en T.
- Auto-enable: el driver solo se energiza mientras hay pulsos (se apaga 0.5 s después de detenerse) para que no se caliente.
- Tarea de control en el núcleo 0 cada 10 ms con `vTaskDelayUntil`; impresión y comandos en `loop()` (núcleo 1).
- Prueba escalón: pwm = 0 hasta que el motor esté detenido 0.5 s, rpm_cmd = 0, y luego pwm = 200 por 200 muestras.
  Las muestras se guardan en memoria y se imprimen al terminar entre `# ESCALON` y `# FIN ESCALON`.
- Comando `V`: imprime la tabla de validación del difuso contra los valores de MATLAB.
- El centroide de los extremos da 0.03 y 254.97 (igual que MATLAB en doble precisión; redondeados: 0.0 y 255.0).

## Estado

- Código escrito y revisado contra las firmas de las librerías (falta compilarlo en PlatformIO en la PC del autor).
- El difuso (`difuso.cpp` real) se probó en la PC contra los 8 valores de MATLAB: coincide.
- Pendiente: prueba en hardware (validar con `V`, girar el potenciómetro, prueba escalón `S`).
