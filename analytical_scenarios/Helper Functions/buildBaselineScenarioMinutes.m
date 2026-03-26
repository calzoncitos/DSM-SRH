function [Pld_base, Pls_base, Pli_base, start_base, ...
          Ppl_base, Ppg_base, Pgl_base, Pg_base, total_cost_base, Ptotal_base] = ...
          buildBaselineScenarioMinutes(Pli, Eld, Els, Pfixed, allowed_hours, nT, Pp, C_in, C_ex, policy, dt)

% Inputs:
%   Pl            - base inflexible load profile (nT×1)
%   Eld           - total dispatchable energy (kWh)
%   Els           - total schedulable energy (kWh)
%   Pfixed        - fixed hourly schedulable load (kW)
%   allowed_hours - vector of allowed start hours
%   nT            - number of time steps
%   Pp            - PV profile (nT×1)
%   C_in, C_ex    - import/export tariffs (nT×1)
%   policy        - 'earliest', 'midpoint', 'latest 'or 'stochastic'
%
% Outputs:
%   Pld_base, Pls_base, Pli_base - baseline load profiles
%   start_base                   - chosen start hour for Pls
%   Ppl_base, Ppg_base, Pgl_base - baseline energy flows
%   Pg_base                      - baseline grid generation
%   total_cost_base              - baseline total cost

H_steps = round((Els / Pfixed) / dt);   % schedulable block length in steps

% Convert allowed hours into indices
allowed_idx = round(allowed_hours / dt) + 1;

% Choose schedulable start index
switch lower(policy)
    case 'earliest'
        start_idx = min(allowed_idx);
    case 'midpoint'
        mid_hour  = round(mean(allowed_hours));
        start_idx = round(mid_hour/dt) + 1;
    case 'latest'
        start_idx = max(allowed_idx) - H_steps + 1;
    case 'stochastic'
        validStarts = allowed_idx(1):allowed_idx(end)-H_steps+1;
        start_idx   = validStarts(randi(length(validStarts)));
    otherwise
        start_idx = min(allowed_idx);
end
start_base = (start_idx-1)*dt;  

% Schedulable load baseline 
Pls_base = zeros(nT,1);
Pls_base(start_idx:start_idx+H_steps-1) = Pfixed;

% Dispatchable load baseline 
Pld_base = zeros(nT,1);
validStarts = allowed_idx(1):allowed_idx(end)-H_steps+1;
start_idx   = validStarts(randi(length(validStarts)));
Pld_base(start_idx:start_idx+H_steps-1) = Eld/(H_steps*dt);



% Residual inflexible load 
Pli_base = Pli(:);

% Routing baseline flows (PV prioritized to load)
Ptotal_base = Pli_base + Pld_base + Pls_base;
Ppl_base    = min(Pp(:), Ptotal_base);
residual    = Ptotal_base - Ppl_base;
Pgl_base    = residual;
Ppg_base    = max(0, Pp(:) - Ppl_base);
Pg_base     = zeros(nT,1);

% Cost (scaled by dt)
cost_import_base = C_in(:) .* Pgl_base * dt;
cost_export_base = -C_ex(:) .* Ppg_base * dt;
total_cost_base  = sum(cost_import_base + cost_export_base);


end