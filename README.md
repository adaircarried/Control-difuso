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

El cableado eléctrico del péndulo **no cambia**. Solo se agrega el potenciómetro y se mueve el encoder de lugar (mecánicamente).

### Lo que se queda igual

| Desde | Hacia | Nota |
|---|---|---|
| GPIO 25 | STEP del DRV8825 | |
| GPIO 26 | DIR del DRV8825 | |
| GPIO 27 | EN del DRV8825 | activo en bajo |
| 3.3V del ESP32 | RST y SLP del driver (puenteados), M0 y M1 | M0 = M1 = 3.3 V y M2 = GND: 1/8 de paso |
| GND del ESP32 | GND lógico del driver, M2 | |
| +24 V de la fuente | VMOT | capacitor de 100 µF entre VMOT y GND, pegado al driver |
| − de la fuente | GND junto a VMOT | tierra común con el ESP32 |
| Bobinas del motor | A1/A2 y B1/B2 | Vref ≈ 0.66 V (≈ 1.3 A), sin cambios |
| Encoder rojo | VIN (5 V) del ESP32 | |
| Encoder negro | GND | |
| Encoder verde (A) | GPIO 32 | pull-ups internas, sin resistencias |
| Encoder blanco (B) | GPIO 33 | |

### Lo nuevo: potenciómetro de 10 kΩ

**Sin potenciómetro:** deja `USAR_POTENCIOMETRO = false` en `config.h` (así viene) y el pin 34 sin conectar.
El valor de pot se escribe por el monitor con `P` y un número (`P0`, `P300`, `P1023`). Cuando conectes el
potenciómetro, cambia a `true` y vuelve a subir el programa.


| Pata del potenciómetro | Va a |
|---|---|
| Extremo 1 | **3.3V** del ESP32 (nunca 5 V: el ADC solo aguanta 3.3 V) |
| Extremo 2 | GND |
| Cursor (la del centro) | GPIO 34 |

Si al girarlo al máximo la lectura baja en lugar de subir, intercambia los extremos (no el cursor).
El ADC del ESP32 no distingue bien los primeros ~0.1 V ni los últimos ~0.2 V: en las puntas del recorrido
el potenciómetro marca 0 o 1023 un poco antes de llegar al tope. Es normal.

## Acople del encoder al motor

En el péndulo el encoder medía el **ángulo del péndulo** (el péndulo iba montado en su eje, sobre el carro).
Ahora se mide la **velocidad del motor**, así que el eje del encoder tiene que girar junto con el eje del motor:

1. **Quita la banda GT2.** Si no, el carro recorrería los 0.88 m del riel en unos 4 s a 300 rpm y chocaría.
2. **Quita la polea del eje del motor** (aflojando los dos prisioneros) y **quita el péndulo** del eje del encoder.
3. **Une los dos ejes con un acople flexible de 5 mm a 6 mm**: el eje del NEMA 17 mide 5 mm y el del LPD3806 6 mm.
   Es el acople de aluminio con ranura en espiral que se usa en impresoras 3D (5×6 mm).
4. **Fija el cuerpo del encoder** con una escuadra o soporte, alineado con el eje del motor y sin forzarlo.
   El acople flexible tolera desalineaciones pequeñas; un acople rígido cargaría los rodamientos del encoder.

Alternativa sin acople: dejar la polea en el motor, poner otra polea GT2 de 20 dientes en el encoder y unirlas
con una banda cerrada. Con poleas iguales (1:1) el código no cambia.

## Condiciones eléctricas

- Fuente de 24 V, Vref y micropaso **sin cambios**. El driver con disipador y ventilador.
- El driver solo se energiza mientras el motor gira (auto-enable) y se apaga 0.5 s después de detenerse,
  para que no se caliente. Con el motor detenido el eje gira libre: es normal.
- Encender: primero el USB, luego los 24 V. Apagar: primero los 24 V, luego el USB.
- Subir el programa siempre con los 24 V apagados. Nunca conectar ni desconectar el motor con el driver encendido.
- Potenciómetro en cero antes de encender los 24 V.
- **Pérdida de pasos:** en régimen permanente `rpm_enc` debe ser casi igual a `rpm_cmd`. Si el motor zumba o
  `rpm_enc` queda abajo, baja `RPM_MAX` en `config.h` (por ejemplo a 250).

## Pasarlo a VS Code

1. En VS Code: `Ctrl+Shift+P` → **Git: Clone** → pega `https://github.com/adaircarried/control-difuso` →
   elige una carpeta **fuera** de la del péndulo → **Open**.
   (O en una terminal: `git clone https://github.com/adaircarried/control-difuso.git`.)
2. Ábrelo en su propia ventana (File → New Window) para que PlatformIO no lo confunda con el del péndulo.
3. PlatformIO detecta `platformio.ini`; en la barra inferior debe decir `env:motor_difuso`.
4. Compila con ✓. La primera vez descarga ESP32Encoder y FastAccelStepper.
5. Para traer cambios nuevos: `git pull` en la terminal de esa carpeta.

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
| `P512` | Potenciómetro virtual (solo con `USAR_POTENCIOMETRO = false`): pone pot = 512. Cualquier valor de 0 a 1023 |

## Exportar a MATLAB

**Opción 1 (recomendada): log del monitor.** Con `log2file` en `platformio.ini`, todo lo que muestra el monitor
se guarda en `logs/device-monitor-<fecha>.log`. Después:

1. Abre `matlab/leer_log.m`, pon el nombre de tu log y córrelo desde la carpeta `matlab/`.
2. Genera `lazo_abierto.csv` (cada 100 ms) y `escalon.csv` (última prueba escalón) y grafica.
3. Corre `identificar_escalon.m` para obtener K y tau.

**Opción 2: directo desde MATLAB.** Cierra el monitor de VS Code, pon tu puerto en `matlab/capturar_serial.m`
(`serialportlist("available")` los muestra) y córrelo con `modo = "escalon"` o `"continuo"`.
