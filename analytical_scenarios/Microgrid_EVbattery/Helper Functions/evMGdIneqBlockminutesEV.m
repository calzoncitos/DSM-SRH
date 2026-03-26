function [Aineq, bineq] = evMGdIneqBlockminutesEV(nT, timePls, Zpls, Zs, nVars, dt)
% MGdIneqBlock Build inequality constraints for schedulable load block

H = round(timePls / dt);   % number of timesteps the load must run

Aineq = [];
bineq = [];

for k = 1:nT
    for i = 0:H-1
        t = k + i;
        if t > nT
            break;  
        end

        row = zeros(1, nVars);

  % Zpls(t) - Zs(k) >= 0
        row(Zpls(t)) = 1;
        row(Zs(k))   = -1;

        Aineq = [Aineq; row];
        bineq = [bineq; 0];
    end
end

end

