function results = run_scenario3()

%% Microgrid_EV + Battery + Dishwasher
% DATA


dt = 15/60;
nT = round(24/dt);
time = (0:nT-1)' * dt;

data = readtable('energy_data.csv');
time_hourly = (0:23)';

Pli  = interp1(time_hourly, data.Load, time, 'linear','extrap');
Pp   = interp1(time_hourly, data.PV,   time, 'linear','extrap');
C_in = interp1(time_hourly, data.ImportTariff, time,'linear','extrap');
C_ex = interp1(time_hourly, data.ExportTariff, time,'linear','extrap');

%% EV PARAMETERS


EV_Pmax = 3.7;
EV_allowed = (time >= 7 & time <= 18);

SOC0 = 10;
SOC_req = 20;
SOC_min = 0;
SOC_max = 40;
eta = 0.95;

%% DISHWASHER PARAMETERS

Els = 2.5;              % kWh
timePls = 1.5;          % hours
Pfixed = Els/timePls;   % kW
allowed_hours = 8:22;

H_steps = round(timePls/dt);

%% BUILD BASE MATRICES


[Aeq, beq, nBlockX] = EVMGdMatrices_Zplsminutes(Pp, Pli, Pfixed);
nVars = size(Aeq,2);

%% COST VECTOR


cost_matrix = [zeros(nT,1), -C_ex*dt,  zeros(nT,1),  C_in*dt,  zeros(nT,6)];
f = reshape(cost_matrix.',[],1);

%% VARIABLE INDICES


pg    = 3:nBlockX:nVars;
pEV   = 5:nBlockX:nVars;
Zpls  = 6:nBlockX:nVars;
zs    = 7:nBlockX:nVars;
socEV = 8:nBlockX:nVars;
y_ch  = 9:nBlockX:nVars;
y_dis = 10:nBlockX:nVars;

%% BOUNDS


lb = zeros(nVars,1);
ub = inf(nVars,1);

lb(pg) = -inf;  ub(pg) = inf;

lb(pEV) = -EV_Pmax;
ub(pEV) =  EV_Pmax;

lb(Zpls) = 0; ub(Zpls) = 1;
lb(zs)   = 0; ub(zs)   = 1;

lb(socEV) = SOC_min;
ub(socEV) = SOC_max;

lb(y_ch)  = 0; ub(y_ch)  = 1;
lb(y_dis) = 0; ub(y_dis) = 1;

intcon = [Zpls zs y_ch y_dis];

%% INITIAL SOC


row = zeros(1,nVars);
row(socEV(1)) = 1;
Aeq = [Aeq; row];
beq = [beq; SOC0];

%% EV ALLOWED HOURS


ub(pEV(~EV_allowed)) = 0;
lb(pEV(~EV_allowed)) = 0;

%%  EV CHARGE/DISCHARGE LOGIC


Pch = EV_Pmax;
Pdis = EV_Pmax;

for k = 1:nT
    row = zeros(1,nVars);
    row(pEV(k))   = 1;
    row(y_ch(k))  = -Pch;
    row(y_dis(k)) =  Pdis;
    Aeq = [Aeq; row];
    beq = [beq; 0];
end

% prevent simultaneous charge & discharge
for k = 1:nT
    row = zeros(1,nVars);
    row(y_ch(k))  = 1;
    row(y_dis(k)) = 1;
    Aineq(k,:) = row;
end
bineq = ones(nT,1);

%% SOC DYNAMICS

for k = 1:nT-1
    row = zeros(1,nVars);
    row(socEV(k+1)) = 1;
    row(socEV(k))   = -1;
    row(pEV(k))     = eta*dt;
    Aeq = [Aeq; row];
    beq = [beq; 0];
end

%% DISHWASHER CONSTRAINTS

% 1) exactly one start
row = zeros(1,nVars);
row(zs) = 1;
Aeq = [Aeq; row];
beq = [beq; 1];

% 2) exactly H_steps active
row = zeros(1,nVars);
row(Zpls) = 1;
Aeq = [Aeq; row];
beq = [beq; H_steps];

% 3) linking: if start -> next H steps active
for k = 1:nT
    for i = 0:H_steps-1
        t = k+i;
        if t>nT, break; end
        row = zeros(1,nVars);
        row(Zpls(t)) = -1;
        row(zs(k))   =  1;
        Aineq = [Aineq; row];
        bineq = [bineq; 0];
    end
end

% 4) start window restriction
allowed_idx = round(allowed_hours/dt)+1;
start_min = min(allowed_idx);
start_max = max(allowed_idx)-H_steps+1;

excluded = (1:nT < start_min) | (1:nT > start_max);
ub(zs(excluded)) = 0;

%%  SOC REQUIREMENT AT 18:00


dep_idx = find(time<=18,1,'last');
row = zeros(1,nVars);
row(socEV(dep_idx)) = -1;
Aineq = [Aineq; row];
bineq = [bineq; -SOC_req];

%%  SOLVE MILP


[x_opt,fval] = intlinprog(f,intcon,Aineq,bineq,Aeq,beq,lb,ub);

%% EXTRACT RESULTS


X = reshape(x_opt,nBlockX,[]);

Ppl   = X(1,:);
Ppg   = X(2,:);
Pg    = X(3,:);
Pgl   = X(4,:);
PEV   = X(5,:);
ZPls  = X(6,:);
Zs    = X(7,:);
SOCev = X(8,:);


Pls = ZPls * Pfixed;
total_cost = fval;
fprintf("Sum Zs = %d\n", round(sum(Zs)));
fprintf("Sum ZPls = %d (expected %d)\n", round(sum(ZPls)), H_steps);

PEV_ch  = max(PEV, 0);   % charging power (load)
PEV_dis = max(-PEV, 0);  % discharging power (generation)

Ptotal_physical = Pli(:) + Pls(:) + PEV_ch(:);   % what the house is consuming
Ptotal_net      = Pli(:) + Pls(:) + PEV(:);   % what you have now (load - EV discharge)

Pg_plot = Ptotal_physical - Pp(:); 
Pgl_plot = max(Pg_plot, 0); % import 
Ppg_plot = max(-Pg_plot, 0); 
Ppl_plot = min(Pp(:), Ptotal_physical);
Ptotal = Ptotal_physical;


%% PLOT SCENARIO 3/


Ptotal = Ptotal_physical;

figure; hold on; grid on;
plot(time,Ptotal,'k','LineWidth',2);
plot(time, Ppl_plot, 'g', 'LineWidth', 1.5);
plot(time,Pls,'m','LineWidth',1.5);
plot(time,PEV,'c','LineWidth',1.5);
plot(time,Pgl_plot,'r','LineWidth',1.5);
plot(time,-Ppg_plot,'b','LineWidth',1.5);


xlabel('Time [h]');
ylabel('Power [kW]');
legend('Total Load','Dishwasher','EV','Grid Import','Grid Export','Ppl');
title('Microgrid Optimization');
xlim([0 24]);

% Metrics calculation

Import_energy = sum(Pgl * dt);
Export_energy = sum(Ppg * dt);
PV_to_load    = sum(Ppl * dt);
peak_load     = max(Ptotal);

results.total_cost    = total_cost;
results.import_energy = Import_energy;
results.export_energy = Export_energy;
results.pv_self       = PV_to_load;
results.peak_load     = peak_load;
results.PEV = PEV(:);
results.SOC = SOCev(:);
results.Ptotal = Ptotal(:);
results.Pgl    = Pgl(:);
results.Ppg    = Ppg(:);
results.Ppl    = Ppl(:);
results.time    = time(:);

end