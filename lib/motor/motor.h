// motor.h: mando del stepper por velocidad.
#pragma once

void motorIniciar();

// Manda al motor la velocidad rpm (un solo sentido de giro). Se llama cada periodo T.
void motorVelocidadRPM(float rpm);
