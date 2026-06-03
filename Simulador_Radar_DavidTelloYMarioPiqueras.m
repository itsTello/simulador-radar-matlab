% =========================================================================
% SIMULADOR DE RADAR — TRABAJO DE PRÁCTICAS (VERSIÓN MULTI-BLANCO + CHIRP)
% =========================================================================
% REQUISITOS IMPLEMENTADOS:
%   [R1]  Blancos con trayectorias pre-establecidas (líneas rectas)
%   [R2]  Modelo SW5: RCS fija por blanco, aleatorizada una sola vez
%   [R3]  Rmax = (3/4)·Rmax_na  →  Rmax_na = (4/3)·Rmax
%   [R4]  Cálculo explícito de Prx_min y Vrx_min (sensibilidad del receptor)
%   [R5]  Tiempo de vuelo exacto cuantizado a múltiplos enteros de τ_comp
%   [R6]  Zona ciega física (Rmax < R < Rmax_na): blanco invisible
%   [R7]  Eco que llega en periodo de TX siguiente: blanco invisible
%   [R8]  Blanco ambiguo FORZADO: blanco 1 arranca en R0 > Rmax_na
%   [R9]  Transición visible: ambiguo (amarillo) → real (verde)
%   [R10] Sensibilidad: V_señal < Vrx_min → no detección aunque V > umbral
%   [R11] Representación en múltiplos de ΔR_comp (celdas comprimidas)
%   [R12] Dos pantallas: espacio físico real + pantalla PPI
%   [R13] Doble círculo Rmax y Rmax_na en ambas pantallas
%   [CHIRP] Compresión de pulsos LFM: B_chirp, CR=B·τ, ΔR_comp=c/(2·B)
%           - Zona ciega física basada en τ (pulso transmitido)
%           - Resolución radial basada en τ_comp = 1/B_chirp
%           - Ruido y SNR calculados con B_rx = B_chirp
%   [EXTRA] Múltiples blancos con trayectorias independientes (+1 punto)
% =========================================================================
clear; clc; close all;

%% =========================================================================
%% 1. MENÚ INTERACTIVO DE PARÁMETROS
%% =========================================================================
disp('======================================================');
disp('   SIMULADOR RADAR — CONFIGURACION DE PARAMETROS');
disp('   (Pulsa ENTER para usar el valor por defecto)');
disp('======================================================');

pedir = @(msg, def) radar_input(input(sprintf('%s [%g]: ', msg, def)), def);

Pdg_kW      = pedir('Potencia pico del transmisor (kW)',         1000);
freq_GHz    = pedir('Frecuencia de operacion (GHz)',              3);
tau_us      = pedir('Anchura de pulso TX (us)',                   2);
B_chirp_MHz = pedir('Ancho de banda Chirp (MHz)  [CR = B*tau]',  5);
Pfa         = pedir('Probabilidad de Falsa Alarma',               1e-6);
Pd          = pedir('Probabilidad de Deteccion',                  0.9);
Gant_dB     = pedir('Ganancia de antena (dB)',                    35);
haz_deg     = pedir('Ancho de haz de la antena (grados)',         3);
sigma_medio = pedir('RCS media del blanco (m^2)',                 10);
num_blancos = pedir('Numero de blancos a simular (1-8)',          3);
num_blancos = max(1, min(8, round(num_blancos)));
vel_blancos = pedir('Velocidad de los blancos (m/s)',             2500);

% Conversiones a unidades SI
Pdg     = Pdg_kW * 1e3;
freq    = freq_GHz * 1e9;
tau     = tau_us * 1e-6;
B_chirp = B_chirp_MHz * 1e6;
Gant    = 10^(Gant_dB / 10);

% Constantes físicas
c      = 3e8;
k_B    = 1.38e-23;
T0     = 290;
lambda = c / freq;
L_sys  = 10^(5/10);
B_rx   = B_chirp;        % Receptor adaptado al pulso comprimido [CHIRP]
F      = 10^(3/10);

%% =========================================================================
%% 2. DIMENSIONAMIENTO RADAR
%% =========================================================================
A_alb      = log(0.62 / Pfa);
B_alb      = log(Pd / (1 - Pd));
SNR_min_dB = A_alb + 0.12*A_alb*B_alb + 1.7*B_alb;
SNR_min    = 10^(SNR_min_dB / 10);

% Ruido con ancho de banda del receptor adaptado al chirp [CHIRP]
N_tot    = k_B * T0 * B_rx * F;
sigma_n  = sqrt(N_tot / 2);
Prx_min  = SNR_min * N_tot; 
Vrx_min  = sqrt(Prx_min);
V_umbral = sqrt(-2 * sigma_n^2 * log(Pfa));

% Rmax    = ((Pdg * Gant^2 * lambda^2 * sigma_medio) / ...
%            ((4*pi)^3 * SNR_min * N_tot * L_sys))^(1/4);
% Rmax_na = (4/3) * Rmax;
% PRT     = (2 * Rmax_na) / c;
% PRF     = 1 / PRT;

% --- COMPRESIÓN DE PULSOS LFM (Chirp) [CHIRP] ---
CR         = B_chirp * tau;           % Ratio de compresión (producto tiempo-ancho de banda)
tau_comp   = 1 / B_chirp;            % Anchura del pulso comprimido
Delta_R    = (c * tau)      / 2;     % Resolución sin comprimir (para zona ciega)
Delta_R_comp = (c * tau_comp) / 2;  % Resolución comprimida  = c/(2·B_chirp)
D_min      = c * tau / 2;           % Distancia mínima (zona ciega TX, basada en τ real)
theta_haz  = deg2rad(haz_deg);

% Ecuación de Radar para Chirp (incluyendo CR en el numerador)
Rmax = ((Pdg * CR * Gant^2 * lambda^2 * sigma_medio) / ((4*pi)^3 * SNR_min * N_tot * L_sys))^(1/4);
Rmax_na = (4/3) * Rmax;
PRT     = (2 * Rmax_na) / c;
PRF     = 1 / PRT;

disp(' ');
disp('================================================================');
fprintf('  SNR minima (Albersheim):       %6.2f  dB\n',  SNR_min_dB);
fprintf('  Potencia de ruido (N_tot):     %.3e  W\n',    N_tot);
fprintf('  Sensibilidad (Prx_min):        %.3e  W\n',    Prx_min);
fprintf('  Tension minima (Vrx_min):      %.3e  V\n',    Vrx_min);
fprintf('  Voltaje umbral (V_umbral):     %.3e  V\n',    V_umbral);
fprintf('  Alcance maximo (Rmax):         %6.2f  km\n',  Rmax/1e3);
fprintf('  Alcance no ambiguo (Rmax_na):  %6.2f  km\n',  Rmax_na/1e3);
fprintf('  PRF:                           %6.2f  Hz\n',  PRF);
fprintf('  PRT:                           %6.4f  ms\n',  PRT*1e3);
disp('  -------  COMPRESION DE PULSOS LFM (Chirp)  -------');
fprintf('  Ancho de pulso TX (tau):       %6.2f  us\n',  tau*1e6);
fprintf('  Ancho de banda Chirp (B):      %6.2f  MHz\n', B_chirp/1e6);
fprintf('  Ratio de compresion (CR=B*tau):%6.1f  (%.1f dB)\n', CR, 10*log10(CR));
fprintf('  Pulso comprimido (tau_comp):   %6.4f  us\n',  tau_comp*1e6);
fprintf('  Resolucion sin comprimir:      %6.1f  m\n',   Delta_R);
fprintf('  Resolucion comprimida:         %6.1f  m\n',   Delta_R_comp);
fprintf('  Distancia minima ciega:        %6.1f  m\n',   D_min);
disp('  ---------------------------------------------------');
fprintf('  Ancho de haz (usuario):        %6.2f  deg\n', haz_deg);
fprintf('  Velocidad blancos:             %6.0f  m/s\n', vel_blancos);
disp('================================================================');
pause(2);

%% =========================================================================
%% 3. DEFINICIÓN DE LOS BLANCOS — MODELO SW5 [R1][R2][R8]
%% =========================================================================
% Paleta de colores distintos para cada blanco (máximo 8)
colores_blancos = [
    1.0  0.45 0.0 ;   % naranja
    0.2  0.8  1.0 ;   % cian
    1.0  0.3  0.75;   % magenta
    0.4  1.0  0.2 ;   % verde lima
    1.0  1.0  0.15;   % amarillo
    0.85 0.4  0.15;   % marrón
    0.6  0.55 1.0 ;   % lavanda
    1.0  0.65 0.65;   % rosa
];

rng('shuffle');

xb_arr    = zeros(1, num_blancos);
yb_arr    = zeros(1, num_blancos);
vx_arr    = zeros(1, num_blancos);
vy_arr    = zeros(1, num_blancos);
sigma_arr = zeros(1, num_blancos);
R0_arr    = zeros(1, num_blancos);
th0_arr   = zeros(1, num_blancos);

disp('--- BLANCOS GENERADOS ---');
% RCS aleatoria en rango amplio [0.2 × 20] × sigma_medio (SW5, fija por blanco).
% Esto garantiza que algunos blancos lejanos sean suficientemente reflectivos
% para producir ecos ambiguos detectables, y otros no.
% A R = 1.35·Rmax_na la señal cae ~10x respecto a Rmax, por lo que se necesita
% RCS ≥ ~10·sigma_medio para ser detectable como ambiguo.
for b = 1:num_blancos
    sigma_arr(b) = sigma_medio * (0.2 + 19.8*rand());   % SW5: RCS fija, rango ×0.2..×20

    if b == 1
        % Blanco 1: posición forzada para demostrar ambigüedad [R8]
        R0_arr(b)  = 1.35 * Rmax_na;
        th0_arr(b) = deg2rad(60);
        vel_r      = -vel_blancos;
    else
        % Blancos adicionales: ángulos distribuidos, distancias aleatorias
        th0_arr(b) = deg2rad(60) + (b-1) * (2*pi / num_blancos);
        R0_arr(b)  = Rmax * (0.4 + 0.7*rand());
        % Velocidad entre el 60% y el 100% del valor elegido
        vel_r      = -(vel_blancos * (0.6 + 0.4*rand()));
    end

    vx_arr(b) = vel_r * cos(th0_arr(b));
    vy_arr(b) = vel_r * sin(th0_arr(b));
    xb_arr(b) = R0_arr(b) * cos(th0_arr(b));
    yb_arr(b) = R0_arr(b) * sin(th0_arr(b));

    fprintf('  B%d | RCS=%.1f m^2 | R0=%.1f km | th=%.0f deg | Vr=%.0f m/s\n', ...
            b, sigma_arr(b), R0_arr(b)/1e3, rad2deg(th0_arr(b)), abs(vel_r));
end

%% =========================================================================
%% 4. PARÁMETROS DE SIMULACIÓN CINEMÁTICA
%% =========================================================================
RPM_antena = 15;
omega_ant  = (RPM_antena/60) * 2*pi;
vel_rot    = deg2rad(3.0);   % 3 deg/frame → 120 frames/vuelta (3x más rápido)
dt         = vel_rot / omega_ant;

r_vec      = (0 : Delta_R_comp : Rmax_na)';
num_celdas = length(r_vec);

fprintf('\n  dt por frame: %.4f s | Celdas: %d (resolucion comprimida: %.1f m)\n', ...
        dt, num_celdas, Delta_R_comp);
disp('  Iniciando simulacion... Cierra la ventana para terminar.');
pause(1);

%% =========================================================================
%% 5. BUCLE DE SIMULACIÓN CONTINUA
%% =========================================================================
fig = figure('Name','Simulador Radar — Practicas', ...
             'Position',[20 20 1600 740], 'Color','k');

theta_antena = 0;
hist_r   = [];
hist_th  = [];
hist_alp = [];
hist_bid = [];

ang_circ = linspace(0, 2*pi, 361);

while isgraphics(fig)

    %% 5.1  Actualización de posiciones
    xb_arr = xb_arr + vx_arr * dt;
    yb_arr = yb_arr + vy_arr * dt;

    for b = 1:num_blancos
        [~, r_tmp] = cart2pol(xb_arr(b), yb_arr(b));
        if r_tmp < D_min          % zona ciega física basada en τ real
            xb_arr(b) = R0_arr(b) * cos(th0_arr(b));
            yb_arr(b) = R0_arr(b) * sin(th0_arr(b));
        end
    end

    %% 5.2  Avance de la antena
    theta_antena = mod(theta_antena + vel_rot, 2*pi);

    %% 5.3  Ruido AWGN complejo
    I_ruido = sigma_n * randn(num_celdas, 1);
    Q_ruido = sigma_n * randn(num_celdas, 1);
    V_rx    = abs(I_ruido + 1j*Q_ruido);

    %% 5.4  Procesado por blanco
    for b = 1:num_blancos

        [theta_b, r_b] = cart2pol(xb_arr(b), yb_arr(b));

        % ¿Iluminado por el haz?
        dif_ang = abs(atan2(sin(theta_b - theta_antena), ...
                            cos(theta_b - theta_antena)));
        if dif_ang > theta_haz/2; continue; end

        % Potencia y tensión del eco - añadimos el CR para que se incluya
        % la tau a la fórmula
        Pr_eco  = (Pdg * CR * Gant^2 * lambda^2 * sigma_arr(b)) / ...
                  ((4*pi)^3 * r_b^4 * L_sys);
        V_senal = sqrt(Pr_eco);

        % Tiempo de vuelo y cuantización a celdas comprimidas [R5][CHIRP]
        t_vuelo    = (2 * r_b) / c;
        num_PRTs   = floor(t_vuelo / PRT);
        t_residual = t_vuelo - num_PRTs * PRT;
        r_aparente = (c * t_residual) / 2;
        celda_idx  = max(1, min(num_celdas, round(r_aparente/Delta_R_comp) + 1));
        r_cuant    = (celda_idx - 1) * Delta_R_comp;

        % Zonas ciegas [R6][R7]
        % R6: zona entre Rmax y Rmax_na (ciega por diseño del PRT)
        % R7: eco residual llega mientras se transmite (t_residual < tau del TX real)
        en_zona_ciega  = (r_b > Rmax) && (r_b <= Rmax_na);
        eco_durante_tx = (t_residual < tau);   % tau = pulso TX real (no comprimido)
        if en_zona_ciega || eco_durante_tx; continue; end

        % Sumar señal al ruido en la celda
        V_rx(celda_idx) = abs((V_senal + I_ruido(celda_idx)) + ...
                               1j*Q_ruido(celda_idx));

        % Decisión de detección [R4][R10]
        if V_rx(celda_idx) > V_umbral && V_senal >= Vrx_min
            if num_PRTs >= 1
                hist_alp(end+1) = -1.0;  % ambiguo
            else
                hist_alp(end+1) =  1.0;  % real
            end
            hist_r(end+1)   = r_cuant;
            hist_th(end+1)  = theta_antena;
            hist_bid(end+1) = b;
        end
    end

    %% 5.4b  FALSAS ALARMAS — ruido que supera V_umbral [CFAR]
    % Celdas donde solo hay ruido (sin blanco) y aun así superan el umbral.
    % Se registran como detecciones en el ángulo actual de la antena.
    celdas_fa = find(V_rx > V_umbral);
    for ci = celdas_fa(:)'
        r_fa = (ci - 1) * Delta_R_comp;
        % Comprobar que ningún blanco iluminado ocupa esta celda
        % (si la hay, ya está registrada como detección real)
        es_blanco = false;
        for b = 1:num_blancos
            [~, r_b_tmp] = cart2pol(xb_arr(b), yb_arr(b));
            celda_b = max(1, min(num_celdas, round(r_b_tmp/Delta_R_comp) + 1));
            if celda_b == ci
                es_blanco = true;
                break;
            end
        end
        if ~es_blanco
            hist_r(end+1)   = r_fa;
            hist_th(end+1)  = theta_antena;
            hist_alp(end+1) = 0.6;   % alpha inicial más bajo: las FA son tenues
            hist_bid(end+1) = 0;     % 0 = falsa alarma (no es ningún blanco)
        end
    end
    hist_alp = hist_alp - sign(hist_alp) * 0.015;
    validos  = abs(hist_alp) > 0.01;
    hist_r   = hist_r(validos);
    hist_th  = hist_th(validos);
    hist_alp = hist_alp(validos);
    hist_bid = hist_bid(validos);

    %% ================================================================
    %% 5.6  VISUALIZACIÓN
    %% ================================================================
    clf(fig);

    % ── SUBPLOT 1: ESPACIO FÍSICO REAL ────────────────────────────────
    ax1 = subplot(1, 3, 1);
    hold on; grid on; axis equal;
    set(ax1, 'Color','k', 'GridColor',[0.22 0.22 0.22], ...
             'XColor','w', 'YColor','w', 'FontSize',9);
    title('Espacio Fisico Real', 'Color','w', 'FontSize',11, 'FontWeight','bold');

    lim1 = Rmax_na * 1.45 / 1e3;
    xlim([-lim1 lim1]);  ylim([-lim1 lim1]);

    % Sombreado zona ciega
    x_s = [Rmax*cos(ang_circ), fliplr(Rmax_na*cos(ang_circ))]/1e3;
    y_s = [Rmax*sin(ang_circ), fliplr(Rmax_na*sin(ang_circ))]/1e3;
    fill(x_s, y_s, [0.6 0.0 0.0], 'FaceAlpha', 0.18, 'EdgeColor','none');

    % Círculos Rmax y Rmax_na
    plot(Rmax   *cos(ang_circ)/1e3, Rmax   *sin(ang_circ)/1e3, ...
         'r--', 'LineWidth', 1.8);
    plot(Rmax_na*cos(ang_circ)/1e3, Rmax_na*sin(ang_circ)/1e3, ...
         'b-.', 'LineWidth', 1.8);

    % Haz de la antena
    r_haz = lim1 * 1e3;   % el haz llega exactamente al borde visible
    [xa1, ya1] = pol2cart([theta_antena - theta_haz/2, ...
                           theta_antena + theta_haz/2], ...
                          [r_haz, r_haz]);
    fill([0, xa1(1), xa1(2)]/1e3, [0, ya1(1), ya1(2)]/1e3, ...
         [0 0.7 0], 'FaceAlpha', 0.20, 'EdgeColor',[0 0.8 0], 'LineWidth',0.8);

    % Todos los blancos tienen el MISMO tamaño de marcador visual.
    % Lo que los diferencia es su RCS (reflectividad), no el tamaño.
    % prof_vis fija tanto el lado radial como el transversal en km absolutos.
    prof_vis = Rmax_na * 0.022;   % tamaño fijo del marcador (~2.2 % de Rmax_na)

    for b = 1:num_blancos
        [theta_b, r_b] = cart2pol(xb_arr(b), yb_arr(b));
        col = colores_blancos(b, :);

        % ── Borde según zona Y detectabilidad ────────────────────────
        if r_b > Rmax_na
            Pr_test = (Pdg * Gant^2 * lambda^2 * sigma_arr(b)) / ...
                      ((4*pi)^3 * r_b^4 * L_sys);
            V_test  = sqrt(Pr_test);
            if V_test >= Vrx_min
                borde   = [1.0 0.55 0.0];   % naranja: detectable como ambiguo
                txt_est = 'AMB';
            else
                borde   = [0.45 0.45 0.45]; % gris: demasiado débil
                txt_est = 'DEB';
            end
        elseif r_b > Rmax
            borde   = [1.0 0.2 0.2];        % rojo: zona ciega
            txt_est = 'CIEGA';
        else
            borde   = [0.2 1.0 0.2];        % verde: detectable
            txt_est = 'DET';
        end

        % ── Sector con dimensiones fijas en km (igual para todos) ────
        % Dimensión radial  : prof_vis km
        % Dimensión angular : ang_vis = prof_vis / r_b → arco = prof_vis km
        r_safe  = max(r_b, prof_vis);
        ang_vis = prof_vis / r_safe;
        r_in    = max(0, r_b - prof_vis/2);
        r_out   = r_b + prof_vis/2;
        th_lo   = theta_b - ang_vis/2;
        th_hi   = theta_b + ang_vis/2;

        n_arc  = 8;
        th_arc = linspace(th_lo, th_hi, n_arc);
        x_sec  = [r_in*cos(th_arc), fliplr(r_out*cos(th_arc))] / 1e3;
        y_sec  = [r_in*sin(th_arc), fliplr(r_out*sin(th_arc))] / 1e3;
        fill(x_sec, y_sec, col, 'FaceAlpha', 0.85, 'EdgeColor', borde, 'LineWidth', 1.8);

        % Cruz central
        cx = xb_arr(b) / 1e3;
        cy = yb_arr(b) / 1e3;
        plot(cx, cy, '+', 'Color', borde, 'MarkerSize', 5, 'LineWidth', 1.0);

        % Etiqueta: número, RCS y estado
        text(cx + lim1*0.03, cy + lim1*0.025, ...
             sprintf('B%d  %.0fm^2\n%s', b, sigma_arr(b), txt_est), ...
             'Color', col, 'FontSize', 7.5, 'FontWeight', 'bold');

        % Vector de velocidad
        vel_mod = sqrt(vx_arr(b)^2 + vy_arr(b)^2);
        if vel_mod > 0
            esc = (Rmax_na * 0.11) / vel_mod;
            quiver(cx, cy, vx_arr(b)*esc/1e3, vy_arr(b)*esc/1e3, ...
                   0, 'Color', col, 'LineWidth', 1.5, 'MaxHeadSize', 0.9);
        end
    end

    % Leyenda de zonas
    text(-lim1*0.97, lim1*0.97, '- - Rmax',          'Color','r',           'FontSize',8);
    text(-lim1*0.97, lim1*0.89, '-.- Rmax,na',        'Color','b',           'FontSize',8);
    text(-lim1*0.97, lim1*0.81, '[//] Zona ciega',    'Color',[0.9 0.3 0.3], 'FontSize',8);
    text(-lim1*0.97, lim1*0.73, 'Borde: verde=det | rojo=ciega | naranja=amb | gris=debil', ...
         'Color',[0.7 0.7 0.7], 'FontSize',7);
    text(-lim1*0.97, lim1*0.65, sprintf('Celda: %.0fm (comp) x %.1f deg', Delta_R_comp, haz_deg), ...
         'Color',[0.6 0.6 0.6], 'FontSize',7);

    xlabel('km','Color','w');  ylabel('km','Color','w');

    % ── SUBPLOT 2: PANTALLA PPI ────────────────────────────────────────
    ax2 = subplot(1, 3, 2);
    hold on; grid on; axis equal;
    set(ax2, 'Color','k', 'GridColor',[0.15 0.15 0.15], ...
             'XColor','w', 'YColor','w', 'FontSize',9);
    title('Pantalla PPI (Detecciones Radar)', 'Color','w', ...
          'FontSize',11, 'FontWeight','bold');

    lim2 = Rmax_na * 1.15 / 1e3;
    xlim([-lim2 lim2]);  ylim([-lim2 lim2]);

    plot(Rmax   *cos(ang_circ)/1e3, Rmax   *sin(ang_circ)/1e3, 'r--', 'LineWidth',1.5);
    plot(Rmax_na*cos(ang_circ)/1e3, Rmax_na*sin(ang_circ)/1e3, 'b-.', 'LineWidth',1.5);

    [xl, yl] = pol2cart(theta_antena, Rmax_na);
    plot([0, xl]/1e3, [0, yl]/1e3, 'g-', 'LineWidth', 2.0);

    % Detecciones con fade
    prof = max(Delta_R_comp, Rmax_na/60);
    for j = 1:length(hist_r)
        r_j    = hist_r(j);
        th_j   = hist_th(j);
        alp_j  = abs(hist_alp(j));
        b_j    = hist_bid(j);

        r_box  = [r_j-prof/2, r_j+prof/2, r_j+prof/2, r_j-prof/2];
        th_box = [th_j-theta_haz/2, th_j-theta_haz/2, ...
                  th_j+theta_haz/2, th_j+theta_haz/2];
        [xbx, ybx] = pol2cart(th_box, r_box);

        if hist_alp(j) < 0
            % Eco ambiguo → amarillo
            fill(xbx/1e3, ybx/1e3, 'y', 'FaceAlpha', alp_j*0.9, 'EdgeColor','none');
        elseif b_j == 0
            % Falsa alarma (ruido) → blanco tenue
            fill(xbx/1e3, ybx/1e3, [1 1 1], 'FaceAlpha', alp_j*0.6, 'EdgeColor','none');
        else
            % Detección real → color del blanco
            fill(xbx/1e3, ybx/1e3, colores_blancos(b_j,:), ...
                 'FaceAlpha', alp_j*0.9, 'EdgeColor','none');
        end
    end

    text(-lim2*0.97,  lim2*1.00, 'Det. real = color del blanco', 'Color','w','FontSize',7);
    text(-lim2*0.97,  lim2*0.91, 'Eco ambiguo = amarillo',       'Color','y','FontSize',7);
    text(-lim2*0.97,  lim2*0.82, 'Falsa alarma (ruido) = blanco','Color',[0.75 0.75 0.75],'FontSize',7);
    text(-lim2*0.97, -lim2*0.91, sprintf('Rmax = %.0f km',    Rmax/1e3),    'Color','r','FontSize',7);
    text(-lim2*0.97, -lim2*1.00, sprintf('Rmax,na = %.0f km', Rmax_na/1e3), 'Color','b','FontSize',7);

    xlabel('km','Color','w');  ylabel('km','Color','w');

    % ── SUBPLOT 3: A-SCOPE ─────────────────────────────────────────────
    ax3 = subplot(1, 3, 3);
    hold on; grid on;
    set(ax3, 'Color',[0.04 0.04 0.04], 'GridColor',[0.22 0.22 0.22], ...
             'XColor','w', 'YColor','w', 'FontSize',9);

    plot(r_vec/1e3, V_rx, 'b', 'LineWidth', 0.9);
    yline(V_umbral, 'r-',  'LineWidth', 1.8);
    yline(Vrx_min,  'm--', 'LineWidth', 1.4);
    text(Rmax_na*0.01/1e3, V_umbral*1.10, 'V_{umbral}', 'Color','r','FontSize',8);
    text(Rmax_na*0.01/1e3, Vrx_min *1.10, 'V_{rx,min}', 'Color','m','FontSize',8);

    xlabel('Distancia (km)','Color','w');
    ylabel('Voltaje (V)',   'Color','w');
    xlim([0, Rmax_na/1e3]);
    ylim([0, max(max(V_rx)*1.2, V_umbral*4)]);
    title(sprintf('A-Scope  —  \\DeltaR_{comp}=%.0fm  (CR=%.0f)', ...
          Delta_R_comp, CR), 'Color','w', 'FontSize',10);

    drawnow;
end

%% =========================================================================
%% FUNCIÓN AUXILIAR
%% =========================================================================
function val = radar_input(in, default)
    if isempty(in)
        val = default;
    else
        val = in;
    end
end