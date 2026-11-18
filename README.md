# Control difuso de velocidad de un motor a pasos

Control Avanzado, Unidad 3. Un ESP32 lee un potenciómetro, un controlador difuso Mamdani (igual al de MATLAB)
lo convierte en un "PWM equivalente" de 0 a 255 y eso se manda como velocidad a un motor a pasos.
Es lazo abierto: el encoder acoplado al eje solo mide las rpm reales.

## Archivos

```
platformio.ini              entorno motor_difuso
lib/config/config.h         pines, motor, encoder y constantes del controlador difuso
lib/difuso/                 controlador difuso Mamdani (sin librería)
lib/encoder/                cuenta del encoder y conversión a rpm
lib/motor/                  mando del stepper por velocidad (FastAccelStepper)
src/main.cpp                ciclo de control cada 10 ms, CSV y comandos
matlab/leer_log.m           convierte el log del monitor en lazo_abierto.csv y escalon.csv
matlab/capturar_serial.m    alternativa: captura directa desde MATLAB
matlab/identificar_escalon.m  K y tau a partir de escalon.csv
```

## Conexiones

El cableado del péndulo **no cambia**. Solo se agrega el potenciómetro:

| Potenciómetro 10 kΩ | Va a |
|---|---|
| Extremo 1 | 3.3V del ESP32 (no 5 V) |
| Extremo 2 | GND |
| Cursor (centro) | GPIO 34 |

El encoder se acopla al eje del motor y la banda GT2 se quita.

## Cargar el programa

1. Abre esta carpeta en VS Code con PlatformIO.
2. Con la fuente de 24 V **apagada**, conecta el USB y sube con → (entorno `motor_difuso`).
   Si dice "Failed to connect", mantén presionado BOOT.
3. Pon el potenciómetro en cero, enciende los 24 V y abre el monitor (el enchufe).

## Comandos (escribir la letra y Enter)

| Comando | Qué hace |
|---|---|
| `V` | Valida el difuso: imprime pwm para pot = 0, 150, 300, ... 1023 junto al valor de MATLAB |
| `S` | Prueba escalón: frena el motor, aplica pwm = 200 de golpe y registra cada 10 ms durante 2 s |

## Exportar a MATLAB

**Opción 1 (recomendada): log del monitor.** Con `log2file` en `platformio.ini`, todo lo que muestra el monitor
se guarda en `logs/device-monitor-<fecha>.log`. Después:

1. Abre `matlab/leer_log.m`, pon el nombre de tu log y córrelo desde la carpeta `matlab/`.
2. Genera `lazo_abierto.csv` (cada 100 ms) y `escalon.csv` (última prueba escalón) y grafica.
3. Corre `identificar_escalon.m` para obtener K y tau.

**Opción 2: directo desde MATLAB.** Cierra el monitor de VS Code, pon tu puerto en `matlab/capturar_serial.m`
(`serialportlist("available")` los muestra) y córrelo con `modo = "escalon"` o `"continuo"`.
