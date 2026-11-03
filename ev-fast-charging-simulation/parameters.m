P=350e3;
V=400;
Fs=50;
Ws=2*pi*Fs;
Fsw=10e3;
Ta=(0.5)/Fsw;
Wsw=2*pi*Fsw;
Vdc= 800;
I_ripple=0.2*sqrt(2)*P/(sqrt(3)*V);
R=0.004;
Rf=0.001;
Rt=R+Rf;
Cdc=1000e-6;
%BASE IMPEDANCE
Zb=V^2/P;
Cb=1/(Ws*Zb);
% CONVERTER SIDE INDUCTOR
L=Vdc/(8*Fsw*I_ripple);

% FILTER CAPACITOR
x = 0.05;
Cf=x*Cb;

% ATTENUATION FACTOR
a=L*Cb*Wsw^2;
attenuation=0.05;
r= (1-(1/attenuation))/-(1-a*x);
if r<0
    r= (1+(1/attenuation))/-(1-a*x);
end

% GRID SIDE INDUCTOR
Lf=L*r;
    
% TOTAL LINE INDUCTANCE
Lt=L+Lf;
    
% RESONANCE FREQUENCY
Wres=sqrt(Lt/(L*Lf*Cf));
Fres=Wres/(2*pi);
    
 %DAMPING RESISTOR
rd=1/(3*Wres*Cf);

fi=7;
fc=1/2*Fsw;

% syms Kp Ki       % //FIRST METHOD//
% G=(Kp+2*pi*fi*Kp/(2*j*pi*fc))*(1/(1+Ta*2*j*pi*fc))*(1/(Rt+2*j*pi*fc*Lt))
% G = simplify(G)
% equ=abs(G)==1
kpi=4.9973;
kii=219.7931;

%outer loop
fc2=(1/20)*fc;
fi2=1/5*fc2;

% syms Kpv       % //FIRST METHOD//
% Gv=(Kpv+2*pi*fi2*Kpv/(2i*pi*fc2))*(3/2*(V/Vdc)*1/(2i*pi*fc2*Cdc))
% Gv = simplify(Gv)
% equ_v=abs(Gv)==1
kpv=2.0537;
kiv=645.1962;

% % Define the open-loop transfer function with PI controller
% s = tf('s');
% G_PIV = (kpv + kiv/s);                  % PI controller


  %% DC-DC CONVERTER DESIGN %%%%
    
    	Vin = 700;    % DC-LINK VOLTAGE
		Vo_max = 450;      % Maximum output voltage (V)
		Io_max = 350;      % Maximum output current (A)
		fsw = 100e3;        % Switching frequency (Hz)
		ripple_current = 0.1; % Current ripple factor (10%)
		ripple_voltage = 0.01; % Voltage ripple factor (1%)
		
		% Worst-case duty cycle calculations
		D_max = Vo_max/(Vo_max+Vin);
		
        % Average current calculation
       I_L=Io_max/(1-D_max);
       
		% Inductor design
		delta_IL = ripple_current * I_L;
		Lch = (Vin * D_max)/(delta_IL * fsw);
		

		% Peak current calculation (for both inducrtor and the switch)
		IL_peak = I_L+ 0.5*delta_IL;
        
        % Saturation Current
        IL_SAT=1.2*IL_peak;
        
		% Capacitor design
		delta_Vo = ripple_voltage * Vo_max;
		Co = (Io_max * D_max)/(fsw * delta_Vo);



