function [Aeq, beq, nBlockX] = MGdMatrices_Zpls(Pp, Pli, Pfixed)

nT = length(Pp);


% X =       [ Ppl, Ppg, Pg,  Pgl, Pld, Zpls,    Zs ]
Aeq_block = [ 1     1    0    0    0    0       0   ;  % Ppl + Ppg = Pp
              0     1    1   -1    0    0       0   ;  % Ppg - Pgl + Pg = 0 
              1     0    0    1   -1   -Pfixed  0  ];  % Ppl + Pgl - Pld - Zpls * P fixed = Pli
nBlockX = size(Aeq_block, 2);
beq_block = [ Pp, zeros(nT,1), Pli];

Aeq = kron(eye(nT), Aeq_block);
beq = reshape(beq_block.', [], 1);

end