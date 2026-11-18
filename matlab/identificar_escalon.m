% identificar_escalon.m: obtiene K y tau del modelo de primer orden
%   G(s) = K / (tau·s + 1)     (entrada: pwm, salida: rpm del encoder)
% a partir de escalon.csv (prueba escalón pwm 0 -> 200, muestras de 10 ms).

clear; clc;

carpeta = fileparts(mfilename('fullpath'));          % carpeta matlab/ (donde está este archivo)
archivo = fullfile(carpeta, 'escalon.csv');
if ~isfile(archivo)
    error(['No existe escalon.csv. Primero corre leer_log.m y revisa que diga ' ...
           '"escalon.csv: 200 muestras".']);
end
datos = readtable(archivo);
t = datos.t_ms / 1000;        % [s]
u = datos.pwm(1);             % tamaño del escalón (200)
y = datos.rpm_enc;            % rpm medidas con el encoder

% Ganancia: valor final / tamaño del escalón (promedio del último 0.2 s para quitar ruido)
yFinal = mean(y(end-19:end));
K = yFinal / u;

% Constante de tiempo: tiempo en que la salida llega al 63.2 % del valor final
indice = find(y >= 0.632 * yFinal, 1);
tau = t(indice);

fprintf('K   = %.4f rpm por unidad de pwm\n', K);
fprintf('tau = %.3f s\n', tau);

% Comparación de la medición contra el modelo identificado
yModelo = K * u * (1 - exp(-t / tau));
figure('Name', 'Prueba escalón');
plot(t, y, '.', t, datos.rpm_cmd, t, yModelo, 'LineWidth', 1.2); grid on;
xlabel('t [s]'); ylabel('velocidad [rpm]');
legend('rpm\_enc (medida)', 'rpm\_cmd (mandada)', sprintf('modelo K = %.3f, \\tau = %.3f s', K, tau), ...
       'Location', 'southeast');
title('Escalón pwm 0 \rightarrow 200');
