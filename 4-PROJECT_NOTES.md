# Project notes

## Feature extraction

First-order low-pass filters use `tau = 0.5 s`. They approximate filtered moments, not a finite rectangular sliding window.

The logged `pm_features` vector contains:

1. Mean armature current (A).
2. Armature-current RMS (A).
3. Armature-current standard deviation (A).
4. Mean speed (RPM).
5. Speed standard deviation (RPM).
6. Mean reference-minus-measured speed error (RPM).
7. Mean field current (A).
8. Reference speed (RPM).
9. Load torque (N m).

RMS is the square root of the filtered current second moment. Variance is the filtered second moment minus the squared filtered mean, clipped below at zero before taking a square root. The classifier directly uses features 2, 6 and 7.

## Supplied calibrated parameters

Values below were read from `pm_trained.mat`, not substituted for the defaults in `pm_setup.m`.

| Parameter | Value | Unit |
| --- | --- | --- |
| `tau` | 0.5 | s |
| `t_hold` | 3 | s |
| `t_deb` | 0.5 | s |
| `warn_level` | 0.8 | dimensionless |
| `T_irms` | 20.4472495 | A |
| `T_err` | 43.8259180 | RPM |
| `if_nom` | 1.0668488 | A |
| `T_if` | 0.1334153 | A |

The threshold-margin score is:

```text
r = max(Irms/T_irms, abs(Eavg)/T_err, abs(Ifmean-if_nom)/T_if)
H = 100 * (1 - min(1, max(0, r)))
```

During start-up the model forces normal code and a margin score of 100. The active flag is needed to distinguish that hold-off from a diagnostic result.

## Scenario data and calibration

The supplied quick dataset has 13 normal, 4 overload, 4 weakened-field and 4 armature-supply-sag scenarios. Each contributes 96 samples, from 4.5 to 14 seconds at 0.1-second intervals: 2,400 rows and 9 feature columns.

Labels originate from injected scenario conditions. The generator excludes cases that fail its manifestation criteria. This produces deliberately separated fault cases; it is not a representative real-world degradation dataset.

`pm_train_model.m` splits whole scenarios, stratified by class, so correlated samples from one run do not cross the train/validation/test boundaries. It aims for 60/20/20 proportions, subject to class counts and rounding. Thresholds maximize balanced accuracy at each node. The script first evaluates training-derived thresholds on validation data, then refits on training plus validation and evaluates on the held-out test set.

With only four scenarios in each abnormal class, the independent test evidence is small. Save the printed metrics and evaluate more operating conditions before making performance claims.

## Demonstration results reported in the supplied project report

These are source-reported simulation examples, not new runs performed for this repository.

| Case | Reference RPM | Load N m | Armature V | Field V | Code | RMS current A | Absolute speed error RPM | Mean field current A |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Normal | 700 | 4 | 240 | 300 | 0 | 4.7 | 0.0 | 1.067 |
| Overload | 700 | 30 | 240 | 300 | 1 | 30.4 | 0.0 | 1.067 |
| Field abnormality | 700 | 4 | 240 | 195 | 2 | 7.2 | 0.0 | 0.693 |
| Supply sag | 1200 | 4 | 100 | 300 | 3 | 4.7 | 371.1 | 1.067 |

The reported sag speed is about 828.9 RPM. Warning is off for the normal example and on for the three abnormal examples. The normal dashboard's reported score is 77.1; abnormal examples show zero. Instantaneous current on the dashboard is different from the RMS feature and should not be compared as if they were identical quantities.

## Limits and next work

- Review the reported unconnected output-port warnings for Diode1, Diode2 and IGBT. Their impact has not been established here.
- Run the included model and scripts in MATLAB/Simulink and preserve the complete logs.
- Test noise, sensor errors, parameter drift, operating-point variation and simultaneous faults.
- Validate on hardware or an independent benchmark before engineering use.
- Treat condition classification, health-score trending and remaining useful life prediction as separate tasks.

## Source basis

Prepared from the supplied project report titled "Simulation-Based Predictive Maintenance Monitoring for an IGBT-Fed DC Motor Drive Using a Threshold-Calibrated Decision Tree" and the supplied MATLAB/Simulink project archive. Personal names, registration numbers, email addresses and the report's external supplementary-material link are not reproduced.
