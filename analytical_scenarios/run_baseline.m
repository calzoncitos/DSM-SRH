function results = run_baseline()

%% Microgrid_baselineScenario


%% Time and data
dt = 15/60;
nT = round(24/dt);
time = (0:nT-1)' * dt;

data = readtable('energy_data.csv');
time_hourly = (0:23)';

Pli  = interp1(time_hourly, data.Load, time, 'linear', 'extrap');
Pp   = interp1(time_hourly, data.PV,   time, 'linear', 'extrap');
C_in = interp1(time_hourly, data.ImportTariff, time, 'linear', 'extrap');
C_ex = interp1(time_hourly, data.ExportTariff, time, 'linear', 'extrap');

%% Baseline EV charging (07:00–11:00)
EV_power = 3; % kW
EV_energy_req = 10; % kWh

EV_profile = zeros(nT,1);
idx_EV = (time >= 9 & time < 13);
EV_profile(idx_EV) = EV_power;

% Cap energy to 10 kWh
EV_energy = sum(EV_profile)*dt;
if EV_energy > EV_energy_req
    EV_profile(idx_EV) = EV_profile(idx_EV) * (EV_energy_req / EV_energy);
end

%% Baseline dishwasher (09:00–10:30)
DW_power = 2.5 / 1.5; % 1.67 kW
DW_profile = zeros(nT,1);
idx_DW = (time >= 9 & time < 10.5);
DW_profile(idx_DW) = DW_power;

%% Total load
Ptotal = Pli + EV_profile + DW_profile;

%% Grid interaction
Pg = Ptotal - Pp;
Pgl = max(Pg,0);
Ppg = max(-Pg,0);

%% Cost
cost = sum(Pgl .* C_in * dt - Ppg .* C_ex * dt);

fprintf("Baseline cost = %.2f ct\n", cost);
fprintf("EV energy = %.2f kWh\n", sum(EV_profile)*dt);
fprintf("Dishwasher energy = %.2f kWh\n", sum(DW_profile)*dt);


%%  METRICS CALCULATION

% Dishwasher load (Pls) may not exist in baseline → define safely
if ~exist('Pls','var')
    if exist('DW_profile','var')
        Pls = DW_profile(:);
    else
        Pls = zeros(nT,1);
    end
end

% Total load starts with base load + dishwasher
Ptotal = Pli(:) + Pls(:);

% Add EV load depending on scenario
if exist('Pld','var')   % Scenario 2 (EV charging only)
    Ptotal = Ptotal + Pld(:);
end

if exist('PEV','var')   % Scenario 3 (V2G)
    Ptotal = Ptotal + PEV(:);
end

if exist('EV_profile','var')   % Baseline
    Ptotal = Ptotal + EV_profile(:);
end

% Grid interaction
Pg  = Ptotal - Pp(:);
Pgl = max(Pg,0);     % import
Ppg = max(-Pg,0);    % export

% Cost
total_cost = sum(Pgl .* C_in * dt - Ppg .* C_ex * dt);

% PV self-consumption
Ppl = min(Pp(:), Ptotal);
PV_to_load = sum(Ppl * dt);

% Peak load
peak_load = max(Ptotal);

% Dishwasher start time
if exist('ZPls','var')
    idx = find(ZPls == 1, 1, 'first');
    if ~isempty(idx)
        DW_start_time = time(idx);
    else
        DW_start_time = NaN;
    end
elseif exist('DW_profile','var')
    idx = find(DW_profile > 0, 1, 'first');
    DW_start_time = time(idx);
else
    DW_start_time = NaN;
end

% EV energy metrics
EV_charge_energy = 0;
EV_discharge_energy = 0;

if exist('Pld','var')
    EV_charge_energy = sum(Pld)*dt;
end

if exist('PEV','var')
    EV_charge_energy    = sum(max(PEV,0))*dt;
    EV_discharge_energy = sum(max(-PEV,0))*dt;
end

if exist('EV_profile','var')
    EV_charge_energy = sum(EV_profile)*dt;
end

% SOC at departure (Scenario 3 only)
if exist('SOCev','var')
    SOC_departure = SOCev(find(time <= 18, 1, 'last'));
else
    SOC_departure = NaN;
end

%%  PRINT BASELINE RESULTS

% Energies
Import_energy = sum(Pgl(:) * dt);
Export_energy = sum(Ppg(:) * dt);
PV_to_load    = sum(Ppl(:) * dt);
peak_load     = max(Ptotal);

% Cost result
total_cost = sum(Pgl .* C_in * dt) - sum(Ppg .* C_ex * dt);

fprintf("\n===== BASELINE METRICS =====\n");
fprintf("Total cost: %.2f ct\n", total_cost);
fprintf("Import energy: %.2f kWh\n", Import_energy);
fprintf("Export energy: %.2f kWh\n", Export_energy);
fprintf("PV-to-load: %.2f kWh\n", PV_to_load);
fprintf("Peak load: %.2f kW\n", peak_load);
fprintf("Dishwasher energy: %.2f kWh\n", sum(Pls)*dt);
fprintf("============================\n\n");



%   BASELINE METRICS

% Total load = inflexible load + dishwasher
Ptotal = Pli(:) + Pls(:);

total_cost = sum(Pgl .* C_in * dt) - sum(Ppg .* C_ex * dt);
Import_energy = sum(Pgl * dt);
Export_energy = sum(Ppg * dt);
PV_to_load = sum(Ppl * dt);
peak_load = max(Ptotal);

results.total_cost    = total_cost;
results.import_energy = Import_energy;
results.export_energy = Export_energy;
results.pv_self       = PV_to_load;
results.peak_load     = peak_load;
results.time    = time(:);
results.Ptotal = Ptotal(:);
results.Pgl    = Pgl(:);
results.Ppg    = Ppg(:);
results.Ppl    = Ppl(:);


%   BASELINE PLOTS
% Total load = inflexible load + dishwasher (fixed profile)
Ptotal = Pli(:) + Pls(:);

figure; hold on; grid on;
plot(time, Ptotal, 'k', 'LineWidth', 2);
plot(time, Ppl, 'g', 'LineWidth', 1.5);
plot(time, Pgl, 'r', 'LineWidth', 1.5);
plot(time, -Ppg, 'b', 'LineWidth', 1.5);
plot(time, Pls, 'm', 'LineWidth', 1.5);

xlabel('Time [h]');
ylabel('Power [kW]');
title('Baseline Microgrid Power Flows');
legend('Total Load','PV→Load','Grid Import','Grid Export','Dishwasher');
xlim([0 24]);
ylim([-10 10]);

end