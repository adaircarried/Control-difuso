% tabla_barrido.m: valores en estado estable de cada nivel del barrido (lazo_abierto.csv).
% Para cada valor de pot (P0, P150, P300...) promedia solo las muestras en las que el filtro
% ya se asentó (rpm_cmd igual a la velocidad objetivo), así no entran los transitorios.
% Genera tabla_barrido.csv y la curva pot -> velocidad (la curva del controlador difuso en el motor).

clear; clc;

carpeta = fileparts(mfilename('fullpath'));   % carpeta matlab/ (correr con el botón Run)
datos = readtable(fullfile(carpeta, 'lazo_abierto.csv'));

RPM_MAX = 300;                    % el mismo de config.h
niveles = unique(datos.pot);      % valores de pot que se usaron
resultados = [];

fprintf('    pot     pwm   rpm_cmd   rpm_enc   error\n');
for i = 1:numel(niveles)
    % Muestras con ese pot y con el filtro ya asentado (a menos de 0.5 rpm del objetivo)
    rpmObjetivo = datos.pwm / 255 * RPM_MAX;
    estable = datos.pot == niveles(i) & abs(datos.rpm_cmd - rpmObjetivo) < 0.5;
    if sum(estable) < 5
        continue;
    end

    pwm = mean(datos.pwm(estable));
    rpmCmd = mean(datos.rpm_cmd(estable));
    rpmEnc = mean(datos.rpm_enc(estable));
    errorPorcentaje = 0;
    if rpmCmd > 0
        errorPorcentaje = (rpmEnc - rpmCmd) / rpmCmd * 100;
    end

    fprintf('%7.0f %7.1f %9.1f %9.1f %6.1f %%\n', niveles(i), pwm, rpmCmd, rpmEnc, errorPorcentaje);
    resultados(end+1, :) = [niveles(i), pwm, rpmCmd, rpmEnc, errorPorcentaje];
end

tabla = array2table(resultados, 'VariableNames', {'pot', 'pwm', 'rpm_cmd', 'rpm_enc', 'error_pct'});
writetable(tabla, fullfile(carpeta, 'tabla_barrido.csv'));

figure('Name', 'Curva pot - velocidad');
plot(tabla.pot, tabla.rpm_cmd, 'o-', tabla.pot, tabla.rpm_enc, 's--', 'LineWidth', 1.2); grid on;
xlabel('pot [0-1023]'); ylabel('velocidad en estado estable [rpm]');
legend('rpm\_cmd (controlador difuso)', 'rpm\_enc (medida)', 'Location', 'northwest');
title('Controlador difuso: pot \rightarrow velocidad del motor');
