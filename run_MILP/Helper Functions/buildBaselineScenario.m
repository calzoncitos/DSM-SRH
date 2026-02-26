function [Pld_base, Pls_base, Pli_base,start_base, Ppl_base, Ppg_base, Pgl_base, Pg_base, total_cost_base, Ptotal_base] = ...
    buildBaselineScenario(strategy, ...
                          Pli, dispatchLoad, dispatchEld, ...
                          Els, Pfixed, allowed_hours, ...
                          nT, Pp, C_in, C_ex)
% Inputs:
%   policy                  - 'earliest', 'midday', or 'stochastic' for random selection
%   Pli                     - base inflexible load profile (nT×1)
%   Eld dispatch load       - total dispatchable energy (kWh)
%   Els                     - total schedulable energy (kWh)
%   Pfixed                  - fixed hourly schedulable load (kW)
%   allowed_hours           - vector of allowed start hours
%   nT                      - number of time steps
%   Pp                      - PV profile (nT×1)
%   C_in, C_ex              - import/export tariffs (nT×1)

% Outputs:
%   Pld_base, Pls_base, Pli_base - baseline load profiles
%   start_base                   - chosen start hour for Pls
%   Ppl_base, Ppg_base, Pgl_base - baseline energy flows
%   Pg_base                      - baseline grid generation
%   total_cost_base              - baseline total cost

%% Base Load 
Pli_base = Pli(:);

%% --- Dispatchable Load ---
Pld_base = zeros(nT,1);
allowed_d = dispatchLoad.allowed_hours;
duration_ld = dispatchEld / dispatchLoad.Pmax;

switch strategy
    case 'earliest'
        start_ld = allowed_d(1);
        
    case 'midday'
        start_ld = round(mean(allowed_d)) - floor(duration_ld/2);
        start_ld = max(start_ld, allowed_d(1));
        
    case 'random'
        max_start = allowed_d(end) - duration_ld + 1;
        start_ld = randi([allowed_d(1), max_start]);
end

Pld_base(start_ld:start_ld+duration_ld-1) = dispatchLoad.Pmax;

%% --- Schedulable Load ---
Pls_base = zeros(nT,1);
timePls = Els / Pfixed;

switch strategy
    case 'earliest'
        start_pls = allowed_hours(1);
        
    case 'midday'
        start_pls = round(mean(allowed_hours)) - floor(timePls/2);
        start_pls = max(start_pls, allowed_hours(1));
        
    case 'random'
        max_start = allowed_hours(end) - timePls + 1;
        start_pls = randi([allowed_hours(1), max_start]);
end
start_base = start_pls;
Pls_base(start_pls:start_pls+timePls-1) = Pfixed;

%% --- Total Load ---
Ptotal_base = Pli_base + Pld_base + Pls_base;

%% --- Power Flow ---
Ppl_base = zeros(nT,1);
Ppg_base = zeros(nT,1);
Pgl_base = zeros(nT,1);
Pg_base  = zeros(nT,1);

for t = 1:nT
    if Pp(t) >= Ptotal_base(t)
        Ppl_base(t) = Ptotal_base(t);
        Ppg_base(t) = Pp(t) - Ptotal_base(t);
    else
        Ppl_base(t) = Pp(t);
        Pgl_base(t) = Ptotal_base(t) - Pp(t);
    end
        Pg_base(t) = Pgl_base(t) - Ppg_base(t);
end


%% Total baseline Cost
cost_import = C_in(:).*Pgl_base;
cost_export = -C_ex(:).*Ppg_base;

total_cost_base = sum(cost_import + cost_export);

end


