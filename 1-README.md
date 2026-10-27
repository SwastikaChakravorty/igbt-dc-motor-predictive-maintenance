# IGBT-fed DC motor drive: condition monitoring

A MATLAB/Simulink project that adds a **read-only, threshold-calibrated decision tree** to a PID-controlled, PWM-driven DC motor drive.

The monitor identifies normal operation, overload, field-current abnormality and speed deviation. It reports a condition code, a maintenance warning and a threshold-margin score without changing the PID, PWM or IGBT command.

> Simulation-based condition classification, not remaining useful life prediction or a hardware protection system. The supplied report calls this predictive maintenance because its condition indicators can support maintenance planning.

## System at a glance

```text
Speed reference --> PID --> PWM --> IGBT chopper --> DC motor + load
        ^                                                |
        +--------------- speed feedback -----------------+
                                                         |
               Read-only measurements + reference/load --+
                         |
              Low-pass feature extraction
                         |
              Threshold decision tree
                         |
           Condition code / warning / margin score
```

## Condition codes

Rules run in priority order after a 3-second start-up hold-off. If several limits are crossed, the highest-priority rule wins.

| Priority | Rule | Code | Meaning |
| --- | --- | --- | --- |
| 1 | Absolute mean speed error > `T_err` | 3 | Speed deviation |
| 2 | Absolute mean field-current deviation > `T_if` | 2 | Field current abnormal |
| 3 | Armature-current RMS > `T_irms` | 1 | Abnormal current / overload |
| Otherwise | No threshold exceeded | 0 | Normal operation |

`pm_predict.m` applies the feature rules offline. The start-up hold-off and warning filter are implemented in the Simulink monitor, not in that function.

## Repository contents

| File | Purpose |
| --- | --- |
| `PEproject_PredictiveMaintenance.slx` | Drive model, monitoring subsystem and dashboard |
| `pm_setup.m` | Default settings; loads saved thresholds when available |
| `pm_generate_data.m` | Creates labelled simulation scenarios and feature logs |
| `pm_train_model.m` | Calibrates thresholds and prints validation/test metrics |
| `pm_predict.m` | Vectorized offline decision-tree rules |
| `pm_run_demo.m` | Runs normal, overload, field and supply-sag examples |
| `pm_dataset.mat` | Supplied simulation feature dataset |
| `pm_trained.mat` | Supplied calibrated threshold parameters |
| `PROJECT_NOTES.md` | Feature definitions, calibration and reported results |
| `VALIDATION.md` | Checks performed for this repository and remaining checks |

The original report, ZIP archive, workspace dump, autosaves, caches and older model backups are deliberately excluded. This is a curated project repository, not the submitted report. It does not assert sole authorship.

## Requirements

- MATLAB and Simulink. The included model's package metadata identifies **R2025a**. Older-release compatibility has not been verified.
- Simscape Electrical with the Specialized Power Systems blocks used by the drive.
- Threshold calibration uses base MATLAB operations, not a Statistics and Machine Learning Toolbox classifier.

## Run the project

Keep the model, scripts and MAT files together. In MATLAB, change the Current Folder to this repository.

```matlab
pm_setup
open_system('PEproject_PredictiveMaintenance.slx')
pm_run_demo('normal')
pm_run_demo('overload')
pm_run_demo('field')
pm_run_demo('sag')
```

The model calls `pm_setup` during initialization. When `pm_trained.mat` is present it uses those saved thresholds. Move that file aside to use the engineering starting values in `pm_setup.m`.

To generate a fresh dataset and calibrate again:

```matlab
pm_generate_data('quick')
pm_train_model
% Optional larger scenario set:
% pm_generate_data('full')
% pm_train_model
```

These commands overwrite `pm_dataset.mat` and `pm_trained.mat`; back them up first if you want to preserve the supplied data. Read the `EXCLUDED` and failed-run messages before interpreting the training output.

The generator overrides load-step parameters per scenario. The demo script does not reset a manually edited load step, so restore its `After` value to `0` before comparing the four demo cases.

## Dashboard interpretation

- **Condition code:** the selected rule, not a probability.
- **Maintenance warning:** filtered abnormal status exceeds `0.8`; the filter time constant is `0.5 s`. This is not a fixed 0.5-second delay.
- **Health index (0-100):** distance from the most limiting normalized threshold. It is not percent life remaining, failure probability or physical health percentage. A permissible heavy load can lower it.
- **Monitor active:** `0` during the first 3 seconds, then `1`.

## What the results do and do not show

The supplied report records the expected codes for four demonstration cases. The dataset contains 25 scenarios and 2,400 feature rows. Those examples are not a statistical accuracy claim or independent hardware validation.

No temperature, vibration, insulation ageing, brush wear, bearing degradation or IGBT junction-temperature diagnosis is implemented. No remaining useful life estimate or automatic shutdown is provided. Model warnings about unconnected device output ports need engineering review.

See [project notes](PROJECT_NOTES.md) and [validation status](VALIDATION.md) before reusing the results.
