// difuso.h: controlador difuso Mamdani pot -> pwm.
#pragma once

// Función de pertenencia triangular con vértices a, b, c (igual que trimf de MATLAB)
float triangular(float x, float a, float b, float c);

// Controlador difuso completo: recibe pot [0, 1023] y regresa pwm [0, 255]
float controlDifuso(float pot);
