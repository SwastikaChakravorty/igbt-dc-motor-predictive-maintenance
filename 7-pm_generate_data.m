function pm_generate_data(mode)
%PM_GENERATE_DATA  Runs many scenarios on the Simulink model and stores labelled feature data.
%   pm_generate_data('quick')  ~25 runs   (default, try this first)
%   pm_generate_data('full')   ~70 runs   (better statistics, takes much longer)
%
%   Features are NOT recomputed here: they are logged by the monitor inside the model
%   (To Workspace block 'pm_features'), so training and inference use identical features.
%   Column order of pm_features:
%     1 Imean  2 Irms  3 Istd  4 Wmean[RPM]  5 Wstd[RPM]  6 Eavg[RPM] (ref-speed)  7 If_mean  8 ref[RPM]  9 TL[Nm]
%
%   LABELS come from the scenario that was injected (not from thresholds on the features):
%     0 NORMAL (incl. normal load steps)         1 OVERLOAD (load torque far above rated)
%     2 FIELD CIRCUIT ABNORMAL (field supply reduced)   3 SPEED DEVIATION (armature supply sag -> cannot reach reference)
%   A scenario is kept only if the injected condition really "manifested" in the simulation
%   (see manifestation criteria below); otherwise it is excluded and reported.
if nargin < 1, mode = 'quick'; end
mdl  = 'PEproject_PredictiveMaintenance';
here = fileparts(mfilename('fullpath'));  addpath(here);
pm_setup;  PM = evalin('base','PM');
if ~bdIsLoaded(mdl), load_system(fullfile(here,[mdl '.slx'])); end

% ---------------- editable assumptions ----------------
Irated = 17;      % [A] approx. rated armature current of the 5 HP / 240 V machine (3730 W / (240 V*0.9))
Tsim   = 14;      % [s] length of every run
tstep  = 8;       % [s] time of the load step (scenarios with a step)
t_eval0 = PM.t_hold + 1.5;   % first usable sample (start-up transient and filter settling excluded)
Vsup0  = 240;  Vfld0 = 300;  % nominal armature / field supply of the drive model

pSlider = [mdl '/' sprintf('Slider\nGain')];  pTL = [mdl '/Constant'];  pStep = [mdl '/Load Step'];
pVa = [mdl '/DC Voltage Source1'];  pVf = [mdl '/DC Voltage Source4'];

% ---------------- 1) calibration run: torque per ampere ----------------
fprintf('Calibration run ...\n');
o = run_one(700, 4, 0, Vsup0, Vfld0);
[tt,X] = get_feat(o);  Imean_cal = mean(X(tt > Tsim-3, 1));
Tloss = 0.5161 + 0.002953*700*pi/30;           % friction + viscous loss (machine data of the drive model)
Kt = (4 + Tloss)/Imean_cal;                    % effective N.m per A at nominal field
fprintf('  steady armature current at TL=4 N.m, 700 RPM: %.2f A -> Kt_eff = %.3f N.m/A\n',Imean_cal,Kt);
TLof = @(frac) max(0, Kt*frac*Irated - Tloss); % load torque that gives frac*Irated armature current

% ---------------- 2) scenario list ----------------
S = {};
if strcmp(mode,'full')
    refsN = [500 700 900 1100];  fN = [0.10 0.30 0.50 0.70 0.90];
    stepsN = [700 0.2 0.7; 700 0.7 0.2; 1000 0.3 0.9; 600 0.6 0.15; 900 0.1 0.8; 500 0.8 0.3];
    refsO = [500 700 800];  fO = [1.5 1.7 1.9];
    vfF = [0.55 0.65 0.75];  refsF = [600 900];
    vaS = [90 110];  refsS = [1000 1200 1300];
else
    refsN = [500 800 1100];  fN = [0.15 0.45 0.80];
    stepsN = [700 0.2 0.7; 700 0.7 0.2; 1000 0.3 0.9; 600 0.6 0.15];
    refsO = [600 800];  fO = [1.6 1.9];
    vfF = [0.60 0.75];  refsF = [600 900];
    vaS = [90 110];  refsS = [1000 1300];
end
for r = refsN, for f = fN, S(end+1,:) = {0,sprintf('normal ref%d f%.2f',r,f),r,f,0,Vsup0,Vfld0}; end, end
for k = 1:size(stepsN,1)
    S(end+1,:) = {0,sprintf('normal load step ref%d %.2f->%.2f',stepsN(k,:)),stepsN(k,1),stepsN(k,2),stepsN(k,3)-stepsN(k,2),Vsup0,Vfld0};
end
for r = refsO, for f = fO, S(end+1,:) = {1,sprintf('overload ref%d f%.2f',r,f),r,f,0,Vsup0,Vfld0}; end, end
for r = refsF, for v = vfF, S(end+1,:) = {2,sprintf('field supply x%.2f ref%d',v,r),r,0.35,0,Vsup0,Vfld0*v}; end, end
for r = refsS, for v = vaS, S(end+1,:) = {3,sprintf('supply sag %dV ref%d',v,r),r,0.30,0,v,Vfld0}; end, end
N = size(S,1);  fprintf('%d scenarios, %d s each.\n',N,Tsim);

% ---------------- 3) run ----------------
D.X = [];  D.y = [];  D.sid = [];  D.t = [];
for i = 1:N
    cls = S{i,1};  ref = S{i,3};  TL0 = TLof(S{i,4});  dTL = TLof(S{i,4}+S{i,5}) - TL0;
    sc(i).cls=cls; sc(i).name=S{i,2}; sc(i).ref=ref; sc(i).TL0=TL0; sc(i).dTL=dTL; sc(i).Va=S{i,6}; sc(i).Vf=S{i,7};
    sc(i).valid = false;  sc(i).reason = '';
    try
        o = run_one(ref, TL0, dTL, S{i,6}, S{i,7});
        [tt,X] = get_feat(o);
        [tt,iu] = unique(tt);  X = X(iu,:);
        tq = (t_eval0:0.1:Tsim)';  Xq = interp1(tt,X,tq);
        late = tq > Tsim-3;
        mI = median(Xq(late,2));  mE = median(abs(Xq(late,6)));  mF = median(abs(Xq(late,7)-PM.if_nom));
        switch cls     % manifestation criteria (physical meaning of the injected condition)
            case 0, ok = mE < 30 && mI < 1.0*Irated;      why = 'normal run not clean (tracking error or current above rated)';
            case 1, ok = mI >= 1.25*Irated;               why = 'armature current did not exceed 125% of rated';
            case 2, ok = mF >= 0.16 && mE < 30;           why = 'field current not reduced by >=15% or speed lost';
            case 3, ok = mE >= 50;                        why = 'speed error below 50 RPM: supply sag did not limit speed';
        end
        sc(i).valid = ok;  if ~ok, sc(i).reason = why; end
        sc(i).medIrms = mI;  sc(i).medAbsErr = mE;  sc(i).medIfDev = mF;
        if ok
            D.X = [D.X; Xq];  D.y = [D.y; cls*ones(size(tq))];  D.sid = [D.sid; i*ones(size(tq))];  D.t = [D.t; tq];
        end
        fprintf('[%2d/%d] class %d %-38s Irms=%5.1f A  |err|=%6.1f RPM  If-dev=%.3f  %s\n',i,N,cls,sc(i).name,mI,mE,mF,tern(ok,'ok',['EXCLUDED: ' sc(i).reason]));
    catch ME
        sc(i).reason = ME.message;  fprintf('[%2d/%d] %s FAILED: %s\n',i,N,sc(i).name,ME.message);
    end
end
meta.mode = mode; meta.Irated = Irated; meta.Kt = Kt; meta.Tsim = Tsim; meta.t_eval0 = t_eval0; meta.PM_tau = PM.tau; meta.PM_t_hold = PM.t_hold;
meta.columns = {'Imean','Irms','Istd','Wmean_RPM','Wstd_RPM','Eavg_RPM','Ifmean','ref_RPM','TL_Nm'};
save(fullfile(here,'pm_dataset.mat'),'D','sc','meta');
for c = 0:3
    fprintf('class %d: %d valid scenarios, %d samples\n',c,sum([sc.cls]==c & [sc.valid]),sum(D.y==c));
end
fprintf('Saved pm_dataset.mat\n');

% ---------------- nested helpers ----------------
    function simOut = run_one(ref,TL0,dTL,Va,Vf)
        in = Simulink.SimulationInput(mdl);
        in = in.setModelParameter('StopTime',num2str(Tsim));
        in = in.setBlockParameter(pSlider,'gain',num2str(ref));
        in = in.setBlockParameter(pTL,'Value',num2str(TL0,'%.6g'));
        in = in.setBlockParameter(pStep,'Time',num2str(tstep));
        in = in.setBlockParameter(pStep,'After',num2str(dTL,'%.6g'));
        in = in.setBlockParameter(pVa,'Amplitude',num2str(Va));
        in = in.setBlockParameter(pVf,'Amplitude',num2str(Vf));
        simOut = sim(in);
    end
end
function [t,X] = get_feat(o)
ts = o.get('pm_features');  t = ts.Time(:);  X = ts.Data;  X = squeeze(X);
if size(X,1) ~= numel(t), X = X.'; end
end
function s = tern(c,a,b), if c, s = a; else, s = b; end, end
