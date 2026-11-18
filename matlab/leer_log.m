% leer_log.m: convierte los logs del monitor de PlatformIO en archivos CSV para MATLAB.
%
% El monitor de PlatformIO guarda todo lo que imprime el ESP32 en la carpeta logs/ del proyecto
% (filtro log2file de platformio.ini); cada vez que se abre el monitor se crea un log nuevo.
% Este script revisa TODOS los logs (no hay que escribir el nombre) y genera, en esta carpeta:
%   - lazo_abierto.csv: el log más reciente en el que se movió el pot (muestras de cada 100 ms)
%   - escalon.csv:      la prueba escalón más reciente (muestras de cada 10 ms durante 2 s)
% Las líneas que empiezan con # son mensajes y se ignoran.

clear; clc;

carpeta = fileparts(mfilename('fullpath'));          % carpeta matlab/ (donde está este archivo)
carpetaLogs = fullfile(carpeta, '..', 'logs');

archivos = dir(fullfile(carpetaLogs, '*.log'));
if isempty(archivos)
    error('No hay logs en %s. Abre el monitor de PlatformIO para generarlos.', carpetaLogs);
end
[~, orden] = sort([archivos.datenum]);
archivos = archivos(orden);                          % del más viejo al más nuevo

nombres = {'t_ms', 'pot', 'pwm', 'rpm_cmd', 'rpm_enc'};
datos = [];
escalon = [];
logDatos = '';
logEscalon = '';

for a = 1:numel(archivos)
    [datosLog, escalonLog] = separarLog(fullfile(carpetaLogs, archivos(a).name));
    if ~isempty(datosLog) && any(datosLog(:, 2) > 0)    % en este log sí se movió el pot
        datos = datosLog;
        logDatos = archivos(a).name;
    end
    if ~isempty(escalonLog)
        escalon = escalonLog;
        logEscalon = archivos(a).name;
    end
end

% ---------------- Lazo abierto (barrido del potenciómetro)
if isempty(datos)
    fprintf('No se encontró ningún log con el potenciómetro en movimiento (pot siempre en 0).\n');
else
    lazoAbierto = array2table(datos, 'VariableNames', nombres);
    writetable(lazoAbierto, fullfile(carpeta, 'lazo_abierto.csv'));
    fprintf('lazo_abierto.csv: %d muestras (de %s)\n', height(lazoAbierto), logDatos);

    t = (lazoAbierto.t_ms - lazoAbierto.t_ms(1)) / 1000;
    figure('Name', 'Lazo abierto');
    subplot(3, 1, 1);
    plot(t, lazoAbierto.pot); grid on;
    ylabel('pot [0-1023]');
    subplot(3, 1, 2);
    plot(t, lazoAbierto.pwm); grid on;
    ylabel('pwm [0-255]');
    subplot(3, 1, 3);
    plot(t, lazoAbierto.rpm_cmd, t, lazoAbierto.rpm_enc); grid on;
    xlabel('t [s]'); ylabel('velocidad [rpm]');
    legend('rpm\_cmd', 'rpm\_enc');
end

% ---------------- Prueba escalón
if isempty(escalon)
    fprintf(['No se encontró ninguna prueba escalón completa en los logs.\n' ...
             'En el monitor escribe S, Enter, y espera a que aparezca "# FIN ESCALON".\n']);
else
    tablaEscalon = array2table(escalon, 'VariableNames', nombres);
    writetable(tablaEscalon, fullfile(carpeta, 'escalon.csv'));
    fprintf('escalon.csv: %d muestras (de %s). Ahora corre identificar_escalon.m\n', ...
            height(tablaEscalon), logEscalon);
end


% Separa un log en las muestras de cada 100 ms y la última prueba escalón completa
function [datos, escalon] = separarLog(ruta)
    lineas = splitlines(fileread(ruta));
    datos = [];
    escalon = [];
    escalonActual = [];
    dentroEscalon = false;

    for i = 1:numel(lineas)
        linea = strtrim(lineas{i});

        if startsWith(linea, '# ESCALON')
            dentroEscalon = true;
            escalonActual = [];
            continue;
        end
        if startsWith(linea, '# FIN ESCALON')
            dentroEscalon = false;
            escalon = escalonActual;      % solo se guarda si la prueba terminó completa
            continue;
        end

        % Solo se aceptan renglones con 5 números separados por comas
        valores = str2double(split(linea, ','));
        if numel(valores) ~= 5 || any(isnan(valores))
            continue;
        end

        if dentroEscalon
            escalonActual(end+1, :) = valores';
        else
            datos(end+1, :) = valores';
        end
    end
end
