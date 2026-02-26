function [T_abs, T_imp] = compareBaselines(Pl, Pp, C_in, C_ex, ...
                                           Eld, Els, Pfixed, allowed_hours, ...
                                           Pld, Pls, Ptotal_opt, ...
                                           Ppl, Pgl, Ppg)
%COMPAREBASELINES Build baseline scenarios and compare with optimized solution
%
% Inputs:
%   Pl            - inflexible load profile (nT×1)
%   Pp            - PV profile (nT×1)
%   C_in, C_ex    - import/export tariffs (nT×1)
%   Eld           - total dispatchable energy (kWh)
%   Els           - total schedulable energy (kWh)
%   Pfixed        - fixed schedulable load (kW)
%   allowed_hours - vector of allowed start hours for Pls
%   Pld_opt, Pls_opt, Ptotal_opt, Ppl_opt, Pgl_opt, Ppg_opt - optimized results
%
% Outputs:
%   T_abs - absolute metrics table
%   T_imp - improvement table (Optimized vs PVfirst baseline)

nT = length(Pl);
Pld_max = Eld/2;

% Baseline A: PV oriented scenario - PV-first + earliest Pls
startA = min(allowed_hours);
Pls_B1 = zeros(nT,1); Pls_B1(startA:startA+Els/Pfixed-1)=Pfixed;
Pld_B1 = zeros(nT,1);
[Ppl_B1, Pgl_B1, Ppg_B1, Ptotal_B1] = route_pv_first(Pl, Pld_B1, Pls_B1, Pp);

% Baseline B: cheapest-hours Pld + greedy PV Pls
startB = greedy_pls_start(Pp, Pfixed, Els, allowed_hours);
Pls_B2 = zeros(nT,1); Pls_B2(startB:startB+Els/Pfixed-1)=Pfixed;
Pld_B2 = cheapest_hours_pld(Eld, Pld_max, C_in);
[Ppl_B2, Pgl_B2, Ppg_B2, Ptotal_B2] = route_pv_first(Pl, Pld_B2, Pls_B2, Pp);

% Baseline C: uniform Pld + earliest Pls
Pld_B3 = Eld / nT * ones(nT,1);
startC = min(allowed_hours);
Pls_B3 = zeros(nT,1); Pls_B3(startC:startC+Els/Pfixed-1)=Pfixed;
[Ppl_B3, Pgl_B3, Ppg_B3, Ptotal_B3] = route_pv_first(Pl, Pld_B3, Pls_B3, Pp);

%% Compute metrics
m1 = compute_metrics(Ppl_B1,Pgl_B1,Ppg_B1,Ptotal_B1,C_in,C_ex);
m2 = compute_metrics(Ppl_B2,Pgl_B2,Ppg_B2,Ptotal_B2,C_in,C_ex);
m3 = compute_metrics(Ppl_B3,Pgl_B3,Ppg_B3,Ptotal_B3,C_in,C_ex);
mOpt = compute_metrics(Ppl,Pgl,Ppg,Ptotal_opt,C_in,C_ex);

% Absolute metrics table
T_abs = table( ...
    [m1.Cost; m2.Cost; m3.Cost; mOpt.Cost], ...
    [m1.Import; m2.Import; m3.Import; mOpt.Import], ...
    [m1.Export; m2.Export; m3.Export; mOpt.Export], ...
    [m1.PV_to_load; m2.PV_to_load; m3.PV_to_load; mOpt.PV_to_load], ...
    [m1.Peak; m2.Peak; m3.Peak; mOpt.Peak], ...
    'VariableNames', {'Cost','Import','Export','PVtoLoad','Peak'}, ...
    'RowNames', {'PV Oriented','Price Oriented','Uniform','Optimized'});

% Improvement table (Optimized vs PVfirst baseline)
relImp = @(b,o) 100*(b-o)/b;
T_imp = table( ...
    relImp(m1.Cost, mOpt.Cost), ...
    relImp(m1.Import, mOpt.Import), ...
    relImp(mOpt.Export, m1.Export), ...
    relImp(mOpt.PV_to_load, m1.PV_to_load), ...
    relImp(m1.Peak, mOpt.Peak), ...
    'VariableNames', {'CostImp','ImportImp','ExportImp','PVtoLoadImp','PeakImp'});

end

%% Helper functions

function start = greedy_pls_start(Pp, Pfixed, Els, allowed_hours)
H = Els / Pfixed;
best = -inf; start = min(allowed_hours);
for s = min(allowed_hours):(max(allowed_hours)-H+1)
    if all(ismember(s:(s+H-1), allowed_hours))
        val = sum(Pp(s:s+H-1));
        if val > best
            best = val; start = s;
        end
    end
end
end

function Pld_base = cheapest_hours_pld(Eld, Pld_max, C_in)
nT = length(C_in);
Pld_base = zeros(nT,1);
[~, idx] = sort(C_in);
remaining = Eld;
for k = 1:nT
    i = idx(k);
    take = min(Pld_max, remaining);
    Pld_base(i) = take;
    remaining = remaining - take;
    if remaining <= 1e-9, break; end
end
end

function [Ppl, Pgl, Ppg, Ptotal] = route_pv_first(Pl, Pld, Pls, Pp)
Ptotal = Pl + Pld + Pls;
Ppl = min(Pp, Ptotal);
residual = Ptotal - Ppl;
Pgl = max(0, residual);
Ppg = max(0, Pp - Ppl);
end

function metrics = compute_metrics(Ppl,Pgl,Ppg,Ptotal,C_in,C_ex)
metrics.Cost = sum(C_in(:).*Pgl(:) - C_ex(:).*Ppg(:));
metrics.Import = sum(Pgl);
metrics.Export = sum(Ppg);
metrics.PV_to_load = sum(Ppl);
metrics.Peak = max(Ptotal);
metrics.Ramp = sum(abs(diff(Ptotal)));
end
