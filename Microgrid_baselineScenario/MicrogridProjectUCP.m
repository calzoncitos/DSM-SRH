clearvars; clc; close all;


%% Load data
dt = 15/60;     
nT = round(24/dt); 
time = (0:nT-1)' * dt;  

data = readtable('energy_data.csv');  
time_hourly = (0:23)';
Pp_data     = data.PV;

pv_area   = 600; 
pv_effcy = 0.22; 
Pp_belle    = preprocessIrradiance('PyranoBelleJournee.csv', pv_area, pv_effcy);
Pp = Pp_belle;

% since the 'energy_data.csv' file has hourly data, the next
% linecodes will convert them into 15min timesteps.
Pli  = interp1(time_hourly, data.Load, time, 'linear', 'extrap');
Pp   = interp1(time_hourly, Pp, time, 'linear', 'extrap');
C_in = interp1(time_hourly, data.ImportTariff, time, 'linear', 'extrap');
C_ex = interp1(time_hourly, data.ExportTariff, time, 'linear', 'extrap');

% dispatchable loads - EV parameters
dispatchLoad.E = 10;
dispatchLoad.allowed_hours = 9:14;
dispatchLoad.Pmax = 3;

Eld = 10; % total dispatchable load


% Scheduling load parameters - Dishwasher parameters
Els = 2.5;                  % total schedulable load
allowed_hours = 8:14;       % allowed hours for schedulable load
timePls = 1.5;              % number of consecutive hours for schedulable load
Pfixed = Els / timePls;  

%% Equality constraints Aeq, beq
[Aeq, beq, nBlockX] = MGdMatrices_Zplsminutes(Pp, Pli, Pfixed);
nVars = size(Aeq,2);

% energy eqs for Pld
rowPld = zeros(1,nVars); 
rowPld(5:nBlockX:nVars) = dt;
Aeq = [Aeq; rowPld];
beq = [beq; Eld];

% energy eqs for Pls
rowZPls = zeros(1,nVars); 
rowZPls(6:nBlockX:nVars) = Pfixed * dt;
Aeq = [Aeq; rowZPls]; 
beq = [beq; Els];

nVars = size(Aeq,2);

%% Cost vector
% X =         [ Ppl ,          Ppg ,      Pg ,        Pgl ,    Pld ,       ZPls           Zs      ]
cost_matrix = [ zeros(nT,1), -C_ex*dt, zeros(nT,1), C_in*dt, zeros(nT,1), zeros(nT,1), zeros(nT,1)];
f = reshape(cost_matrix.', [], 1);


%% Bounds
% general lower and upper bounds
lb = zeros(nVars,1); 
ub = inf(nVars,1); 

pg  = 3:nBlockX:nVars; 
pld = 5:nBlockX:nVars;
Zpls = 6:nBlockX:nVars; 
zs   = 7:nBlockX:nVars; 

% grid bounds
lb(pg) = -inf; 
ub(pg) = inf; 

% dispatchable energy bounds
ub(pld) = dispatchLoad.Pmax  * ones(size(pld));
lb(pld) = 0;
% binary schedulable bounds Zpls
lb(Zpls) = 0; 
ub(Zpls) = 1; 
% binary start indicator Zs
lb(zs) = 0; 
ub(zs) = 1; 

intcon = [Zpls, zs];

%% inequality constraints
[Aineq, bineq] = MGdIneqBlockminutes(nT, timePls, Zpls, zs, nVars, dt);

% Single start
row = zeros(1,nVars); 
row(zs) = 1;
Aeq = [Aeq; row]; 
beq = [beq; 1];

% Time-window restriction
allowed_idx   = round(allowed_hours / dt) + 1;
H_steps       = round(timePls / dt);  
start_window  = max(allowed_idx) - H_steps + 1;    % last valid start index

excluded = (1:nT < min(allowed_idx)) | (1:nT > start_window);
ub(zs(excluded)) = 0;


allowed_EV = (time >= min(dispatchLoad.allowed_hours)) & ...
             (time <= max(dispatchLoad.allowed_hours));
ub(pld(~allowed_EV)) = 0;


%%  MILP
[x_opt, fval] = intlinprog(f, intcon, Aineq, bineq, Aeq, beq, lb, ub);

% reshape solution
X = reshape(x_opt, nBlockX, []);
    Ppl = X(1,:);
    Ppg = X(2,:);
    Pg  = X(3,:);
    Pgl = X(4,:);
    Pld = X(5,:);
    ZPls = X(6,:);
    Zs  = X(7,:);

Pls = ZPls * Pfixed;

total_cost = sum(C_in .* Pgl(:) * dt - C_ex .* Ppg(:) * dt);
fprintf('Total Cost: %.2f ct\n', total_cost);

fprintf('EV energy = %.2f kWh\n', sum(Pld)*dt);
fprintf('Dishwasher energy = %.2f kWh\n', sum(Pls)*dt);
fprintf('ZPls count = %d (expected = %d)\n', sum(ZPls), H_steps, H_steps*dt);

%% Visualization plots for comparing scenarios
time_hours = (0:nT-1) * dt;  
plotEnergySystemminutes(time_hours, Pli, Pld, Pls, Ppl, Ppg, Pgl, X, C_in, C_ex, Pp);


%% Baseline scenario 
% this baseline scenario simulates a scenario without optimizing schedules
% to compare with opt values from MILP
[Pld_base, Pls_base, Pli_base, start_base, Ppl_base, Ppg_base, Pgl_base, Pg_base, total_cost_base, Ptotal_base] = buildBaselineScenarioMinutes(Pli, Eld, Els, Pfixed, allowed_hours, nT, Pp, C_in, C_ex, 'stochastic',dt);

Ptotal_opt = Pli(:) + Pld(:) + Pls(:); % total load
cost_import_opt = C_in.* Pgl(:)*dt;
cost_export_opt = -C_ex .* Ppg(:)*dt;
total_cost_opt  = sum(cost_import_opt + cost_export_opt);

metrics = table(total_cost_base, total_cost_opt, ...
    sum(Pgl_base)*dt,   sum(Pgl)*dt, ...
    sum(Ppg_base)*dt,   sum(Ppg)*dt, ...
    sum(Ppl_base)*dt,   sum(Ppl)*dt, ...
    max(Ptotal_base)*dt,max(Ptotal_opt)*dt, ...
    'VariableNames', {'Cost_base','Cost_opt', 'Import_kWh_base','Import_kWh_opt', ...
        'Export_kWh_base','Export_kWh_opt', 'PV_to_load_kWh_base','PV_to_load_kWh_opt', ...
        'Peak_load_kW_base','Peak_load_kW_opt' });

toHM = @(h) sprintf('%02d:%02d', floor(h), round((h - floor(h))*60));
start_hour_opt = find(Zs==1);
on_hours_opt   = find(ZPls==1);
start_str = toHM(time_hours(start_hour_opt));
on_strs   = arrayfun(@(h) toHM(h), time_hours(on_hours_opt), 'UniformOutput', false);
fprintf('Optimized Pls start = %s, ON = %s\n', start_str, strjoin(on_strs, ', '));

PV_total = sum(Pp) * dt;
SCR_opt  = sum(Ppl) * dt / PV_total;
SCR_base = sum(Ppl_base) * dt / PV_total;


disp(metrics);

