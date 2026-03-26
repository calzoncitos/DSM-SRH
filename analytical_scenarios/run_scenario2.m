function results = run_scenario2()

%% Microgrid_EV+dishwasher


%% data
dt = 15/60;
nT = round(24/dt);
time = (0:nT-1)' * dt;

data = readtable('energy_data.csv');
time_hourly = (0:23)';

Pli  = interp1(time_hourly, data.Load, time, 'linear', 'extrap');
Pp   = interp1(time_hourly, data.PV,   time, 'linear', 'extrap');
C_in = interp1(time_hourly, data.ImportTariff, time, 'linear', 'extrap');
C_ex = interp1(time_hourly, data.ExportTariff, time, 'linear', 'extrap');

%% EV parameters
EV_energy_req = 10;
EV_Pmax = 3;
EV_allowed = (time >= 7 & time <= 18);
EV_allowed = (time >= 7 & time <= 18); 
EV_duration = sum(EV_allowed) * dt;
if EV_Pmax * EV_duration < EV_energy_req
    error('EV energy requirement infeasible with current window/Pmax');
end


%% Dishwasher parameters
Els = 2.5;
timePls = 1.5;
Pfixed = Els / timePls;
DW_allowed = (time >= 8 & time <= 22);
allowed_hours = 8:22;

%% Build MILP matrices
[Aeq, beq, nBlockX] = MGdMatrices_Zplsminutes(Pp, Pli, Pfixed);
nVars = size(Aeq,2);

% EV energy constraint
rowEV = zeros(1,nVars);
rowEV(5:nBlockX:nVars) = dt;
Aeq = [Aeq; rowEV];
beq = [beq; EV_energy_req];

% Dishwasher energy constraint
rowDW = zeros(1,nVars);
rowDW(6:nBlockX:nVars) = Pfixed * dt;
Aeq = [Aeq; rowDW];
beq = [beq; Els];

%% Cost vector
cost_matrix = [zeros(nT,1), -C_ex*dt, zeros(nT,1), C_in*dt, zeros(nT,1), zeros(nT,1), zeros(nT,1)];
f = reshape(cost_matrix.', [], 1);

%% Bounds
lb = zeros(nVars,1);
ub = inf(nVars,1);

pg  = 3:nBlockX:nVars;
pld = 5:nBlockX:nVars;
Zpls = 6:nBlockX:nVars;
zs   = 7:nBlockX:nVars;

lb(pg) = -inf;
ub(pg) = inf;

lb(pld) = 0;
ub(pld) = EV_Pmax;

lb(Zpls) = 0; ub(Zpls) = 1;
lb(zs) = 0; ub(zs) = 1;

intcon = [Zpls, zs];

%% Allowed hours
ub(pld(~EV_allowed)) = 0;

%% Dishwasher start constraint
[Aineq, bineq] = MGdIneqBlockminutes(nT, timePls, Zpls, zs, nVars, dt);

row = zeros(1,nVars);
row(zs) = 1;
Aeq = [Aeq; row];
beq = [beq; 1];

% Dishwasher time-window restriction
H_steps = round(timePls / dt);   % 6 steps for 1.5 h

DW_start_hour = min(allowed_hours);   % e.g. 8
DW_end_hour   = max(allowed_hours);   % e.g. 22

% earliest and latest *start* times in hours
DW_start_min_h = DW_start_hour;
DW_start_max_h = DW_end_hour - timePls;   % must leave room for full 1.5 h

% convert to indices
start_min = round(DW_start_min_h / dt) + 1;
start_max = round(DW_start_max_h / dt) + 1;

fprintf('Dishwasher allowed start indices: %d to %d\n', start_min, start_max);

if start_max < start_min
    error('Infeasible: dishwasher window too narrow for 1.5 h');
end

all_starts = 1:nT;
excluded = (all_starts < start_min) | (all_starts > start_max);

ub(zs(excluded)) = 0;   % Zs can only be 1 inside this window



% Zs can only be 1 inside the allowed start window
ub(zs(excluded)) = 0;





%% Solve MILP
[x_opt, fval] = intlinprog(f, intcon, Aineq, bineq, Aeq, beq, lb, ub);


X    = reshape(x_opt, nBlockX, []);
Ppl  = X(1,:);
Ppg  = X(2,:);
Pg   = X(3,:);
Pgl  = X(4,:);
Pld  = X(5,:);
ZPls = X(6,:);
Zs   = X(7,:);

Pls  = ZPls * Pfixed;


fprintf("Optimized cost = %.2f ct\n", fval);
fprintf("EV energy = %.2f kWh\n", sum(Pld)*dt);
fprintf("Dishwasher energy = %.2f kWh\n", sum(Pls)*dt);


%% METRICS (Scenario 2)

% Use decision variables directly
Ptotal = Pli(:) + Pld(:) + Pls(:);  
PV_to_load = sum(Ppl(:) * dt);    
Import_energy = sum(Pgl(:) * dt);
Export_energy = sum(Ppg(:) * dt);
peak_load = max(Ptotal);

% Cost: use fval 
total_cost = fval;

% Dishwasher start time
idx = find(ZPls == 1, 1, 'first');
DW_start_time = time(idx);

fprintf("\n===== SCENARIO 2 METRICS =====\n");
fprintf("Total cost: %.2f ct\n", total_cost);
fprintf("Import energy: %.2f kWh\n", Import_energy);
fprintf("Export energy: %.2f kWh\n", Export_energy);
fprintf("PV-to-load (via Ppl): %.2f kWh\n", PV_to_load);
fprintf("Peak load: %.2f kW\n", peak_load);
fprintf("Dishwasher start: %02d:%02d\n", floor(DW_start_time), round((DW_start_time-floor(DW_start_time))*60));
fprintf("EV charged energy: %.2f kWh\n", sum(Pld)*dt);
fprintf("EV discharged energy: 0.00 kWh\n");
fprintf("================================\n\n");


%% SCENARIO 2 PLOTS


Ptotal = Pli(:) + Pls(:) + Pld(:);   % EV only charges

figure; hold on; grid on;
plot(time, Ptotal, 'k', 'LineWidth', 2);
plot(time, Ppl, 'g', 'LineWidth', 1.5);
plot(time, Pgl, 'r', 'LineWidth', 1.5);
plot(time, -Ppg, 'b', 'LineWidth', 1.5);
plot(time, Pls, 'm', 'LineWidth', 1.5);
plot(time, Pld, 'c', 'LineWidth', 1.5);

xlabel('Time [h]');
ylabel('Power [kW]');
title('Scenario 2: EV + Dishwasher');
legend('Total Load','PV→Load','Grid Import','Grid Export','Dishwasher','EV Charge');
xlim([0 24]);


Import_energy = sum(Pgl * dt);
Export_energy = sum(Ppg * dt);
PV_to_load    = sum(Ppl * dt);
peak_load     = max(Ptotal);

results.total_cost    = total_cost;
results.import_energy = Import_energy;
results.export_energy = Export_energy;
results.pv_self       = PV_to_load;
results.peak_load     = peak_load;
results.PEV = Pld(:);
results.Ptotal = Ptotal(:);
results.Pgl    = Pgl(:);
results.Ppg    = Ppg(:);
results.Ppl    = Ppl(:);
results.time    = time(:);


end