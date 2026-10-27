function pm_run_demo(kind)
%PM_RUN_DEMO  Runs ONE scenario on the model and prints the predicted condition.
%   pm_run_demo('normal') | 'overload' | 'field' | 'sag'  (default 'normal')
%   For additional tests change the numbers below, or open the model and edit the blocks
%   (see README: Slider Gain = reference speed, Constant = load torque, Load Step, DC sources).
if nargin < 1, kind = 'normal'; end
mdl = 'PEproject_PredictiveMaintenance';  here = fileparts(mfilename('fullpath'));  addpath(here);
if ~bdIsLoaded(mdl), load_system(fullfile(here,[mdl '.slx'])); end
ref = 700;  TL = 4;  Va = 240;  Vf = 300;       % NORMAL: 700 RPM, 4 N.m
switch kind
    case 'overload', TL = 30;                    % far above rated load
    case 'field',    Vf = 0.65*300;              % weakened field supply
    case 'sag',      ref = 1200;  Va = 100;      % armature supply too low to reach the reference
end
in = Simulink.SimulationInput(mdl);
in = in.setModelParameter('StopTime','14');
in = in.setBlockParameter([mdl '/' sprintf('Slider\nGain')],'gain',num2str(ref));
in = in.setBlockParameter([mdl '/Constant'],'Value',num2str(TL));
in = in.setBlockParameter([mdl '/DC Voltage Source1'],'Amplitude',num2str(Va));
in = in.setBlockParameter([mdl '/DC Voltage Source4'],'Amplitude',num2str(Vf));
o = sim(in);  ts = o.get('pm_features');  X = squeeze(ts.Data);  if size(X,1)~=numel(ts.Time), X = X.'; end
evalin('base','pm_setup');  PM = evalin('base','PM');
code = pm_predict(X(end,2),X(end,6),X(end,7),PM);
names = {'NORMAL OPERATION','ABNORMAL CURRENT (OVERLOAD)','FIELD CURRENT ABNORMAL','SPEED DEVIATION'};
fprintf('Scenario "%s": Irms = %.1f A, mean speed error = %.1f RPM, field current = %.3f A\n',kind,X(end,2),X(end,6),X(end,7));
fprintf('Predicted condition at t = %.0f s: %d = %s   (thresholds %s)\n',ts.Time(end),code,names{code+1},tern(PM.trained,'TRAINED','DEFAULT'));
end
function s = tern(c,a,b), if c, s = a; else, s = b; end, end
