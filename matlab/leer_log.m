% leer_log.m: convierte el log del monitor de PlatformIO en archivos CSV para MATLAB.
%
% El monitor de PlatformIO guarda todo lo que imprime el ESP32 en la carpeta logs/ del proyecto
% (filtro log2file de platformio.ini). Este script separa:
%   - lazo_abierto.csv: muestras de cada 100 ms (potenciómetro -> difuso -> motor)
%   - escalon.csv:      la última prueba escalón (muestras de cada 10 ms durante 2 s)
% Las líneas que empiezan con # son mensajes y se ignoran.

clear; clc;

archivo = '../logs/device-monitor-XXXXXX-XXXXXX.log';  % <- cambiar por el nombre del log (ruta desde matlab/)

lineas = splitlines(fileread(archivo));
nombres = {'t_ms', 'pot', 'pwm', 'rpm_cmd', 'rpm_enc'};

datos = [];
escalon = [];
dentroEscalon = false;

for i = 1:numel(lineas)
    linea = strtrim(lineas{i});

    if startsWith(linea, '# ESCALON')
        dentroEscalon = true;
        escalon = [];          % si hubo varias pruebas, se queda la última
        continue;
    end
    if startsWith(linea, '# FIN ESCALON')
        dentroEscalon = false;
        continue;
    end

    % Solo se aceptan renglones con 5 números separados por comas
    valores = str2double(split(linea, ','));
    if numel(valores) ~= 5 || any(isnan(valores))
        continue;
    end

    if dentroEscalon
        escalon(end+1, :) = valores';
    else
        datos(end+1, :) = valores';
    end
end

if ~isempty(datos)
    lazoAbierto = array2table(datos, 'VariableNames', nombres);
    writetable(lazoAbierto, 'lazo_abierto.csv');
    fprintf('lazo_abierto.csv: %d muestras\n', height(lazoAbierto));

    t = (lazoAbierto.t_ms - lazoAbierto.t_ms(1)) / 1000;
    figure('Name', 'Lazo abierto');
    subplot(2, 1, 1);
    plot(t, lazoAbierto.pot); grid on;
    ylabel('pot [0-1023]');
    subplot(2, 1, 2);
    plot(t, lazoAbierto.rpm_cmd, t, lazoAbierto.rpm_enc); grid on;
    xlabel('t [s]'); ylabel('velocidad [rpm]');
    legend('rpm\_cmd', 'rpm\_enc');
end

if ~isempty(escalon)
    tablaEscalon = array2table(escalon, 'VariableNames', nombres);
    writetable(tablaEscalon, 'escalon.csv');
    fprintf('escalon.csv: %d muestras (ahora corre identificar_escalon.m)\n', height(tablaEscalon));
end
