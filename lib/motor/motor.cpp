// motor.cpp: mando del stepper con FastAccelStepper.
//
// FastAccelStepper genera los pulsos de STEP por hardware, sin bloquear el programa:
// nosotros solo le decimos a qué velocidad (pasos/s) y con qué aceleración (pasos/s²) llegar.

#include "motor.h"

#include <FastAccelStepper.h>

#include "config.h"

static FastAccelStepperEngine generador;
static FastAccelStepper* stepper = NULL;  // la librería entrega el motor como puntero: se usa con ->

static float pasosAnteriores = 0.0;  // velocidad mandada en el periodo anterior [pasos/s]

void motorIniciar() {
  // Primero el driver deshabilitado, antes que cualquier otra cosa
  pinMode(PIN_ENABLE, OUTPUT);
  digitalWrite(PIN_ENABLE, HIGH);

  generador.init();
  // DRIVER_RMT: los pulsos se generan con el periférico RMT del ESP32.
  // El otro modo (MCPWM + PCNT) usa el mismo contador PCNT que el encoder y borraría su cuenta.
  stepper = generador.stepperConnectToPin(PIN_STEP, DRIVER_RMT);
  stepper->setDirectionPin(PIN_DIR);
  stepper->setEnablePin(PIN_ENABLE, true);  // true: ENABLE activo en bajo
  // El driver se energiza solo mientras hay pulsos y se apaga 0.5 s después de detenerse
  // (así el DRV8825 no se calienta con el motor quieto).
  stepper->setAutoEnable(true);
  stepper->setDelayToDisable(500);
}

void motorVelocidadRPM(float rpm) {
  // rpm -> pasos por segundo: rpm / 60 = vueltas por segundo; x 1600 pasos por vuelta
  float pasosPorSegundo = rpm / 60.0 * PASOS_POR_VUELTA;

  // Aceleración para pasar de la velocidad anterior a la nueva justo en un periodo T
  float aceleracion = fabs(pasosPorSegundo - pasosAnteriores) / T;
  if (aceleracion < 100) aceleracion = 100;  // la librería no acepta aceleración 0
  stepper->setAcceleration(lround(aceleracion));
  pasosAnteriores = pasosPorSegundo;

  // Velocidad muy baja: se detienen los pulsos
  if (rpm < RPM_MINIMA) {
    stepper->stopMove();
    return;
  }

  stepper->setSpeedInHz(lround(pasosPorSegundo));
  stepper->runForward();  // un solo sentido de giro
}
