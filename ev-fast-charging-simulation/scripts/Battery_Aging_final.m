%% ULTRA-FAST ELECTRIC VEHICLE CHARGING SIMULATION WITH BATTERY AGING
% EE584: Power Electronics - Fall 2025
% Author: Lorans Hirmez
% Description: Simulates 350kW fast charging with different cooling strategies
% and battery aging effects

clear all; close all; clc;

%% BATTERY PACK SPECIFICATIONS
Q_nom = 100;           % Battery capacity [kWh]
n_series = 96;         % Series cells
n_parallel = 72;       % Parallel cells
V_min = 350;           % Minimum voltage [V]
V_max = 450;           % Maximum voltage [V]
m_battery = 500;       % Thermal mass [kg]
c_p_battery = 1000;    % Specific heat [J/(kg·K)]
A_surface = 3;         % Surface area [m²]
T_max_safe = 45;       % Safety temperature limit [°C]

%% CHARGING PARAMETERS
P_charge = 350e3;      % Charging power [W]
I_charge = 400;        % Charging current [A]
SOC_start = 0.20;      % Starting SOC
SOC_end = 0.80;        % Ending SOC
dt = 1;                % Time step [s]

%% ELECTRICAL MODEL PARAMETERS
R0_base = 0.05;        % Base resistance at 25°C [Ω]
alpha_R = 0.005;       % Temperature coefficient [1/°C]
R1 = 0.01;             % RC network resistance 1 [Ω]
C1 = 1000;             % RC network capacitance 1 [F]
R2 = 0.015;            % RC network resistance 2 [Ω]
C2 = 5000;             % RC network capacitance 2 [F]
tau1 = R1 * C1;        % Time constant 1 [s]
tau2 = R2 * C2;        % Time constant 2 [s]
dOCV_dT = -0.0003;     % Entropic coefficient [V/K]

%% BATTERY AGING PARAMETERS
k_cal = 0.0001;        % Calendar aging constant
E_a = 30000;           % Activation energy [J/mol]
R_gas = 8.314;         % Gas constant [J/(mol·K)]
B_cyc = 31630;         % Cycle aging pre-exponential factor
z_cyc = 0.55;          % Cycle aging power exponent
alpha_cyc = 0.00025;   % Current stress factor [1/A]
beta_cyc = 0.045;      % Temperature stress factor [1/K]

%% COOLING CONFIGURATIONS
cooling_configs = {
    'No Active Cooling', 10, 0, 0;
    'Liquid Cooling', 500, 20, 5000;
    'Refrigerant Cooling', 1200, 10, 12000;
    'PCM Cooling', 300, 42, 8000
};

%% AMBIENT TEMPERATURE SCENARIOS
T_ambient_scenarios = [25, 35]; % [°C]

%% MAIN SIMULATION LOOP
for scenario = 1:length(T_ambient_scenarios)
    T_ambient = T_ambient_scenarios(scenario);
    
    fprintf('\n=== SIMULATION SCENARIO %d: T_ambient = %.0f°C ===\n', scenario, T_ambient);
    
    figure('Position', [100, 100, 1400, 800]);
    
    for config = 1:size(cooling_configs, 1)
        cooling_name = cooling_configs{config, 1};
        h_conv = cooling_configs{config, 2};  % [W/(m²·K)]
        T_coolant = cooling_configs{config, 3}; % [°C]
        cost = cooling_configs{config, 4};      % [$]
        
        fprintf('\n--- Running: %s ---\n', cooling_name);
        
        % Initialize variables
        SOC = SOC_start;
        T_cell = T_ambient;
        V1 = 0;
        V2 = 0;
        t = 0;
        idx = 1;
        
        % Storage arrays
        time_data = [];
        SOC_data = [];
        T_cell_data = [];
        Q_gen_data = [];
        Q_cool_data = [];
        V_terminal_data = [];
        P_cool_data = [];
        
        % Run charging simulation
        while SOC < SOC_end && T_cell < T_max_safe
            % Open Circuit Voltage
            OCV = V_min + SOC * (V_max - V_min);
            
            % Temperature-dependent resistance
            R0 = R0_base * (1 + alpha_R * (T_cell - 25));
            
            % Terminal voltage (2nd order equivalent circuit)
            V_terminal = OCV - I_charge * R0 - V1 - V2;
            
            % Update RC network voltages
            V1 = V1 * exp(-dt/tau1) + I_charge * R1 * (1 - exp(-dt/tau1));
            V2 = V2 * exp(-dt/tau2) + I_charge * R2 * (1 - exp(-dt/tau2));
            
            % Heat generation
            Q_joule = I_charge^2 * R0;  % Joule heating [W]
            T_abs = T_cell + 273.15;
            Q_entropic = I_charge * T_abs * dOCV_dT;  % Entropic heating [W]
            Q_gen = Q_joule + Q_entropic;
            
            % Cooling power
            if strcmp(cooling_name, 'PCM Cooling')
                % PCM cooling effectiveness near melting point
                if T_cell < T_coolant
                    Q_cool = h_conv * A_surface * (T_cell - T_ambient);
                else
                    Q_cool = h_conv * A_surface * (T_cell - T_coolant);
                end
            else
                if T_coolant == 0
                    Q_cool = h_conv * A_surface * (T_cell - T_ambient);
                else
                    Q_cool = h_conv * A_surface * (T_cell - T_coolant);
                end
            end
            
            % Compressor power for refrigerant system
            if strcmp(cooling_name, 'Refrigerant Cooling')
                COP = 3.0;
                P_compressor = Q_cool / COP;
            else
                P_compressor = 0;
            end
            
            % Temperature update
            dT_dt = (Q_gen - Q_cool) / (m_battery * c_p_battery);
            T_cell = T_cell + dT_dt * dt;
            
            % SOC update
            dSOC = (I_charge * dt) / (Q_nom * 1000 * 3600 / V_min);
            SOC = SOC + dSOC;
            
            % Store data
            time_data(idx) = t;
            SOC_data(idx) = SOC * 100;
            T_cell_data(idx) = T_cell;
            Q_gen_data(idx) = Q_gen / 1000;  % Convert to kW
            Q_cool_data(idx) = Q_cool / 1000;
            V_terminal_data(idx) = V_terminal;
            P_cool_data(idx) = P_compressor / 1000;
            
            t = t + dt;
            idx = idx + 1;
        end
        
        % Calculate metrics
        charging_time = time_data(end) / 60;  % [minutes]
        peak_temp = max(T_cell_data);
        avg_temp = mean(T_cell_data);
        energy_delivered = trapz(time_data, V_terminal_data .* I_charge) / 3.6e6;  % [kWh]
        energy_cooling = trapz(time_data, P_cool_data);  % [kWh]
        final_SOC = SOC_data(end);
        
        % Battery aging calculation (for 1 cycle)
        t_hours = time_data(end) / 3600;
        T_avg_K = mean(T_cell_data) + 273.15;
        
        % Calendar aging
        Q_loss_cal = k_cal * sqrt(t_hours) * exp(-E_a / (R_gas * T_avg_K));
        
        % Cycle aging (1 cycle = 0.6 equivalent full cycle for 20-80% SOC)
        N_equiv = 0.6;
        Q_loss_cyc = B_cyc * N_equiv^z_cyc * exp(alpha_cyc * I_charge) * ...
                     exp(beta_cyc * (T_avg_K - 298.15));
        
        % Normalize cycle aging
        Q_loss_cyc = Q_loss_cyc / 1e6;  % Scale factor
        
        capacity_retention_1cycle = 100 * (1 - Q_loss_cal - Q_loss_cyc);
        
        % Estimate cycle life to 80% capacity
        cycles_to_80 = 20 / (Q_loss_cal + Q_loss_cyc);
        
        fprintf('Charging Time: %.2f min\n', charging_time);
        fprintf('Peak Temperature: %.2f°C\n', peak_temp);
        fprintf('Average Temperature: %.2f°C\n', avg_temp);
        fprintf('Final SOC: %.2f%%\n', final_SOC);
        fprintf('Energy Delivered: %.2f kWh\n', energy_delivered);
        fprintf('Capacity Retention (1 cycle): %.4f%%\n', capacity_retention_1cycle);
        fprintf('Est. Cycle Life (80%% EOL): %.0f cycles\n', cycles_to_80);
        
        % Plotting - Temperature
        subplot(2, 2, 1);
        plot(time_data/60, T_cell_data, 'LineWidth', 2, 'DisplayName', cooling_name);
        hold on;
        yline(T_max_safe, 'r--', 'LineWidth', 1.5, 'DisplayName', 'Safety Limit');
        xlabel('Time [min]');
        ylabel('Temperature [°C]');
        title(sprintf('Cell Temperature (T_{ambient} = %.0f°C)', T_ambient));
        legend('Location', 'best');
        grid on;
        
        % Plotting - Heat Generation vs Cooling
        subplot(2, 2, 2);
        plot(time_data/60, Q_gen_data, '-', 'LineWidth', 2, 'DisplayName', [cooling_name ' (Gen)']);
        hold on;
        plot(time_data/60, Q_cool_data, '--', 'LineWidth', 2, 'DisplayName', [cooling_name ' (Cool)']);
        xlabel('Time [min]');
        ylabel('Power [kW]');
        title('Heat Generation vs Cooling Power');
        legend('Location', 'best');
        grid on;
        
        % Plotting - SOC
        subplot(2, 2, 3);
        plot(time_data/60, SOC_data, 'LineWidth', 2, 'DisplayName', cooling_name);
        hold on;
        xlabel('Time [min]');
        ylabel('SOC [%]');
        title('State of Charge');
        legend('Location', 'best');
        grid on;
        ylim([0 100]);
        
        % Plotting - Terminal Voltage
        subplot(2, 2, 4);
        plot(time_data/60, V_terminal_data, 'LineWidth', 2, 'DisplayName', cooling_name);
        hold on;
        xlabel('Time [min]');
        ylabel('Voltage [V]');
        title('Terminal Voltage');
        legend('Location', 'best');
        grid on;
    end
    
    sgtitle(sprintf('Ultra-Fast Charging Simulation Results (T_{ambient} = %.0f°C)', T_ambient));
end

%% BATTERY AGING ANALYSIS OVER MULTIPLE CYCLES
fprintf('\n=== LONG-TERM BATTERY AGING ANALYSIS ===\n');

n_cycles = 1000;  % Simulate 1000 cycles
T_ambient_aging = [25, 35];   % Both ambient temperatures

for amb_idx = 1:length(T_ambient_aging)
    T_amb_current = T_ambient_aging(amb_idx);
    
    fprintf('\n--- Aging Analysis at T_ambient = %.0f°C ---\n', T_amb_current);
    
    figure('Position', [100 + (amb_idx-1)*50, 100 + (amb_idx-1)*50, 1200, 800]);
    
    for config = 1:size(cooling_configs, 1)
        cooling_name = cooling_configs{config, 1};
        h_conv = cooling_configs{config, 2};
        T_coolant = cooling_configs{config, 3};
        
        fprintf('Processing aging for: %s\n', cooling_name);
        
        capacity_fade = zeros(1, n_cycles);
        Q_capacity = Q_nom * ones(1, n_cycles);
        
        for cycle = 1:n_cycles
            % Average temperature during charging depends on ambient temp
            if T_amb_current == 25
                % 25°C ambient case
                if strcmp(cooling_name, 'No Active Cooling')
                    T_avg_cycle = 42;
                elseif strcmp(cooling_name, 'PCM Cooling')
                    T_avg_cycle = 33;
                elseif strcmp(cooling_name, 'Liquid Cooling')
                    T_avg_cycle = 27;
                elseif strcmp(cooling_name, 'Refrigerant Cooling')
                    T_avg_cycle = 25;
                else
                    T_avg_cycle = 30;  % Default fallback
                end
            else  % 35°C ambient case
                % Higher ambient = higher operating temperatures
                if strcmp(cooling_name, 'No Active Cooling')
                    T_avg_cycle = 52;  % Exceeds safety, limited operation
                elseif strcmp(cooling_name, 'PCM Cooling')
                    T_avg_cycle = 43;  % Near safety limit
                elseif strcmp(cooling_name, 'Liquid Cooling')
                    T_avg_cycle = 37;
                elseif strcmp(cooling_name, 'Refrigerant Cooling')
                    T_avg_cycle = 35;
                else
                    T_avg_cycle = 40;  % Default fallback
                end
            end
            
            T_avg_K = T_avg_cycle + 273.15;
            
            % Cumulative calendar aging
            t_total_hours = cycle * 0.5;  % Assume 30 min per cycle
            Q_loss_cal = k_cal * sqrt(t_total_hours) * exp(-E_a / (R_gas * T_avg_K));
            
            % Cumulative cycle aging
            N_equiv = cycle * 0.6;
            Q_loss_cyc = B_cyc * N_equiv^z_cyc * exp(alpha_cyc * I_charge) * ...
                         exp(beta_cyc * (T_avg_K - 298.15));
            Q_loss_cyc = Q_loss_cyc / 1e8;  % Better scaling factor to prevent unrealistic degradation
            
            % Total capacity (ensure it doesn't go below 0)
            Q_capacity(cycle) = max(0, Q_nom * (1 - Q_loss_cal - Q_loss_cyc));
            capacity_fade(cycle) = 100 * Q_capacity(cycle) / Q_nom;
        end
        
        % Plot capacity fade
        subplot(2, 1, 1);
        plot(1:n_cycles, capacity_fade, 'LineWidth', 2, 'DisplayName', cooling_name);
        hold on;
        yline(80, 'r--', 'LineWidth', 1.5, 'DisplayName', 'EOL (80%)');
        xlabel('Cycle Number');
        ylabel('Capacity Retention [%]');
        title(sprintf('Battery Capacity Fade Over Cycling (T_{ambient} = %.0f°C)', T_amb_current));
        legend('Location', 'best');
        grid on;
        ylim([75 101]);
        
        % Plot capacity [kWh]
        subplot(2, 1, 2);
        plot(1:n_cycles, Q_capacity, 'LineWidth', 2, 'DisplayName', cooling_name);
        hold on;
        yline(80, 'r--', 'LineWidth', 1.5, 'DisplayName', 'EOL (80 kWh)');
        xlabel('Cycle Number');
        ylabel('Capacity [kWh]');
        title(sprintf('Absolute Battery Capacity (T_{ambient} = %.0f°C)', T_amb_current));
        legend('Location', 'best');
        grid on;
    end
end

fprintf('\nSimulation Complete!\n');