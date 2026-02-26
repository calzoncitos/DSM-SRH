%% Linear programming framework for microgrid with PV - Grid - Loads

clearvars; clc; close all;

%% Load Parameters
data = readtable('energy_data.csv');
P_PV = data.PV;             % PV generation data
P_L = data.Load;            % Loads data
C_in = data.ImportTariff;   % Cost import tariff strategy
C_ex = data.ExportTariff;   % Cost export tariff strategy
T = height(data);           % Lenght of data to introduce total timesteps scenario

head(data) % show first 8 rows of energy data file


%% equality constraints
[Aeq, beq] = MGdMatrices_vec(P_PV, P_L);
nVars = size(Aeq,2) / T;



%% Objective function: Cost vector: [PV→L,       PV→G,   G→L]
cost_pattern =                      [zeros(T,1), -C_ex, C_in];
cost_pattern = cost_pattern(:,1:nVars);
f = reshape(cost_pattern.', [], 1);

%% Bounds
lb = zeros(nVars*T,1); % lower bound equal to zero on this scenario
ub = [];               % upper bounds not defined so assuming infinite bounds

%% Solve LP
[x_opt, fval] = linprog(f, [], [], Aeq, beq, lb, []);


fprintf('Total Cost:%g\n', fval)
display(x_opt) % values for power flow (PV->LOAD, PV->GRID, GRID->LOAD)

% Reshape and plot
X = reshape(x_opt, nVars, T);

Pv = X(1,:)'; % PV to Load
Pg = X(3,:)'; % PV to Grid
Pl = X(2,:)'; % Grid to Load


%% Plot Visualizations

% Stacked bar plot for energy flows

bar(X','stacked'); xlabel('Hour'); ylabel('Power Flow (kW)');
legend({'PV→Load','PV→Grid','Grid→Load'}); title('Energy Flows');


% Cost contributions
cost_matrix = [zeros(1,T); -C_ex.' .* X(2,:); C_in.' .* X(3,:)];
figure; area(cost_matrix'); xlabel('Hour'); ylabel('Cost (ct)');
legend({'PV→Load (0)','PV→Grid (Revenue)','Grid→Load (Cost)'});
title('Cost Contributions'); grid on;

% Tariff behaviour analysis
t=1:T;
figure;
plot(t, C_in, '-r','LineWidth', 1.8, 'DisplayName','Import Tariff');
hold on;
plot(t, C_ex, '-b','LineWidth', 1.8, 'DisplayName','export Tariff');
ylabel('Tariff (ct/kWh)');
xlabel('Hour');
title('Tariff Behavior');
legend('Location','best');
grid on;