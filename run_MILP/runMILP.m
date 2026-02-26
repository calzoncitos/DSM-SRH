%% Microgrid_Zplschedule

clearvars; clc; close all;

%% Insert parameters data 
data = readtable('energy_data.csv');

% Inflexible load data
Pli = data.Load;
nT = length(Pli);

% PV parameters
Pp_data   = data.PV;         % PV(kW) from energy data file

pv_area   = 600;             % introduce total PV area on site
pv_effcy  = 0.22;            % introduce PV eficiency factor
Pp_belle    = preprocessIrradiance('PyranoBelleJournee.csv', pv_area, pv_effcy);

Pp = Pp_belle;               % Choose PV generation source from data, or Pyrano datasets

% Tariff electricity cost
C_in = data.ImportTariff;    % Choose constant or dynamic tariff strategy
C_ex = data.ExportTariff;    % Choose constant or dynamic tariff strategy

% Dispatchable loads parameters
dispatchLoad.allowed_hours = 7:20;
dispatchLoad.Pmax = 5;       % Max power for dispatchable load at each timestep
dispatchEld = 15;            % total dispatchable load


% Scheduling load parameters
Els = 20;                    % total schedulable load
Pfixed = 4;                  % fixed schedulable load per hour
allowed_hours = 7:16;        % allowed hours for schedulable load
timePls =  Els / Pfixed;     % number of consecutive hours for schedulable load


%% Equality constraints Aeq, beq
% Equality matrix block function
[Aeq, beq, nBlockX] = MGdMatrices_Zpls(Pp, Pli, Pfixed);
nVars = size(Aeq,2);

% energy eqs for Pld
rowPld = zeros(1,nVars); 
rowPld(5:nBlockX:nVars) = 1; % rowPld = 1 for the one hour timestep (change this if timestep is different to hourly)
Aeq = [Aeq; rowPld];
beq = [beq; dispatchEld];

% energy eqs for Pls
rowZPls = zeros(1,nVars); 
rowZPls(6:nBlockX:nVars) = Pfixed;
Aeq = [Aeq; rowZPls]; 
beq = [beq; Els];

nVars = size(Aeq,2);

%% Objective Function / Cost vector
% X =          [ Ppl ,        Ppg ,     Pg ,      Pgl ,    Pld ,       ZPls          Zs      ]
cost_matrix = [ zeros(nT,1), -C_ex, zeros(nT,1), C_in, zeros(nT,1), zeros(nT,1), zeros(nT,1)];
f = reshape(cost_matrix.', [], 1);


%% Bounds
% general lower and upper bounds
lb = zeros(nVars,1); 
ub = inf(nVars,1); 

pg  = 3:nBlockX:nVars;  % index for Grid variable
pld = 5:nBlockX:nVars;  % index for Dispatchable variable
Zpls = 6:nBlockX:nVars; % index for Schedulable variable
zs   = 7:nBlockX:nVars; % index for binary start indicator variable

% grid bounds
lb(pg) = -inf; 
ub(pg) = inf; 

% Dispatchable load bounds
ub(pld) = dispatchLoad.Pmax;
lb(pld) = 0;

% Binary schedulable bounds Zpls
lb(Zpls) = 0; 
ub(Zpls) = 1; 
% Binary start indicator Zs
lb(zs) = 0; 
ub(zs) = 1; 
% Integer formulation
intcon = [Zpls, zs];



%% inequality constraints
[Aineq, bineq] = MGdIneqBlock(nT, timePls, Zpls, zs, nVars);

% Single start for schedulable load
row = zeros(1,nVars); 
row(zs) = 1;
Aeq = [Aeq; row]; 
beq = [beq; 1];

% Time window restriction fos schedulable load
start_window = max(allowed_hours) - timePls + 1;
excluded = (1:nT < min(allowed_hours)) | (1:nT > start_window);
ub(zs(excluded)) = 0;

% Time window restriction for dispatchable load
all_hours = 1:nT;

outside_d = (all_hours < min(dispatchLoad.allowed_hours)) | (all_hours > max(dispatchLoad.allowed_hours));
pld_outside = pld(outside_d);
ub(pld_outside) = 0;

%%  MILP formulation
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

total_cost = fval;
fprintf('Total Cost: %.2f ct\n', fval);


%% Visualization plots for comparing scenarios
t = 1:nT;
plotEnergySystem(t, Pli, Pld, Pls, Ppl, Ppg, Pgl, X, C_in, C_ex);


%% Baseline scenario comparisson analysis

[Pld_base, Pls_base, Pli_base, start_base, Ppl_base, Ppg_base, Pgl_base, Pg_base, total_cost_base, Ptotal_base] = ...
    buildBaselineScenario('random', Pli, dispatchLoad, dispatchEld, Els, Pfixed, allowed_hours, nT, Pp, C_in, C_ex);

Ptotal_opt = Pli(:) + Pld(:) + Pls(:); % optimal total load for comparisson scenario
cost_import_opt = C_in.* Pgl(:);
cost_export_opt = -C_ex .* Ppg(:);
total_cost_opt  = sum(cost_import_opt + cost_export_opt);


metrics = table(total_cost_base, total_cost_opt, ...
    sum(Pgl_base),   sum(Pgl), ...
    sum(Ppg_base),   sum(Ppg), ...
    sum(Ppl_base),   sum(Ppl), ...
    max(Ptotal_base),max(Ptotal_opt), ...
'VariableNames', {'Cost_base','Cost_opt', 'Import_kWh_base','Import_kWh_opt', ...
'Export_kWh_base','Export_kWh_opt', 'PV_to_load_kWh_base','PV_to_load_kWh_opt', ...
'Peak_load_kW_base','Peak_load_kW_opt' });
disp(metrics);

[T_abs, T_imp] = compareBaselines(Pli, Pp, C_in, C_ex, dispatchEld, Els, Pfixed, allowed_hours, Pld, Pls, Ptotal_opt, Ppl, Pgl, Ppg);
disp('=== ABSOLUTE METRICS ===');
disp(T_abs);
compareScenarios(t, Ptotal_base, Ptotal_opt, Pld_base, Pld, Pls_base, Pls, Ppl_base, Ppl, Ppg_base, Ppg, Pgl_base, Pgl)

% Find star hour indices for Schedulable loads distribution
start_hour_opt = find(Zs==1);
on_hours_opt   = find(ZPls==1);
fprintf('Baseline Pls start = %d, ON = %s\n', start_base, mat2str(start_base:(start_base+timePls-1)));
fprintf('Optimized Pls start = %d, ON = %s\n', start_hour_opt, mat2str(on_hours_opt));

