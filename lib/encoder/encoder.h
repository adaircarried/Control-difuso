// encoder.h: lectura del encoder acoplado al eje del motor.
#pragma once

void encoderIniciar();

// Cuenta acumulada del encoder (2400 cuentas por vuelta)
long encoderCuentas();

// Convierte un cambio de cuentas en un intervalo de tiempo a rpm
float encoderRpm(long cambioCuentas, float segundos);
