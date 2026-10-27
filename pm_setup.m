function pm_setup
%PM_SETUP  Puts the predictive-maintenance parameters (struct PM) in the base workspace.
%   Called automatically by the model (Model InitFcn).  You normally never run it by hand.
%
%   * Default values below are ENGINEERING STARTING VALUES, not trained values.
%   * If pm_trained.mat exists (created by pm_train_model.m) it is loaded instead.
%
%   PM.tau        [s]  time constant of the moving-window (low-pass) filters used for features
%   PM.t_hold     [s]  start-up hold-off: the classifier output is forced to NORMAL before this time
%   PM.t_deb      [s]  debounce time of the maintenance warning (condition must persist)
%   PM.warn_level [-]  debounced indicator must exceed this value (0..1) to raise the warning
%   PM.T_irms     [A]  decision-tree node 3: RMS armature current above this -> ABNORMAL CURRENT
%   PM.T_err      [RPM] node 1: |mean speed error| above this -> SPEED DEVIATION
%   PM.if_nom     [A]  nominal field current (mean of NORMAL data when trained)
%   PM.T_if       [A]  node 2: |field current - if_nom| above this -> FIELD CURRENT ABNORMAL
PM.tau = 0.5;  PM.t_hold = 3;  PM.t_deb = 0.5;  PM.warn_level = 0.8;
PM.T_irms = 24;  PM.T_err = 60;  PM.if_nom = 1.0665;  PM.T_if = 0.15;
PM.trained = false;  PM.trained_on = 'not trained (default engineering thresholds)';
f = fullfile(fileparts(mfilename('fullpath')),'pm_trained.mat');
if exist(f,'file')
    S = load(f);
    PM = S.PM;  PM.trained = true;
end
assignin('base','PM',PM);
end
