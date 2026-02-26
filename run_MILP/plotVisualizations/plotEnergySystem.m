function plotEnergySystem(t, Pli, Pld, Pls, Ppl, Ppg, Pgl, X, C_in, C_ex)

% plotEnergySystem Generates all visualization plots for energy system optimization
%
% Inputs:
%   t    - time vector (1×nT)
%   Pl   - base load profile (nT×1)
%   Pli  - inflexible load (nT×1)
%   Pld  - dispatchable load (nT×1)
%   Pls  - schedulable load (nT×1)
%   Ppl  - PV→Load flow (nT×1)
%   Ppg  - PV→Grid flow (nT×1)
%   Pgl  - Grid→Load flow (nT×1)
%   X    - decision matrix (rows include Pls binary schedule)
%   C_in - import cost vector (nT×1)
%   C_ex - export tariff vector (nT×1)

%% Energy flows (stacked bar)
figure;
bar([Ppl; Ppg; Pgl; Pld; Pls]','stacked');
xlabel('Hour'); ylabel('kW');
legend({'PV→Load','PV→Grid','Grid→Load','Dispatchable Load','Schedulable Load'}, 'Location','best');
title('Energy Flows'); grid on;

%% Total Load profile
Pli = Pli(:); Pld = Pld(:); Pls = Pls(:);
Ptotal = Pli + Pld + Pls;

figure;
subplot(2,1,1);
plot(t, Ptotal, '-o','LineWidth',2,'Color',[0 0.447 0.741]);
xlabel('Hour'); ylabel('Total Load (kW)');
title('Total Load Profile'); grid on;
on_idx = find(Pld > 0); 
    t_on  = t(min(on_idx));
    t_off = t(max(on_idx));
    ylims = ylim;

    patch([t_on t_off t_off t_on], ...
          [ylims(1) ylims(1) ylims(2) ylims(2)], ...
          [0.9 0.4 0.4], ...        % red shade
          'FaceAlpha',0.2, ...
          'EdgeColor','none', ...
          'DisplayName','dispatchable active period');
    on_idx = find(Pls > 0);   % steps where Pls is active
if ~isempty(on_idx)
    t_on  = t(min(on_idx));
    t_off = t(max(on_idx));
    ylims = ylim;  % current y-axis limits

    patch([t_on t_off t_off t_on], ...
          [ylims(1) ylims(1) ylims(2) ylims(2)], ...
          [0.2 0.8 0.6], ...        % green shade
          'FaceAlpha',0.2, ...      % transparency
          'EdgeColor','none', ...
          'DisplayName','Pls active');
end

xlabel('Time [hours]');
ylabel('kW');
legend; grid on;

subplot(2,1,2); 
plot(t, Ptotal,'--o','LineWidth',1,'Color','k','DisplayName','Total Load'); 
hold on;
plot(t, Pli,'--','LineWidth',1.2,'DisplayName','Inflexible');
stairs(t, Pld,'--m','LineWidth',1.2,'DisplayName','Dispatchable');
stairs(t, Pls,'--c','LineWidth',1.2,'DisplayName','Schedulable');
plot(t, Pli,'-r','LineWidth',1.5,'DisplayName','Base Load');
ylabel('Load (kW)'); legend(); grid on;

%% Schedulable Load ON/OFF schedule
figure;
stairs(t, X(6,:), 'LineWidth', 2);
xlabel('Hour'); ylabel('ON/OFF');
ylim([-0.1 1.1]);
title('Schedulable Load Activation'); grid on;

%% Cost contribution timeline
C_in = C_in(:); C_ex = C_ex(:); Pgl = Pgl(:); Ppg = Ppg(:);

cost_import = C_in .* Pgl; 
cost_export = -C_ex .* Ppg;
net_cost    = cost_import + cost_export;

figure;
subplot(2,1,1); hold on;
h_import = area(t, max(0,cost_import),'FaceColor',[0.85 0.6 0.1],'EdgeColor','none');
h_export = area(t, min(0,cost_export),'FaceColor',[0.05 0.45 0.7],'EdgeColor','none');
plot(t, zeros(size(t)), '--k', 'LineWidth', 1);
h_net = plot(t, net_cost, '-k', 'LineWidth', 2.2, 'DisplayName','Net cost');
plot(t, net_cost, 'sk', 'MarkerFaceColor','w', 'MarkerSize', 4);
xlabel('Hour'); ylabel('Cost (ct)');
title('Hourly Cost and Revenue');
legend([h_import, h_export, h_net], {'Grid→Load Cost','PV→Grid Revenue','Net cost'}, 'Location','best');
grid on; xlim([1 length(t)]); hold off;

subplot(2,1,2); % cumulative cost
cum_net = cumsum(net_cost);
plot(t, cum_net, '-','Color',[0 0 0], 'LineWidth',2);
xlabel('Hour'); ylabel('Cumulative cost (ct)');
title(sprintf('Cumulative Net Cost (Total = %.2f ct)', cum_net(end)));
grid on; xlim([1 length(t)]); yline(0,'--k');

%% Net cost import–export
figure;
plot(t, net_cost, '-o','LineWidth',2,'Color','k');
xlabel('Hour'); ylabel('ct');
title('Net Cost (Import – Export)'); grid on;

end
