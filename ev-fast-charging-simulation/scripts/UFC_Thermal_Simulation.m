%% Ultra-Fast EV Charging Thermal Management Simulation
% EE584 Power Electronics - Progress Report 3
% Lorans Hirmez - Fall 2025
% Objective 1: Thermal Management Analysis

clear all; close all; clc;

%% ========================================================================
%  BATTERY PACK PARAMETERS
%  ========================================================================
battery.capacity_kWh = 100;              % Battery pack capacity [kWh]
battery.capacity_Ah = 250;               % Nominal capacity [Ah]
battery.nominal_voltage = 400;           % Nominal voltage [V]
battery.V_min = 350;                     % Minimum voltage [V]
battery.V_max = 450;                     % Maximum voltage [V]
battery.num_series = 96;                 % Number of cells in series
battery.num_parallel = 72;               % Number of cells in parallel
battery.mass = 500;                      % Battery pack mass [kg]
battery.Cp = 1000;                       % Specific heat capacity [J/(kg·K)]
battery.surface_area = 3;                % Effective surface area [m²]

% Internal resistance (temperature dependent)
battery.R0_base = 0.05;                  % Base internal resistance at 25°C [Ohm]
battery.R0_temp_coeff = 0.005;           % Temperature coefficient [Ohm/°C]

% RC network parameters for dynamic response
battery.R1 = 0.01;                       % Fast RC resistance [Ohm]
battery.C1 = 1000;                       % Fast RC capacitance [F]
battery.R2 = 0.015;                      % Slow RC resistance [Ohm]
battery.C2 = 5000;                       % Slow RC capacitance [F]

% Entropic heat coefficient
battery.dOCV_dT = -0.0003;               % Entropic coefficient [V/K]

%% ========================================================================
%  CHARGING PARAMETERS
%  ========================================================================
charging.I_charge = 400;                 % Charging current [A]
charging.power_kW = 350;                 % Target charging power [kW]
charging.SOC_initial = 0.20;             % Initial state of charge [0-1]
charging.SOC_target = 0.80;              % Target state of charge [0-1]

%% ========================================================================
%  ENVIRONMENTAL & SAFETY PARAMETERS
%  ========================================================================
env.T_ambient = 25;                      % Ambient temperature [°C]
env.T_max_safe = 45;                     % Maximum safe temperature [°C]

%% ========================================================================
%  SIMULATION PARAMETERS
%  ========================================================================
sim.dt = 1;                              % Time step [seconds]
sim.t_max = 3600;                        % Maximum simulation time [seconds]

%% ========================================================================
%  COOLING SYSTEM DEFINITIONS
%  ========================================================================

% Case 1: No Active Cooling (Natural Convection)
cooling(1).name = 'No Active Cooling';
cooling(1).type = 'natural';
cooling(1).h = 10;                       % Heat transfer coefficient [W/(m²·K)]
cooling(1).T_coolant = env.T_ambient;    % No separate coolant temp
cooling(1).power_consumption = 0;        % No power consumption [W]
cooling(1).cost_capex = 0;               % No additional cost

% Case 2: Liquid Cooling (Glycol-Water)
cooling(2).name = 'Liquid Cooling';
cooling(2).type = 'liquid';
cooling(2).h = 500;                      % Heat transfer coefficient [W/(m²·K)]
cooling(2).T_coolant = 20;               % Coolant inlet temperature [°C]
cooling(2).flow_rate = 5/60;             % Flow rate [L/s] (5 L/min)
cooling(2).fluid_Cp = 3500;              % Glycol-water specific heat [J/(kg·K)]
cooling(2).fluid_density = 1050;         % Fluid density [kg/m³]
cooling(2).pump_power = 200;             % Pump power [W]
cooling(2).cost_capex = 5000;            % Capital cost estimate [$]

% Case 3: Refrigerant Direct Cooling (R-134a)
cooling(3).name = 'Refrigerant Cooling';
cooling(3).type = 'refrigerant';
cooling(3).h = 1200;                     % Heat transfer coefficient [W/(m²·K)]
cooling(3).T_evaporator = 10;            % Evaporator temperature [°C]
cooling(3).COP = 3.0;                    % Coefficient of performance
cooling(3).cost_capex = 12000;           % Capital cost estimate [$]

% Case 4: Phase Change Material (PCM)
cooling(4).name = 'PCM Cooling';
cooling(4).type = 'pcm';
cooling(4).h = 300;                      % Effective heat transfer coefficient [W/(m²·K)]
cooling(4).T_melt = 42;                  % PCM melting point [°C]
cooling(4).latent_heat = 200000;         % Latent heat of fusion [J/kg]
cooling(4).pcm_mass = 50;                % PCM mass [kg]
cooling(4).pcm_melted = 0;               % Initial melted fraction [0-1]
cooling(4).cost_capex = 8000;            % Capital cost estimate [$]

%% ========================================================================
%  MAIN SIMULATION LOOP - RUN ALL COOLING CASES
%  ========================================================================

results = struct();

for case_idx = 1:length(cooling)
    
    fprintf('\n=================================================\n');
    fprintf('Running Case %d: %s\n', case_idx, cooling(case_idx).name);
    fprintf('=================================================\n');
    
    % Initialize state variables
    SOC = charging.SOC_initial;
    T_cell = env.T_ambient;              % Initial cell temperature [°C]
    V1 = 0;                              % Initial voltage across RC1
    V2 = 0;                              % Initial voltage across RC2
    
    % Storage arrays
    t_vec = 0:sim.dt:sim.t_max;
    T_vec = zeros(size(t_vec));
    SOC_vec = zeros(size(t_vec));
    V_vec = zeros(size(t_vec));
    Q_gen_vec = zeros(size(t_vec));
    Q_cool_vec = zeros(size(t_vec));
    P_cool_vec = zeros(size(t_vec));
    
    % PCM state tracking
    if strcmp(cooling(case_idx).type, 'pcm')
        pcm_melted = cooling(case_idx).pcm_melted;
    end
    
    % Simulation loop
    charging_complete = false;
    idx = 1;
    
    for t = t_vec
        
        % Update OCV based on SOC (simplified linear model)
        OCV = battery.V_min + SOC * (battery.V_max - battery.V_min);
        
        % Temperature-dependent internal resistance
        R0 = battery.R0_base * (1 + battery.R0_temp_coeff * (T_cell - 25));
        
        % Calculate terminal voltage
        V_terminal = OCV - charging.I_charge * R0 - V1 - V2;
        
        % Calculate heat generation
        % Joule heating
        Q_joule = charging.I_charge^2 * R0;
        
        % Entropic heating
        Q_entropic = charging.I_charge * (T_cell + 273.15) * battery.dOCV_dT;
        
        % Total heat generation [W]
        Q_gen = Q_joule + Q_entropic;
        
        % Calculate cooling heat removal based on strategy
        switch cooling(case_idx).type
            case 'natural'
                % Natural convection
                Q_cool = cooling(case_idx).h * battery.surface_area * ...
                         (T_cell - env.T_ambient);
                P_cooling = 0;
                
            case 'liquid'
                % Forced liquid cooling
                Q_cool = cooling(case_idx).h * battery.surface_area * ...
                         (T_cell - cooling(case_idx).T_coolant);
                % Account for coolant temperature rise
                T_coolant_out = cooling(case_idx).T_coolant + ...
                    Q_cool / (cooling(case_idx).flow_rate * ...
                    cooling(case_idx).fluid_density * cooling(case_idx).fluid_Cp);
                P_cooling = cooling(case_idx).pump_power;
                
            case 'refrigerant'
                % Refrigerant cooling with COP
                Q_cool = cooling(case_idx).h * battery.surface_area * ...
                         (T_cell - cooling(case_idx).T_evaporator);
                % Compressor power = cooling power / COP
                P_cooling = Q_cool / cooling(case_idx).COP;
                
            case 'pcm'
                % Phase change material cooling
                if T_cell < cooling(case_idx).T_melt
                    % Below melting point - sensible heat
                    Q_cool = cooling(case_idx).h * battery.surface_area * ...
                             (T_cell - env.T_ambient);
                elseif pcm_melted < 1.0
                    % During phase change - latent heat absorption
                    Q_cool_potential = cooling(case_idx).h * battery.surface_area * ...
                                       (T_cell - cooling(case_idx).T_melt);
                    % Limit by remaining latent heat capacity
                    Q_latent_available = cooling(case_idx).latent_heat * ...
                                        cooling(case_idx).pcm_mass * (1 - pcm_melted);
                    Q_cool = min(Q_cool_potential, Q_latent_available / sim.dt);
                    % Update PCM melted fraction
                    pcm_melted = pcm_melted + (Q_cool * sim.dt) / ...
                                (cooling(case_idx).latent_heat * cooling(case_idx).pcm_mass);
                else
                    % PCM fully melted - reduced effectiveness
                    Q_cool = cooling(case_idx).h * battery.surface_area * ...
                             (T_cell - env.T_ambient) * 0.3;
                end
                P_cooling = 0;  % Passive system
        end
        
        % Thermal energy balance - update temperature
        dT_dt = (Q_gen - Q_cool) / (battery.mass * battery.Cp);
        T_cell = T_cell + dT_dt * sim.dt;
        
        % Update RC network voltages (exponential decay)
        tau1 = battery.R1 * battery.C1;
        tau2 = battery.R2 * battery.C2;
        V1 = V1 * exp(-sim.dt/tau1) + charging.I_charge * battery.R1 * (1 - exp(-sim.dt/tau1));
        V2 = V2 * exp(-sim.dt/tau2) + charging.I_charge * battery.R2 * (1 - exp(-sim.dt/tau2));
        
        % Update SOC
        dSOC = (charging.I_charge * sim.dt) / (battery.capacity_Ah * 3600);
        SOC = SOC + dSOC;
        
        % Store results
        T_vec(idx) = T_cell;
        SOC_vec(idx) = SOC;
        V_vec(idx) = V_terminal;
        Q_gen_vec(idx) = Q_gen;
        Q_cool_vec(idx) = Q_cool;
        P_cool_vec(idx) = P_cooling;
        
        % Check termination conditions
        if SOC >= charging.SOC_target
            fprintf('Target SOC reached at t = %.1f seconds\n', t);
            charging_complete = true;
            break;
        end
        
        if T_cell >= env.T_max_safe
            fprintf('WARNING: Maximum safe temperature exceeded at t = %.1f seconds\n', t);
            break;
        end
        
        if V_terminal >= battery.V_max
            fprintf('Maximum voltage reached at t = %.1f seconds\n', t);
            break;
        end
        
        idx = idx + 1;
    end
    
    % Trim unused array elements
    t_vec = t_vec(1:idx-1);
    T_vec = T_vec(1:idx-1);
    SOC_vec = SOC_vec(1:idx-1);
    V_vec = V_vec(1:idx-1);
    Q_gen_vec = Q_gen_vec(1:idx-1);
    Q_cool_vec = Q_cool_vec(1:idx-1);
    P_cool_vec = P_cool_vec(1:idx-1);
    
    % Store results for this case
    results(case_idx).name = cooling(case_idx).name;
    results(case_idx).time = t_vec;
    results(case_idx).temperature = T_vec;
    results(case_idx).SOC = SOC_vec;
    results(case_idx).voltage = V_vec;
    results(case_idx).Q_gen = Q_gen_vec;
    results(case_idx).Q_cool = Q_cool_vec;
    results(case_idx).P_cool = P_cool_vec;
    results(case_idx).charging_complete = charging_complete;
    
    % Calculate performance metrics (store as scalars)
    results(case_idx).metrics.peak_temp = max(T_vec);
    results(case_idx).metrics.final_temp = T_vec(end);
    results(case_idx).metrics.charging_time = t_vec(end);
    results(case_idx).metrics.energy_delivered = trapz(t_vec, charging.I_charge .* V_vec) / 3600; % Wh
    results(case_idx).metrics.cooling_energy = trapz(t_vec, P_cool_vec) / 3600; % Wh
    results(case_idx).metrics.total_heat_gen = trapz(t_vec, Q_gen_vec) / 1000; % kJ
    results(case_idx).metrics.total_heat_removed = trapz(t_vec, Q_cool_vec) / 1000; % kJ
    
    fprintf('Peak Temperature: %.2f °C\n', results(case_idx).metrics.peak_temp);
    fprintf('Charging Time: %.1f seconds (%.2f minutes)\n', ...
            results(case_idx).metrics.charging_time, ...
            results(case_idx).metrics.charging_time/60);
    fprintf('Energy Delivered: %.2f kWh\n', results(case_idx).metrics.energy_delivered/1000);
    fprintf('Cooling Energy: %.2f kWh\n', results(case_idx).metrics.cooling_energy/1000);
    
end

%% ========================================================================
%  RESULTS VISUALIZATION
%  ========================================================================

colors = lines(length(results));

% FIGURE 1: Time-Series Plots (3 subplots)
figure('Position', [50, 100, 1500, 500]);

% Subplot 1: Temperature vs Time
subplot(1,3,1)
hold on; grid on;
for i = 1:length(results)
    plot(results(i).time/60, results(i).temperature, 'LineWidth', 2.5, ...
         'Color', colors(i,:), 'DisplayName', results(i).name);
end
plot([0 max(results(1).time)/60], [env.T_max_safe env.T_max_safe], ...
     'r--', 'LineWidth', 2, 'DisplayName', 'Safety Limit');
xlabel('Time (minutes)', 'FontSize', 12);
ylabel('Cell Temperature (°C)', 'FontSize', 12);
title('Temperature Profile During Charging', 'FontSize', 13, 'FontWeight', 'bold');
legend('Location', 'best', 'FontSize', 10);
set(gca, 'FontSize', 11);
ylim([10 50]);

% Subplot 2: SOC vs Time
subplot(1,3,2)
hold on; grid on;
for i = 1:length(results)
    plot(results(i).time/60, results(i).SOC*100, 'LineWidth', 2.5, ...
         'Color', colors(i,:), 'DisplayName', results(i).name);
end
xlabel('Time (minutes)', 'FontSize', 12);
ylabel('State of Charge (%)', 'FontSize', 12);
title('SOC Profile During Charging', 'FontSize', 13, 'FontWeight', 'bold');
legend('Location', 'best', 'FontSize', 10);
set(gca, 'FontSize', 11);

% Subplot 3: Heat Generation vs Cooling
subplot(1,3,3)
hold on; grid on;
for i = 1:length(results)
    plot(results(i).time/60, results(i).Q_gen/1000, 'LineWidth', 2.5, ...
         'Color', colors(i,:), 'DisplayName', [results(i).name ' (Gen)']);
    plot(results(i).time/60, results(i).Q_cool/1000, '--', 'LineWidth', 2, ...
         'Color', colors(i,:), 'DisplayName', [results(i).name ' (Cool)']);
end
xlabel('Time (minutes)', 'FontSize', 12);
ylabel('Heat Power (kW)', 'FontSize', 12);
title('Heat Generation vs Cooling Power', 'FontSize', 13, 'FontWeight', 'bold');
legend('Location', 'best', 'FontSize', 8);
set(gca, 'FontSize', 11);

sgtitle('Ultra-Fast Charging: Time-Series Analysis', 'FontSize', 15, 'FontWeight', 'bold');

% FIGURE 2: Performance Comparison Bar Charts (3 subplots)
figure('Position', [50, 50, 1500, 500]);

metric_names = {results.name};

% Subplot 1: Peak Temperature
subplot(1,3,1)
peak_temps = zeros(1, length(results));
for i = 1:length(results)
    peak_temps(i) = results(i).metrics.peak_temp;
end
b = bar(peak_temps, 'FaceColor', 'flat');
for i = 1:length(results)
    b.CData(i,:) = colors(i,:);
end
set(gca, 'XTickLabel', metric_names, 'XTickLabelRotation', 45);
ylabel('Peak Temperature (°C)', 'FontSize', 12);
title('Peak Temperature Comparison', 'FontSize', 13, 'FontWeight', 'bold');
grid on;
hold on;
plot([0 length(results)+1], [env.T_max_safe env.T_max_safe], 'r--', 'LineWidth', 2.5);
text(length(results)/2, env.T_max_safe+1, 'Safety Limit', 'Color', 'r', ...
     'FontSize', 10, 'HorizontalAlignment', 'center');
set(gca, 'FontSize', 11);
ylim([0 max(peak_temps)*1.15]);

% Subplot 2: Charging Time
subplot(1,3,2)
charging_times = zeros(1, length(results));
for i = 1:length(results)
    charging_times(i) = results(i).metrics.charging_time/60;
end
b = bar(charging_times, 'FaceColor', 'flat');
for i = 1:length(results)
    b.CData(i,:) = colors(i,:);
end
set(gca, 'XTickLabel', metric_names, 'XTickLabelRotation', 45);
ylabel('Charging Time (minutes)', 'FontSize', 12);
title('Charging Time Comparison', 'FontSize', 13, 'FontWeight', 'bold');
grid on;
set(gca, 'FontSize', 11);
% Add values on top of bars
for i = 1:length(charging_times)
    text(i, charging_times(i)+0.5, sprintf('%.1f min', charging_times(i)), ...
         'HorizontalAlignment', 'center', 'FontSize', 10);
end

% Subplot 3: Cooling Energy
subplot(1,3,3)
cooling_energy = zeros(1, length(results));
for i = 1:length(results)
    cooling_energy(i) = results(i).metrics.cooling_energy/1000; % kWh
end
b = bar(cooling_energy, 'FaceColor', 'flat');
for i = 1:length(results)
    b.CData(i,:) = colors(i,:);
end
set(gca, 'XTickLabel', metric_names, 'XTickLabelRotation', 45);
ylabel('Cooling Energy (kWh)', 'FontSize', 12);
title('Cooling System Energy Consumption', 'FontSize', 13, 'FontWeight', 'bold');
grid on;
set(gca, 'FontSize', 11);
% Add values on top of bars
for i = 1:length(cooling_energy)
    if cooling_energy(i) > 0
        text(i, cooling_energy(i)+0.05, sprintf('%.2f kWh', cooling_energy(i)), ...
             'HorizontalAlignment', 'center', 'FontSize', 10);
    end
end

sgtitle('Ultra-Fast Charging: Performance Metrics Comparison', 'FontSize', 15, 'FontWeight', 'bold');

%% ========================================================================
%  SUMMARY TABLE
%  ========================================================================

fprintf('\n\n=================================================\n');
fprintf('PERFORMANCE METRICS SUMMARY\n');
fprintf('=================================================\n\n');

% Create summary table
summary_table = table();
cooling_names = cell(length(results), 1);
peak_temps_table = zeros(length(results), 1);
charging_times_table = zeros(length(results), 1);
energy_delivered_table = zeros(length(results), 1);
cooling_energy_table = zeros(length(results), 1);
heat_gen_table = zeros(length(results), 1);
charging_complete_table = cell(length(results), 1);

for i = 1:length(results)
    cooling_names{i} = results(i).name;
    peak_temps_table(i) = results(i).metrics.peak_temp;
    charging_times_table(i) = results(i).metrics.charging_time/60;
    energy_delivered_table(i) = results(i).metrics.energy_delivered/1000;
    cooling_energy_table(i) = results(i).metrics.cooling_energy/1000;
    heat_gen_table(i) = results(i).metrics.total_heat_gen;
    if results(i).charging_complete
        charging_complete_table{i} = 'Yes';
    else
        charging_complete_table{i} = 'No';
    end
end

summary_table.CoolingStrategy = cooling_names;
summary_table.PeakTemp_C = peak_temps_table;
summary_table.ChargingTime_min = charging_times_table;
summary_table.EnergyDelivered_kWh = energy_delivered_table;
summary_table.CoolingEnergy_kWh = cooling_energy_table;
summary_table.TotalHeatGen_kJ = heat_gen_table;
summary_table.ChargingComplete = charging_complete_table;

disp(summary_table);

%% ========================================================================
%  EXPORT RESULTS
%  ========================================================================

% Save results to MAT file
save('UFC_Thermal_Results.mat', 'results', 'battery', 'charging', 'cooling', 'env');

% Export summary table to CSV
writetable(summary_table, 'UFC_Thermal_Summary.csv');

fprintf('\n=================================================\n');
fprintf('Simulation Complete!\n');
fprintf('Results saved to UFC_Thermal_Results.mat\n');
fprintf('Summary saved to UFC_Thermal_Summary.csv\n');
fprintf('=================================================\n');