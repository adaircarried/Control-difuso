// motor.h: mando del stepper por velocidad.
#pragma once

void motorIniciar();

// Manda al motor la velocidad rpm (un solo sentido de giro). Se llama cada periodo T.
void motorVelocidadRPM(float rpm);

// Prueba de calibración: avanza exactamente "pasos" pasos despacio y espera a que termine.
// Regresa los pasos que la librería dice haber dado.
long motorMoverPasos(long pasos);
