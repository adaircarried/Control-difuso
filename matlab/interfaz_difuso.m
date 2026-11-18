function interfaz_difuso(puerto)
% interfaz_difuso: potenciómetro virtual y gráfica en tiempo real del control difuso.
%
% Uso (antes cierra el monitor serial de VS Code; el puerto solo lo abre un programa a la vez):
%   interfaz_difuso("COM7")
%
% - El deslizador hace de potenciómetro: al soltarlo manda "P<valor>" al ESP32.
% - La gráfica muestra rpm_cmd (mandada por el difuso) y rpm_enc (medida con el encoder).
% - Botones: validar difuso (V), prueba escalón (S, calcula K y tau), detener y guardar CSV.

if nargin < 1
    puerto = "COM7";
end

carpeta = fileparts(mfilename('fullpath'));   % se guardan los CSV junto a este archivo
nombres = {'t_ms', 'pot', 'pwm', 'rpm_cmd', 'rpm_enc'};
datos = zeros(0, 5);          % todas las muestras de 100 ms
escalon = zeros(0, 5);        % muestras de la prueba escalón (10 ms)
dentroEscalon = false;
MUESTRAS_GRAFICA = 300;       % últimos 30 s en la gráfica

% ---------------------------------------------------- Ventana
fig = uifigure('Name', 'Control difuso de velocidad - motor a pasos', 'Position', [80 80 1000 640]);

uilabel(fig, 'Position', [30 595 500 30], 'FontSize', 16, 'FontWeight', 'bold', ...
        'Text', 'Potenciómetro virtual (pot: 0 a 1023)');
deslizador = uislider(fig, 'Position', [30 580 640 3], 'Limits', [0 1023], 'Value', 0, ...
                      'MajorTicks', [0 150 300 450 600 700 850 1023], ...
                      'ValueChangedFcn', @(origen, ~) mandarPot(origen.Value));

etiquetaPot = uilabel(fig, 'Position', [700 570 280 30], 'FontSize', 16, 'Text', 'pot = 0');
etiquetaPwm = uilabel(fig, 'Position', [700 540 280 30], 'FontSize', 16, 'Text', 'pwm = 0');
etiquetaRpm = uilabel(fig, 'Position', [700 510 280 30], 'FontSize', 16, ...
                      'Text', 'rpm: mandada 0 / medida 0');

uibutton(fig, 'push', 'Text', 'Validar difuso (V)', 'Position', [30 500 150 32], ...
         'ButtonPushedFcn', @(~, ~) mandar("V"));
uibutton(fig, 'push', 'Text', 'Prueba escalón (S)', 'Position', [190 500 150 32], ...
         'ButtonPushedFcn', @(~, ~) mandar("S"));
uibutton(fig, 'push', 'Text', 'Detener (pot = 0)', 'Position', [350 500 150 32], ...
         'ButtonPushedFcn', @(~, ~) detener());
uibutton(fig, 'push', 'Text', 'Guardar CSV', 'Position', [510 500 150 32], ...
         'ButtonPushedFcn', @(~, ~) guardarDatos());

ejes = uiaxes(fig, 'Position', [30 170 940 320]);
hold(ejes, 'on'); grid(ejes, 'on');
lineaCmd = plot(ejes, NaN, NaN, 'LineWidth', 1.5);
lineaEnc = plot(ejes, NaN, NaN, 'LineWidth', 1.5);
xlabel(ejes, 't [s]'); ylabel(ejes, 'velocidad [rpm]');
legend(ejes, 'rpm\_cmd (controlador difuso)', 'rpm\_enc (encoder)', 'Location', 'northwest');
ylim(ejes, [0 320]);

mensajes = uitextarea(fig, 'Position', [30 20 940 140], 'Editable', 'off', ...
                      'FontName', 'Consolas', 'Value', {'Conectando...'});

% ---------------------------------------------------- Puerto serial
s = serialport(puerto, 115200);
configureTerminator(s, "LF");
flush(s);
configureCallback(s, "terminator", @leerLinea);
fig.CloseRequestFcn = @(~, ~) cerrar();
agregarMensaje(sprintf('Conectado a %s. El ESP32 se reinicia al abrir el puerto: espera 2 s.', puerto));

% ---------------------------------------------------- Funciones

    function mandar(texto)
        writeline(s, texto);
    end

    function mandarPot(valor)
        valor = round(valor);
        deslizador.Value = valor;
        mandar("P" + valor);
        etiquetaPot.Text = sprintf('pot = %d', valor);
    end

    function detener()
        mandarPot(0);
    end

    function agregarMensaje(texto)
        mensajes.Value = [mensajes.Value; {char(texto)}];
        try
            scroll(mensajes, 'bottom');
        catch
        end
    end

    function leerLinea(origen, ~)
        linea = strtrim(readline(origen));
        if strlength(linea) == 0
            return;
        end

        % Mensajes del ESP32 (empiezan con #)
        if startsWith(linea, "#")
            agregarMensaje(linea);
            if startsWith(linea, "# ESCALON")
                dentroEscalon = true;
                escalon = zeros(0, 5);
            elseif startsWith(linea, "# FIN ESCALON")
                dentroEscalon = false;
                terminarEscalon();
            end
            return;
        end

        % Renglones del CSV: 5 números separados por comas
        valores = str2double(split(linea, ","));
        if numel(valores) ~= 5 || any(isnan(valores))
            return;
        end

        if dentroEscalon
            escalon(end+1, :) = valores';
            return;
        end

        datos(end+1, :) = valores';
        etiquetaPwm.Text = sprintf('pwm = %.1f', valores(3));
        etiquetaRpm.Text = sprintf('rpm: mandada %.1f / medida %.1f', valores(4), valores(5));

        % Gráfica de los últimos 30 s
        inicio = max(1, size(datos, 1) - MUESTRAS_GRAFICA + 1);
        t = (datos(inicio:end, 1) - datos(1, 1)) / 1000;
        set(lineaCmd, 'XData', t, 'YData', datos(inicio:end, 4));
        set(lineaEnc, 'XData', t, 'YData', datos(inicio:end, 5));
        drawnow limitrate;
    end

    function terminarEscalon()
        if size(escalon, 1) < 20
            return;
        end
        tabla = array2table(escalon, 'VariableNames', nombres);
        writetable(tabla, fullfile(carpeta, 'escalon.csv'));

        % K y tau del modelo de primer orden G(s) = K / (tau s + 1)
        tEscalon = escalon(:, 1) / 1000;
        u = escalon(1, 3);
        y = escalon(:, 5);
        yFinal = mean(y(end-19:end));
        K = yFinal / u;
        indice = find(y >= 0.632 * yFinal, 1);
        if yFinal <= 0 || isempty(indice)
            agregarMensaje('Escalón guardado en escalon.csv, pero la velocidad medida no subió: revisa el motor.');
            return;
        end
        tau = tEscalon(indice);
        agregarMensaje(sprintf('Escalón guardado en escalon.csv:  K = %.4f rpm/pwm,  tau = %.3f s', K, tau));

        figure('Name', 'Prueba escalón');
        plot(tEscalon, y, '.', tEscalon, escalon(:, 4), tEscalon, K * u * (1 - exp(-tEscalon / tau)), ...
             'LineWidth', 1.2); grid on;
        xlabel('t [s]'); ylabel('velocidad [rpm]');
        legend('rpm\_enc (medida)', 'rpm\_cmd (mandada)', ...
               sprintf('modelo K = %.3f, \\tau = %.3f s', K, tau), 'Location', 'southeast');
        title('Escalón pwm 0 \rightarrow 200');
    end

    function guardarDatos()
        if isempty(datos)
            agregarMensaje('Todavía no hay datos.');
            return;
        end
        tabla = array2table(datos, 'VariableNames', nombres);
        writetable(tabla, fullfile(carpeta, 'datos_interfaz.csv'));
        agregarMensaje(sprintf('Guardado datos_interfaz.csv (%d muestras)', size(datos, 1)));
    end

    function cerrar()
        try
            writeline(s, "P0");      % deja el motor detenido
            configureCallback(s, "off");
        catch
        end
        delete(s);
        delete(fig);
    end
end
