function compareScenarios(t, Ptotal_base, Ptotal_opt, Pld_base, Pld, Pls_base, Pls, Ppl_base, Ppl, Ppg_base, Ppg, Pgl_base, Pgl)

figure;  
subplot(2,1,1);
plot(t, Ptotal_base,'--','LineWidth',1.2,'DisplayName','Total Base'); hold on;
plot(t, Ptotal_opt, '-','LineWidth',2,'DisplayName','Total Opt');
ylabel('kW'); title('Total Load'); grid on; legend;

subplot(2,1,2);
stairs(t, Pls_base,'--c','LineWidth',1.2,'DisplayName','Pls Base'); hold on;
stairs(t, Pls, '-c','LineWidth',2,'DisplayName','Pls Opt');
stairs(t, Pld_base,'--m','LineWidth',1.2,'DisplayName','Pld Base');
stairs(t, Pld, '-m','LineWidth',2,'DisplayName','Pld Opt');
ylabel('kW'); title('Flexible loads'); grid on; legend;

figure;
subplot(3,1,1); plot(t, Ppl_base,'--','DisplayName','PV→Load Base'); hold on; plot(t, Ppl,'-','DisplayName','PV→Load Opt'); grid on; legend;
subplot(3,1,2); plot(t, Ppg_base,'--','DisplayName','PV→Grid Base'); hold on; plot(t, Ppg,'-','DisplayName','PV→Grid Opt'); grid on; legend;
subplot(3,1,3); plot(t, Pgl_base,'--','DisplayName','Grid→Load Base'); hold on; plot(t, Pgl,'-','DisplayName','Grid→Load Opt'); grid on; legend;

figure;

% --- PV to Load ---
subplot(3,2,1);
bar(t, [Ppl_base, Ppl(:)]);
xlabel('Hour'); ylabel('kW');
title('PV → Load');
legend({'Baseline','Optimized'}); grid on;

% --- PV to Grid ---
subplot(3,2,2);
bar(t, [Ppg_base, Ppg(:)]);
xlabel('Hour'); ylabel('kW');
title('PV → Grid');
legend({'Baseline','Optimized'}); grid on;

% --- Grid to Load ---
subplot(3,2,3);
bar(t, [Pgl_base, Pgl(:)]);
xlabel('Hour'); ylabel('kW');
title('Grid → Load');
legend({'Baseline','Optimized'}); grid on;

% --- Dispatchable Load ---
subplot(3,2,4);
stairs(t, Pld_base,'--m','LineWidth',1.5,'DisplayName','Baseline'); hold on;
stairs(t, Pld,'-m','LineWidth',2,'DisplayName','Optimized');
xlabel('Hour'); ylabel('kW');
title('Dispatchable Load');
legend('Location','best'); grid on;

% --- Schedulable Load ---
subplot(3,2,5);
stairs(t, Pls_base,'--c','LineWidth',1.5,'DisplayName','Baseline'); hold on;
stairs(t, Pls,'-c','LineWidth',2,'DisplayName','Optimized');
xlabel('Hour'); ylabel('kW');
title('Schedulable Load');
legend('Location','best'); grid on;

% total loads flow base vs optim
figure;
subplot(2,1,1);
bar(t,[Ppl_base, Ppg_base, Pgl_base, Pld_base, Pls_base],'stacked');
title('Baseline Energy Flows'); 
xlabel('Time [hours]')
ylabel('kW'); grid on;
legend({'PV→Load','PV→Grid','Grid→Load','Dispatchable','Schedulable'}, 'Location','best');

subplot(2,1,2);
bar(t,[Ppl(:), Ppg(:), Pgl(:), Pld(:), Pls(:)],'stacked');
title('Optimized Energy Flows'); ylabel('kW'); grid on;
legend({'PV→Load','PV→Grid','Grid→Load','Dispatchable','Schedulable'}, 'Location','best');

end