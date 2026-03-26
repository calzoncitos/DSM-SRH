clearvars; clc; close all;


%% Load data 15 min steps
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

Pli  = interp1(time_hourly, data.Load, time, 'linear', 'extrap');
Pp   = interp1(time_hourly, Pp, time, 'linear', 'extrap');
C_in = interp1(time_hourly, data.ImportTariff, time, 'linear', 'extrap');
C_ex = interp1(time_hourly, data.ExportTariff, time, 'linear', 'extrap');

% dispatchable loads PEV
dispatchLoad.E = 10;
dispatchLoad.allowed_hours = 9:18;
dispatchLoad.Pmax = 7;

Eld = 10; % total dispatchable load

eta = 0.95; 
 
SOC0 = 10;                % initial kWh 
SOC_req = 20;             % required at departure

Pch_const = 3.7;          % kW charging 
Pdis_const = 3.7;         % kW discharging

% Scheduling load parameters DISHWASHER
Els = 2.5;                % total schedulable load
allowed_hours = 12:18;    % allowed hours for schedulable load
timePls = 1.5;            % number of consecutive hours for schedulable load
Pfixed = Els / timePls;  

%% Equality constraints Aeq, beq
[Aeq, beq, nBlockX] = EVMGdMatrices_Zplsminutes(Pp, Pli, Pfixed);
nVars = size(Aeq,2);


% energy eqs for Pls
rowZPls = zeros(1,nVars); 
rowZPls(6:nBlockX:nVars) = Pfixed * dt;
Aeq = [Aeq; rowZPls]; 
beq = [beq; Els];

nVars = size(Aeq,2);




%% Cost vector
% X =          [ Ppl ,        Ppg ,       Pg ,        Pgl ,    PEV ,       ZPls              Zs  ,       SOC   ,    y_ch,       y_dis    ]
cost_matrix = [ zeros(nT,1), -C_ex*dt, zeros(nT,1), C_in*dt, zeros(nT,1), zeros(nT,1), zeros(nT,1), zeros(nT,1), zeros(nT,1), zeros(nT,1)];
epsilon = 0.01; 
cost_matrix(:,5) = cost_matrix(:,5) + epsilon*dt;
f = reshape(cost_matrix.', [], 1);


%% Bounds
% general lower and upper bounds
lb = zeros(nVars,1); 
ub = inf(nVars,1); 

pg  = 3:nBlockX:nVars; 
pEV = 5:nBlockX:nVars;
Zpls = 6:nBlockX:nVars; 
zs   = 7:nBlockX:nVars; 
socEV  = 8:nBlockX:nVars; % EV discharging 
y_ch = 9:nBlockX:nVars; 
y_dis = 10:nBlockX:nVars;


% grid bounds
lb(pg) = -inf; 
ub(pg) = inf; 

% binary schedulable bounds Zpls
lb(Zpls) = 0; 
ub(Zpls) = 1; 
% binary start indicator Zs
lb(zs) = 0; 
ub(zs) = 1; 



% EV discharge bounds 
lb(pEV) = -dispatchLoad.Pmax;   % discharge
ub(pEV) =  dispatchLoad.Pmax;   % charge


% SOC bounds 
SOC_min = 0;
SOC_max = 40;
lb(socEV) = SOC_min;
ub(socEV) = SOC_max;

% Initial SOC 
row0 = zeros(1, nVars); 
row0(socEV(1)) = 1; 
Aeq = [Aeq; row0]; 
beq = [beq; SOC0];

lb(y_ch) = 0; ub(y_ch) = 1; 
lb(y_dis) = 0; ub(y_dis) = 1; 
intcon = [Zpls, zs, y_ch, y_dis];

for k = 1:nT
    row = zeros(1,nVars);
    row(pEV(k))   = 1;
    row(y_ch(k))  = -Pch_const;
    row(y_dis(k)) =  Pdis_const;
    Aeq = [Aeq; row];
    beq = [beq; 0];
end

%% inequality constraints
[Aineq, bineq] = CMGdIneqBlockminutesEV(nT, timePls, Zpls, zs, nVars, dt);

% Single start
row = zeros(1,nVars); 
row(zs) = 1;
Aeq = [Aeq; row]; 
beq = [beq; 1];

% Time-window restriction
allowed_idx   = round(allowed_hours / dt) + 1;
H_steps       = round(timePls / dt);  
start_window  = max(allowed_idx) - H_steps + 1; 

excluded = (1:nT < min(allowed_idx)) | (1:nT > start_window);
ub(zs(excluded)) = 0;


allowed_EV = (time >= min(dispatchLoad.allowed_hours)) & ...
             (time <= max(dispatchLoad.allowed_hours));
ub(pEV(~allowed_EV)) = 0; 
lb(pEV(~allowed_EV)) = 0;


% SOC(t+1) - SOC(t) - eta_ch*Pld(t)*dt + (1/eta_dis)*PdisEV(t)*dt = 0
for k = 1:nT-1 row = zeros(1, nVars); 
    row(socEV(k+1)) = 1; 
    row(socEV(k)) = -1; 
    row(pEV(k)) = eta * dt; 
    Aeq = [Aeq; row]; 
    beq = [beq; 0]; 
end 




%%  MILP
[x_opt, fval] = intlinprog(f, intcon, [], [], Aeq, beq, lb, ub);

% reshape solution
X = reshape(x_opt, nBlockX, []);
    Ppl = X(1,:);
    Ppg = X(2,:);
    Pg  = X(3,:);
    Pgl = X(4,:);
    PEV = X(5,:);
    ZPls = X(6,:);
    Zs  = X(7,:);
    SOCev = X(8,:);
    y_ch = X(9,:);
    y_dis = X(10,:);


Pls = ZPls * Pfixed;
EV_charge    = max(PEV, 0);
EV_discharge = max(-PEV, 0);

fprintf('min SOC = %.2f, max SOC = %.2f\n', min(SOCev), max(SOCev));
fprintf('sum(Zs) = %d\n', sum(Zs));
fprintf('sum(ZPls) = %d\n', sum(ZPls));

total_cost = fval;
fprintf('Total Cost: %.2f ct\n', fval);


fprintf('Dishwasher energy = %.2f kWh\n', sum(Pls)*dt);
fprintf('ZPls count = %d (expected = %.2f hours)\n', sum(ZPls), H_steps*dt);

%% Visualization plots for comparing scenarios
time_hours = (0:nT-1) * dt;  
plotEnergySystemminutes(time_hours, Pli, PEV, Pls, Ppl, Ppg, Pgl, X, C_in, C_ex, Pp);



%% === EV Charging / Discharging Plot ===
t = time_hours;
%% === EV Charging / Discharging Plot ===
figure;
hold on;
stairs(t, PEV, 'LineWidth', 2, 'Color', [0.2 0.6 0.8], 'DisplayName','EV Charge (Pld)');
stairs(t, EV_discharge, 'LineWidth', 2, 'Color', [0.8 0.3 0.3], 'DisplayName','EV Discharge (PdisEV)');
xlabel('Time [hours]');
ylabel('kW');
title('EV Charging and Discharging');
legend('Location','best');
grid on;
xlim([min(t) max(t)]);

%% EV State of Charge
figure;
plot(t, SOCev, 'LineWidth', 2, 'Color', [0.1 0.4 0.7]);
xlabel('Time [hours]');
ylabel('SOC [kWh]');
title('EV State of Charge');
grid on;
xlim([min(t) max(t)]);

%% Full Energy Balance Including EV
Pli = Pli(:); Pls = Pls(:); EV_charge= EV_charge(:);
Ptotal = Pli + EV_charge + Pls;



