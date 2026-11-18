// main.cpp: control difuso de velocidad de un motor a pasos, en lazo abierto.
//
// Núcleo 0: tareaControl(), cada T = 10 ms exactos:
//   potenciómetro -> controlador difuso (pwm) -> rpm objetivo -> filtro de primer orden -> motor.
//   El encoder solo mide las rpm reales; no se retroalimenta.
// Núcleo 1: loop(), imprime el CSV cada 100 ms y atiende los comandos.
//
// Comandos (escribir la letra y presionar Enter):
//   S  prueba escalón: pwm de 0 a 200 de golpe, registra cada 10 ms durante 2 s
//   V  valida el controlador difuso contra los valores de MATLAB
//
// Salida: CSV  t_ms,pot,pwm,rpm_cmd,rpm_enc   (las líneas que empiezan con # son mensajes)

#include <Arduino.h>

#include "config.h"
#include "difuso.h"
#include "encoder.h"
#include "motor.h"

// Modos de operación
const int MODO_POTENCIOMETRO = 0;     // normal: el potenciómetro manda
const int MODO_ESCALON_ESPERA = 1;    // pwm = 0 hasta que el motor se detiene
const int MODO_ESCALON_REGISTRO = 2;  // pwm = 200 y se guarda cada muestra de 10 ms
const int MODO_ESCALON_IMPRIMIR = 3;  // el núcleo 1 imprime lo guardado (el potenciómetro ya manda)

// ---------------------------------------------------- Variables compartidas entre núcleos
volatile int modo = MODO_POTENCIOMETRO;
volatile bool pedirEscalon = false;  // el núcleo 1 pide, el núcleo 0 actúa

struct Muestra {
  unsigned long tiempoMs;
  float pot;
  float pwm;
  float rpmComando;
  float rpmEncoder;
};

QueueHandle_t colaReporte;            // muestras de 100 ms, del núcleo 0 al núcleo 1
Muestra escalon[MUESTRAS_ESCALON];    // registro de la prueba escalón (se imprime al terminar)

// ---------------------------------------------------- Núcleo 0: ciclo de control
// Aquí no va Serial ni delay.

void tareaControl(void* parametro) {
  const TickType_t periodoTicks = pdMS_TO_TICKS(lround(T * 1000));  // 10 ms (tick de 1 ms)
  TickType_t ultimoDespertar = xTaskGetTickCount();

  float rpmComando = 0.0;
  long cuentasAnterior = encoderCuentas();  // cuenta de hace 10 ms
  long cuentasReporte = cuentasAnterior;    // cuenta de hace 100 ms
  int periodos = 0;
  int periodosQuieto = 0;
  int muestra = 0;

  while (true) {
    // Dormir hasta exactamente 10 ms después del despertar anterior: periodo fijo
    vTaskDelayUntil(&ultimoDespertar, periodoTicks);

    // 1) Potenciómetro: lectura de 12 bits escalada a 0–1023
    float pot = analogRead(PIN_POTENCIOMETRO) * POT_MAXIMO / ADC_MAXIMO;

    if (pedirEscalon) {
      modo = MODO_ESCALON_ESPERA;
      periodosQuieto = 0;
      pedirEscalon = false;
    }

    // 2) Controlador difuso: pot -> pwm (en la prueba escalón el pwm es fijo)
    float pwm;
    if (modo == MODO_ESCALON_ESPERA) {
      pwm = 0.0;
    } else if (modo == MODO_ESCALON_REGISTRO) {
      pwm = PWM_ESCALON;
    } else {
      pwm = controlDifuso(pot);
    }

    // 3) "PWM equivalente" a velocidad objetivo
    float rpmObjetivo = pwm / PWM_MAXIMO * RPM_MAX;

    // 4) Filtro de primer orden (tau = 0.2 s) y mando al motor
    rpmComando = rpmComando + (rpmObjetivo - rpmComando) * T / TAU_FILTRO;
    motorVelocidadRPM(rpmComando);

    // 5) Velocidad real con el encoder, en los últimos 10 ms
    long cuentas = encoderCuentas();
    float rpmEncoder10ms = encoderRpm(cuentas - cuentasAnterior, T);
    cuentasAnterior = cuentas;

    // Prueba escalón: esperar a que el motor esté detenido 0.5 s y empezar desde 0
    if (modo == MODO_ESCALON_ESPERA && rpmComando < RPM_MINIMA) {
      periodosQuieto++;
      if (periodosQuieto >= PERIODOS_REPOSO) {
        rpmComando = 0.0;
        muestra = 0;
        modo = MODO_ESCALON_REGISTRO;  // el escalón se aplica desde el siguiente periodo
      }
    } else if (modo == MODO_ESCALON_REGISTRO) {
      escalon[muestra].tiempoMs = muestra * lround(T * 1000);  // 0, 10, 20, ... ms desde el escalón
      escalon[muestra].pot = pot;
      escalon[muestra].pwm = pwm;
      escalon[muestra].rpmComando = rpmComando;
      escalon[muestra].rpmEncoder = rpmEncoder10ms;
      muestra++;
      if (muestra >= MUESTRAS_ESCALON) modo = MODO_ESCALON_IMPRIMIR;
    }

    // Cada 100 ms: rpm del encoder en esos 100 ms y una muestra para el CSV
    periodos++;
    if (periodos >= PERIODOS_POR_REPORTE) {
      float rpmEncoder = encoderRpm(cuentas - cuentasReporte, T * PERIODOS_POR_REPORTE);
      cuentasReporte = cuentas;
      periodos = 0;

      if (modo == MODO_POTENCIOMETRO || modo == MODO_ESCALON_ESPERA) {
        Muestra reporte;
        reporte.tiempoMs = millis();
        reporte.pot = pot;
        reporte.pwm = pwm;
        reporte.rpmComando = rpmComando;
        reporte.rpmEncoder = rpmEncoder;
        xQueueSend(colaReporte, &reporte, 0);
      }
    }
  }
}

// ---------------------------------------------------- Núcleo 1: comandos e impresión

void imprimirMuestra(Muestra m) {
  Serial.printf("%lu,%.1f,%.1f,%.1f,%.1f\n", m.tiempoMs, m.pot, m.pwm, m.rpmComando, m.rpmEncoder);
}

void imprimirEscalon() {
  Serial.println("# ESCALON pwm 0 -> 200, una muestra cada 10 ms");
  Serial.println("t_ms,pot,pwm,rpm_cmd,rpm_enc");
  for (int i = 0; i < MUESTRAS_ESCALON; i++) {
    imprimirMuestra(escalon[i]);
  }
  Serial.println("# FIN ESCALON");
  modo = MODO_POTENCIOMETRO;  // se reanuda el CSV de cada 100 ms
}

void validarDifuso() {
  const int CASOS = 8;
  float pruebaPot[CASOS] = {0, 150, 300, 450, 600, 700, 850, 1023};
  float esperadoMatlab[CASOS] = {0.0, 36.3, 77.4, 109.6, 151.4, 172.0, 213.9, 255.0};
  Serial.println("# Validación del controlador difuso (pot -> pwm)");
  for (int i = 0; i < CASOS; i++) {
    Serial.printf("# pot %6.1f -> pwm %6.1f   (MATLAB %6.1f)\n",
                  pruebaPot[i], controlDifuso(pruebaPot[i]), esperadoMatlab[i]);
  }
}

void atenderComandos() {
  if (!Serial.available()) return;
  String linea = Serial.readStringUntil('\n');
  linea.trim();
  if (linea.length() == 0) return;
  char comando = toupper(linea[0]);

  if (comando == 'S') {
    if (modo == MODO_POTENCIOMETRO) {
      Serial.println("# Prueba escalón: deteniendo el motor...");
      pedirEscalon = true;
    } else {
      Serial.println("# Ya hay una prueba escalón en curso");
    }
  } else if (comando == 'V') {
    validarDifuso();
  }
}

void setup() {
  motorIniciar();  // primero: driver deshabilitado

  Serial.begin(115200);
  delay(200);

  analogReadResolution(12);                               // ADC de 12 bits: 0–4095
  analogSetPinAttenuation(PIN_POTENCIOMETRO, ADC_11db);   // rango de entrada completo, 0–3.3 V

  encoderIniciar();
  colaReporte = xQueueCreate(20, sizeof(Muestra));

  // Tarea de control en el núcleo 0 con prioridad alta (loop() corre en el núcleo 1)
  xTaskCreatePinnedToCore(tareaControl, "control", 4096, NULL, 20, NULL, 0);

  Serial.println();
  Serial.println("# Control difuso de velocidad (lazo abierto).  S: prueba escalón   V: validar difuso");
  Serial.println("t_ms,pot,pwm,rpm_cmd,rpm_enc");
}

void loop() {
  atenderComandos();

  // Imprimir cada muestra de 100 ms que mandó el núcleo 0
  Muestra m;
  while (xQueueReceive(colaReporte, &m, 0) == pdTRUE) {
    imprimirMuestra(m);
  }

  if (modo == MODO_ESCALON_IMPRIMIR) imprimirEscalon();

  delay(5);
}
