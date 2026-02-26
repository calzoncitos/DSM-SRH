function [Aeq, beq, nVars] = MGdMatrices_vec(P_PV, P_L)
    T = length(P_PV);
    % Variables in scenario: [PV→L, PV→G, G→L]
    
     Aeq_period = [ 1  1  0;   % PV→L + PV→G = PV
                    0  1 -1;   % PV→G - G→L = PV - Load
                   -1  0 -1 ]; %-PV→L - G→L = -Load
    nVars = size(Aeq_period, 2);
    Aeq = kron(eye(T), Aeq_period);
    beq = reshape([P_PV, P_PV - P_L, -P_L].', [], 1);
end