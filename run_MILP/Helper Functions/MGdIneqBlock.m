function [Aineq, bineq] = MGdIneqBlock(nT, timePls, pls, z, nVars)
%MGdIneqBlock Build inequality constraints for schedulable load block

H = timePls;
nStarts = nT; 

% indices for Pls windows ---
winIdx = (0:H-1)' + (1:nStarts);   % H × nStarts
winIdx = min(winIdx, nT);  
winIdx = pls(winIdx);   

% sparse matrix for Pls part ---
rows = repmat(1:nStarts, H, 1);    % row indices
cols = winIdx;                     % column indices
vals = -ones(H, nStarts);          % coefficients (negative for LHS)
A_pls = sparse(rows(:), cols(:), vals(:), nStarts, nVars);

% sparse matrix for Z part ---
A_z = sparse(1:nStarts, z(1:nStarts), H, nStarts, nVars);

Aineq = A_pls + A_z;
bineq = zeros(nStarts,1);

end
