

clc; clear; close all;

r1 = run_baseline();
r2 = run_scenario2();
r3 = run_scenario3();


%  COMPARISON TABLE


Scenario = {'Baseline'; 'EV + DW'; 'EV + V2G + DW'};


TotalCost = [r1.total_cost;
             r2.total_cost;
             r3.total_cost];

ImportEnergy = [r1.import_energy;
                r2.import_energy;
                r3.import_energy];

ExportEnergy = [r1.export_energy;
                r2.export_energy;
                r3.export_energy];

PVself = [r1.pv_self;
          r2.pv_self;
          r3.pv_self];

PeakLoad = [r1.peak_load;
            r2.peak_load;
            r3.peak_load];
time = [r1.time;r2.time;r3.time];

Ptotal = [r1.Ptotal;r2.Ptotal;r3.Ptotal;];

Pgl = [r1.Pgl;r2.Pgl;r3.Pgl;];

CostReduction_percent = (TotalCost(1) - TotalCost) / TotalCost(1) * 100;

T = table(Scenario, TotalCost, ImportEnergy, ExportEnergy,PVself, PeakLoad, CostReduction_percent);

disp(T)

figure;
bar(TotalCost)
set(gca,'XTickLabel',Scenario)
ylabel('Total Cost [ct]')
title('Total Operating Cost Comparison')
grid on



figure; hold on; grid on;

plot(r3.time, r3.SOC,'r','LineWidth',2)

xlabel('Time [h]')
ylabel('State of Charge [kWh]')
title('EV Battery SOC (V2G Scenario)')
xlim([0 24])

