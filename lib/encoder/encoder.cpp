// encoder.cpp: lectura del encoder con el contador de pulsos de hardware (PCNT) del ESP32.
//
// La librería ESP32Encoder configura el PCNT para que cuente los 4 flancos de A y B por sí solo,
// aunque el procesador esté ocupado. Aquí solo leemos esa cuenta y la convertimos a rpm.

#include "encoder.h"

#include <ESP32Encoder.h>

#include "config.h"

static ESP32Encoder contador;  // static: solo se usa dentro de este archivo

void encoderIniciar() {
  if (PULLUP_INTERNA) {
    ESP32Encoder::useInternalWeakPullResistors = puType::up;
  } else {
    ESP32Encoder::useInternalWeakPullResistors = puType::none;
  }
  contador.attachFullQuad(PIN_ENCODER_A, PIN_ENCODER_B);  // cuenta los 4 flancos: 600 x 4 = 2400
  contador.setFilter(FILTRO_ENCODER);
  contador.clearCount();
}

long encoderCuentas() {
  return (long)contador.getCount();
}

float encoderRpm(long cambioCuentas, float segundos) {
  // vueltas = cuentas / 2400;  rpm = vueltas / segundos * 60
  float rpm = (cambioCuentas / (float)CUENTAS_POR_VUELTA) / segundos * 60.0;
  if (ENCODER_INVERTIDO) rpm = -rpm;
  return rpm;
}
