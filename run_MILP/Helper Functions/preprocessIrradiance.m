function P_PV_hourly = preprocessIrradiance(filename,pv_area, pv_effcy)
% Convert irradiance CSV into hourly PV power (kW)

    % Read table
    data = readtable(filename);

    irrStr = string(data.Diffus);
    irrStr = strrep(irrStr," W/m²","");
    irrStr = strrep(irrStr," mW/m²","e-3");
    irrStr = strrep(irrStr," fW/m²","e-15");


    irradiance = str2double(irrStr);
    irradiance(irradiance < 0) = 0;

    P_PV = (irradiance * pv_area * pv_effcy) / 1000;

    P_PV_hourly = reshape(mean(reshape(P_PV,12,[])),[],1);
end