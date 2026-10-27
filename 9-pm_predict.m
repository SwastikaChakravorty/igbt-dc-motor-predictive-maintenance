function code = pm_predict(Irms, Eavg, Ifmean, PM)
%PM_PREDICT  Same 3-node decision tree that is built from blocks inside the Simulink monitor.
%   Inputs may be column vectors.  Output code: 0 NORMAL, 1 ABNORMAL CURRENT (OVERLOAD),
%   2 FIELD CURRENT ABNORMAL, 3 SPEED DEVIATION.
code = zeros(size(Irms));
code(Irms > PM.T_irms) = 1;                         % node 3 (lowest priority)
code(abs(Ifmean - PM.if_nom) > PM.T_if) = 2;        % node 2
code(abs(Eavg) > PM.T_err) = 3;                     % node 1 (highest priority)
end
