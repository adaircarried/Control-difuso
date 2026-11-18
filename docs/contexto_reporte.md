# Contexto para el reporte: Control difuso de velocidad de un motor a pasos

Usa este contexto para redactar el reporte de la práctica. Es un documento conciso, en español, con
justificación técnica breve. Las figuras las insertaré yo (capturas de MATLAB); para cada una te indico
qué muestra y cómo interpretarla. No inventes datos que no estén aquí.

## Datos generales

- Materia: Control Avanzado, Unidad 3 (control difuso). Alumno: Diego Adair de León Márquez.
- Práctica: control difuso tipo Mamdani de la velocidad de un motor a pasos, en lazo abierto
  (el encoder solo mide; no se retroalimenta).
- La maestra validó la práctica funcionando en el laboratorio.

## Hardware

| Elemento | Detalle |
|---|---|
| Microcontrolador | ESP32 DevKit WROOM-32 (38 pines), programado en PlatformIO con framework Arduino |
| Driver | DRV8825, corriente limitada a ≈ 1.3 A (Vref ≈ 0.66 V) |
| Motor | NEMA 17 17HS4401 (200 pasos/vuelta); **3200 pasos/vuelta medidos** (ver calibración) |
| Sensor | Encoder incremental LPD3806-600BM, 600 PPR, cuadratura ×4 = 2400 cuentas/vuelta, acoplado al eje del motor |
| Fuente | 12 V / 5 A al driver |
| Entrada | "Potenciómetro" 0–1023. No se consiguió un potenciómetro físico: se usó un **potenciómetro virtual** (deslizador en una interfaz de MATLAB que manda el valor por serial). La lectura del ADC real (`pot = adc·1023/4095`, GPIO 34, ADC1 de 12 bits) quedó programada y se activa con un parámetro. |

Conexiones: STEP → GPIO 25, DIR → GPIO 26, EN → GPIO 27, encoder A/B → GPIO 32/33 (pull-ups internas a 3.3 V),
encoder alimentado a 5 V. Tierra común entre ESP32, driver y fuente.

## Diseño del controlador difuso (idéntico al de MATLAB)

- Entrada **pot** en [0, 1023]: 5 funciones triangulares con centros 0, 255.75, 511.5, 767.25 y 1023;
  cada una [c − 255.75, c, c + 255.75].
- Salida **pwm** ("PWM equivalente") en el universo [−63.75, 318.75]: 5 triangulares con centros
  0, 63.75, 127.5, 191.25 y 255; cada una [c − 63.75, c, c + 63.75].
- 5 reglas: si pot es el conjunto i, entonces pwm es el conjunto i.
- Inferencia Mamdani: implicación **min** (recorte), agregación **max**, defusificación por **centroide
  discreto con 101 puntos** en [−63.75, 318.75] (igual que MATLAB). El resultado se satura a [0, 255].
- Se implementó a mano en C++ (sin librería) para reproducir exactamente el FIS de MATLAB.

## Implementación en el ESP32

1. Cada **10 ms** (tarea de tiempo real en el núcleo 0): lee pot → controlador difuso → pwm.
2. pwm → velocidad objetivo: `rpm_obj = pwm/255 · 300` (RPM_MAX = 300 rpm).
3. Filtro de primer orden sobre la velocidad mandada, τ = 0.2 s: `rpm_cmd += (rpm_obj − rpm_cmd)·T/τ`, T = 10 ms.
4. rpm_cmd se convierte a frecuencia de pasos (`rpm/60 · 3200` pasos/s) y los pulsos STEP se generan por
   hardware (librería FastAccelStepper, periférico RMT), sin bloquear el programa.
5. Velocidad real con el encoder (contador de pulsos de hardware PCNT) cada 100 ms.
6. Telemetría por serial a 115200 baudios, cada 100 ms, en CSV: `t_ms, pot, pwm, rpm_cmd, rpm_enc`.
7. Comandos: `V` (validación del difuso), `S` (prueba escalón pwm 0 → 200, registro cada 10 ms durante 2 s),
   `U` (calibración: 10 vueltas exactas), `P<valor>` (potenciómetro virtual).
8. Interfaz en MATLAB (`interfaz_difuso.m`): deslizador como potenciómetro, gráfica en tiempo real de
   rpm_cmd y rpm_enc, y botones para validar, prueba escalón (calcula K y τ) y guardar CSV.

## Resultados, figura por figura

### 1. Validación del controlador difuso (tabla del comando V)

El ESP32 calcula exactamente los valores del FIS de MATLAB:

| pot | pwm ESP32 | pwm MATLAB |
|---|---|---|
| 0 | 0.0 | 0.0 |
| 150 | 36.3 | 36.3 |
| 300 | 77.4 | 77.4 |
| 450 | 109.6 | 109.6 |
| 600 | 151.4 | 151.4 |
| 700 | 172.0 | 172.0 |
| 850 | 213.9 | 213.9 |
| 1023 | 255.0 | 255.0 |

Interpretación: la implementación en el microcontrolador es fiel al diseño. La curva no es una recta: las
triangulares y el centroide le dan forma ligeramente no lineal (por ejemplo, pot = 150 da 36.3 y no 37.4).

### 2. Primera prueba y calibración de pasos por vuelta

- En la primera prueba (figura opcional "antes de calibrar") la velocidad medida salió **negativa** y de
  **la mitad** de la mandada (≈ 145 rpm contra 300), aunque con la forma correcta.
- El signo se debía al sentido en que quedó acoplado el encoder (se invirtió por software).
- Para la mitad se hizo una prueba de calibración (comando `U`): se mandaron 16 000 pasos y el eje dio
  **5 vueltas** (contadas a mano y medidas por el encoder: 12 001 cuentas ≈ 5 × 2400).
  Conclusión: el encoder mide bien y el motor requiere **3200 pasos/vuelta** (equivalente a 1/16 de paso,
  en lugar de los 1600 esperados con 1/8). Se ajustó ese valor en el programa.

### 3. Barrido en lazo abierto (figura de 3 gráficas: pot, pwm y velocidad contra el tiempo)

- Se aplicaron escalones del potenciómetro: 0, 150, 300, 450, 600, 700, 850 y 1023, unos 5–10 s cada uno.
- Gráfica de pwm: reproduce la salida del difuso en cada nivel.
- Gráfica de velocidad: **rpm_enc (medida) queda prácticamente encima de rpm_cmd (mandada)** de 0 a ≈ 250 rpm;
  en 300 rpm llega a ≈ 290–300 rpm (límite del motor con 12 V).
- Cada cambio de nivel se ve como una subida exponencial suave: es el filtro de primer orden (τ = 0.2 s).
- La caída a 0 cerca de t ≈ 113 s es la prueba escalón (`S`), hecha en medio del barrido: el programa baja
  el pwm a 0, aplica el escalón y regresa al nivel anterior (la rampa recta es MATLAB uniendo el hueco
  mientras se registraba el escalón).

### 4. Curva pot → velocidad en estado estable (tabla_barrido.m)

- Promedio de cada nivel solo cuando el filtro ya se asentó.
- Velocidades esperadas (rpm = pwm/255 · 300): 0, 42.7, 91.1, 128.9, 178.1, 202.4, 251.6 y 300 rpm.
- [Insertaré la tabla `tabla_barrido.csv` con rpm_enc medidas y el error %.]
- Interpretación: es la curva del controlador difuso medida en el motor; la medida sigue a la mandada con
  error pequeño hasta ≈ 250 rpm.

### 5. Prueba escalón e identificación (pwm 0 → 200)

- Velocidad mandada final: 200/255 · 300 = 235.3 rpm. Medida final ≈ 225 rpm.
- Modelo de primer orden identificado: **G(s) = K / (τs + 1) = 1.124 / (0.210 s + 1)** (entrada pwm, salida rpm).
- K = 1.124 rpm por unidad de pwm (teórico 300/255 = 1.176; diferencia −4.4 %).
  τ = 0.210 s (teórico 0.2 s del filtro; los 10 ms extra corresponden a un periodo de muestreo).
- Método: K = valor final / tamaño del escalón (promedio de los últimos 0.2 s); τ = tiempo al 63.2 % del valor final.
- La curva del modelo sigue muy bien los puntos medidos. La dispersión de ±5 rpm viene de medir la velocidad
  en ventanas de solo 10 ms.
- Justificación: un motor a pasos sin pérdida de pasos sigue la velocidad que se le manda, así que la dinámica
  identificada es principalmente la del filtro de primer orden programado; la pequeña diferencia en K se
  atribuye a pasos perdidos ocasionalmente a velocidad alta con la fuente de 12 V y al ruido de medición.

### 6. Interfaz de MATLAB (captura)

Deslizador como potenciómetro virtual, indicadores de pot, pwm y rpm, gráfica en tiempo real de rpm_cmd
y rpm_enc, y botones de validación, prueba escalón, detener y guardar CSV. Con ella se hizo la demostración.

## Conclusiones sugeridas

- El controlador difuso Mamdani implementado en el ESP32 reproduce exactamente al diseñado en MATLAB.
- La velocidad del motor sigue a la del controlador difuso en todo el rango, con error pequeño hasta ≈ 250 rpm.
- La prueba escalón permitió identificar G(s) = 1.124/(0.210 s + 1), consistente con el filtro programado (τ = 0.2 s).
- La calibración experimental (3200 pasos/vuelta) fue necesaria para que la velocidad medida coincidiera
  con la mandada; medir con el encoder permitió detectar y corregir el error.
- Mejoras: usar el potenciómetro físico (ya programado), cerrar el lazo con el encoder y usar 24 V para tener
  más par a velocidad alta.
