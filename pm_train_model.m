function pm_train_model
%PM_TRAIN_MODEL  Learns the thresholds of the 3-node decision tree from pm_dataset.mat.
%   Needs only base MATLAB (no Statistics / Machine Learning Toolbox).
%
%   Tree (same structure as the blocks inside the Simulink monitor, see pm_predict.m):
%     node 1: |mean speed error| > T_err           -> 3 SPEED DEVIATION
%     node 2: |field current - if_nom| > T_if       -> 2 FIELD CURRENT ABNORMAL
%     node 3: RMS armature current   > T_irms       -> 1 ABNORMAL CURRENT (OVERLOAD)
%     otherwise                                      -> 0 NORMAL OPERATION
%   Each threshold is learned from data: the value that best separates the fault class from the
%   classes that reach that node (max. balanced accuracy, centred in the gap between the classes).
%
%   DATA SPLIT: whole scenarios (runs) are assigned to train (60%) / validation (20%) / test (20%),
%   stratified per class, so correlated samples of one run never appear in two sets.
%     step 1: thresholds learned on TRAIN, reported on VALIDATION
%     step 2: thresholds re-learned on TRAIN+VALIDATION, reported once on the untouched TEST set
%   The final thresholds are saved in pm_trained.mat and are picked up automatically by the model.
here = fileparts(mfilename('fullpath'));  addpath(here);
pm_setup;  PM0 = evalin('base','PM');
S = load(fullfile(here,'pm_dataset.mat'));  D = S.D;  sc = S.sc;  meta = S.meta;
assert(abs(meta.PM_tau-PM0.tau)<1e-12 && abs(meta.PM_t_hold-PM0.t_hold)<1e-12, ...
    'Dataset was generated with different filter settings (PM.tau / PM.t_hold). Regenerate the data.');

Irms = D.X(:,2);  Eabs = abs(D.X(:,6));  Ifm = D.X(:,7);  y = D.y;

% ---- scenario-level stratified split ----
rng(7);  split = zeros(numel(sc),1);
for c = 0:3
    ids = find([sc.valid] & [sc.cls]==c);  n = numel(ids);
    if n < 3, error('Class %d has only %d valid scenarios (need >= 3). Run pm_generate_data(''full'') or read the EXCLUDED messages.',c,n); end
    ids = ids(randperm(n));  ntr = max(1,round(0.6*n));  nva = max(1,round(0.2*n));
    if ntr+nva >= n, ntr = n-2; nva = 1; end
    split(ids(1:ntr)) = 1;  split(ids(ntr+1:ntr+nva)) = 2;  split(ids(ntr+nva+1:end)) = 3;
    fprintf('class %d: %d scenarios -> train %d / val %d / test %d\n',c,n,ntr,nva,n-ntr-nva);
end
rs = split(D.sid);   % split of every sample
tr = rs==1;  va = rs==2;  te = rs==3;

% ---- step 1: learn on train, evaluate on validation ----
PM = learn(PM0, Irms, Eabs, Ifm, y, tr);
fprintf('\n=== VALIDATION set (thresholds learned on train only) ===\n');
report(PM, Irms, D.X(:,6), Ifm, y, rs, va, D.sid);

% ---- step 2: learn on train+val, evaluate once on test ----
PM = learn(PM0, Irms, Eabs, Ifm, y, tr|va);
fprintf('\n=== TEST set (thresholds learned on train+validation) ===\n');
report(PM, Irms, D.X(:,6), Ifm, y, rs, te, D.sid);

PM.trained = true;  PM.trained_on = datestr(now);
PM.n_scenarios = sum(split>0);
save(fullfile(here,'pm_trained.mat'),'PM');
fprintf('\nLearned thresholds: T_err = %.1f RPM, T_if = %.3f A (if_nom = %.4f A), T_irms = %.2f A\n',PM.T_err,PM.T_if,PM.if_nom,PM.T_irms);
fprintf('Saved pm_trained.mat  (the Simulink model loads it automatically through pm_setup).\n');
fprintf('NOTE: results come from simulated faults of this model only; they are not a validation on a real machine.\n');
end

function PM = learn(PM0, Irms, Eabs, Ifm, y, m)
PM = PM0;
PM.if_nom = mean(Ifm(m & y==0));
PM.T_err  = best_thr(Eabs(m & (y==0|y==1|y==2)), Eabs(m & y==3));
dev = abs(Ifm - PM.if_nom);
PM.T_if   = best_thr(dev(m & (y==0|y==1)), dev(m & y==2));
PM.T_irms = best_thr(Irms(m & y==0), Irms(m & y==1));
end

function T = best_thr(neg, pos)
% rule "positive if value > T"; maximise balanced accuracy, return centre of the best range
v = sort([neg(:); pos(:)]);  v = unique(v);
if numel(v) > 600, v = v(round(linspace(1,numel(v),600))); v = unique(v); end
cand = (v(1:end-1) + v(2:end))/2;
ba = zeros(size(cand));
for k = 1:numel(cand), ba(k) = 0.5*(mean(pos > cand(k)) + mean(neg <= cand(k))); end
idx = find(ba >= max(ba) - 1e-12);
T = 0.5*(cand(idx(1)) + cand(idx(end)));
end

function report(PM, Irms, Eavg, Ifm, y, rs, m, sid)
p = pm_predict(Irms(m), Eavg(m), Ifm(m), PM);  t = y(m);
C = accumarray([t+1, p+1], 1, [4 4]);
names = {'NORMAL','OVERLOAD','FIELD','SPEED-DEV'};
fprintf('Confusion matrix (rows = true class, cols = predicted):\n        %s\n',sprintf('%10s',names{:}));
for i = 1:4, fprintf('%-9s%s\n',names{i},sprintf('%10d',C(i,:))); end
for i = 1:4
    tp = C(i,i);  prec = tp/max(1,sum(C(:,i)));  rec = tp/max(1,sum(C(i,:)));
    fprintf('  %-9s precision %.3f   recall %.3f   (n=%d)\n',names{i},prec,rec,sum(C(i,:)));
end
fprintf('  False-alarm rate (NORMAL samples flagged abnormal): %.4f\n',sum(C(1,2:4))/max(1,sum(C(1,:))));
fprintf('  Missed-fault rate (fault samples predicted NORMAL): %.4f\n',sum(C(2:4,1))/max(1,sum(sum(C(2:4,:)))));
% scenario level: most frequent prediction per run
ids = unique(sid(m));  ok = 0;
for k = 1:numel(ids)
    q = m & sid==ids(k);  pk = pm_predict(Irms(q),Eavg(q),Ifm(q),PM);  ok = ok + (mode(pk)==mode(y(q)));
end
fprintf('  Scenario-level: %d of %d runs classified correctly (majority vote)\n',ok,numel(ids));
end
