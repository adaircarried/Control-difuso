% capturar_serial.m: lee el ESP32 directamente desde MATLAB (sin el monitor de PlatformIO)
% y guarda los CSV. Antes de correrlo, cierra el monitor serial de VS Code: el puerto
% solo lo puede abrir un programa a la vez.
%
%   modo = "continuo": registra el CSV de cada 100 ms durante 'duracion' segundos
%   modo = "escalon":  manda el comando S y guarda la prueba escalón

clear; clc;

puerto = "COM5";       % <- cambiar. Lista de puertos: serialportlist("available")
modo = "escalon";      % "continuo" o "escalon"
duracion = 30;         % [s] solo para el modo continuo

s = serialport(puerto, 115200);
configureTerminator(s, "LF");
s.Timeout = 15;
pause(2);              % al abrir el puerto el ESP32 se reinicia: esperar a que arranque
flush(s);

nombres = {'t_ms', 'pot', 'pwm', 'rpm_cmd', 'rpm_enc'};
datos = [];

if modo == "escalon"
    writeline(s, "S");
    dentroEscalon = false;
    while true
        linea = strtrim(readline(s));
        if startsWith(linea, "# ESCALON"), dentroEscalon = true; continue; end
        if startsWith(linea, "# FIN ESCALON"), break; end
        valores = str2double(split(linea, ","));
        if dentroEscalon && numel(valores) == 5 && all(~isnan(valores))
            datos(end+1, :) = valores';
        end
    end
    archivo = 'escalon.csv';
else
    inicio = tic;
    while toc(inicio) < duracion
        linea = strtrim(readline(s));
        valores = str2double(split(linea, ","));
        if numel(valores) == 5 && all(~isnan(valores))
            datos(end+1, :) = valores';
        end
    end
    archivo = 'lazo_abierto.csv';
end

clear s;   % cierra el puerto

tabla = array2table(datos, 'VariableNames', nombres);
carpeta = fileparts(mfilename('fullpath'));   % se guarda junto a este archivo
writetable(tabla, fullfile(carpeta, archivo));
fprintf('%s: %d muestras\n', archivo, height(tabla));
