function cost_matrix = objectivefunction(nT,C_ex,C_in)
cost_matrix = [ zeros(nT,1), -C_ex, zeros(nT,1), C_in, zeros(nT,1), zeros(nT,1), zeros(nT,1)];
end