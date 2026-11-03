# Ultra-Fast EV Charging System (350 kW): MATLAB/Simulink Model

A MATLAB/Simulink simulation of a 350 kW DC fast-charging station, built for **EE 584 Power Electronics** (Fall 2025, San Diego State University). It covers the grid-side rectifier, the DC-DC charging stage, a battery model with thermal dynamics, and a comparison of three cooling strategies.

**Author:** Lorans Hirmez  
**Course instructor:** Prof. Reza Sabzehgar

![System model](images/System_model.png)

## What it models

| Stage | Description |
|---|---|
| Grid and AFE rectifier | Three-phase active front end with an LCL filter and a PI current/voltage control loop, regulating a DC link |
| Buck-boost DC-DC converter | Steps the DC link (700 V) to the battery voltage range (350 to 450 V) at up to 350 A |
| Charging controller | CC-CP-CV: constant current, then constant power (350 kW limit), then constant voltage as the state of charge rises |
| Battery model | 100 kWh pack (96s72p) with an equivalent-circuit electrical model and a lumped thermal model |
| Cooling comparison | Liquid, refrigerant-based, and phase-change-material (PCM) cooling under 350 kW charging, with a 45 °C safety limit |
| Aging and economics | Battery capacity-fade simulation over repeated fast-charge cycles and a techno-economic estimate for a 350 kW station |

## Key design parameters

These come from `parameters.m` and the thermal scripts:

- AC side: 400 V line voltage, 50 Hz, 10 kHz switching, DC link 800 V
- DC-DC stage: 700 V input, 450 V max output, 350 A max output current, 100 kHz switching, 10% current ripple, 1% voltage ripple
- LCL filter, damping resistor, and PI gains are computed in `parameters.m` from the ripple and attenuation targets
- Battery: 100 kWh, 250 Ah, 350 to 450 V, 500 kg thermal mass, 3 m² effective surface area

## Repository layout

```
.
├── SYSTEM_MODEL.slx              Simulink model of the full charger
├── parameters.m                  Run first: defines converter, filter and controller parameters
├── scripts/
│   ├── UFC_Thermal_Simulation.m  Cooling-strategy comparison (liquid, refrigerant, PCM)
│   ├── Battery_Aging_final.m     Charging simulation with battery aging
│   └── Battery_Aging_10_year.m   Long-horizon aging run
├── images/                       Model screenshots and simulation plots
└── docs/
    └── EE584_Final_Report.pdf    Full written report
```

## How to run

1. Open MATLAB and set this folder as the current folder.
2. Run `parameters.m`. This loads the variables the Simulink model needs into the workspace.
3. Open `SYSTEM_MODEL.slx` and click **Run**. The model uses a 3 µs discrete step, so a full run takes a while.
4. Run `scripts/UFC_Thermal_Simulation.m` or `scripts/Battery_Aging_final.m` on their own. They are self-contained scripts, not tied to the Simulink model.

**Requirements:** MATLAB and Simulink. If the model reports missing blocks on opening, install the add-on named in the error message (the power-electronics blocks typically come from Simscape Electrical).

## Results

Simulated waveforms confirm proper operation of the AC-DC and DC-DC stages: the grid current tracks the grid voltage phase, the DC link is regulated, and the charger moves from constant-current to constant-voltage as the battery fills. See the report in `docs/` for the plots and the cooling and economic analysis.

![Grid voltage and current](images/Grid%20Phase%20Voltage%20and%20Current.png)

## Notes

- Heavy files (the 137 MB `.fig`, presentation, video and generated Simulink cache) are intentionally not included. See `.gitignore`.
- This is coursework, so parameters such as battery resistance and thermal coefficients are modeling assumptions, not measured values from a real station.
