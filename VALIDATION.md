# Validation status

## Checked during repository preparation

- Inspected all five included MATLAB scripts and the Simulink package's XML.
- Parsed all XML parts in the curated model package successfully.
- Confirmed the model initialization callback is `pm_setup`.
- Read the saved threshold struct and checked the dataset shape and class counts: 2,400 rows, 9 columns; class counts 1,248 / 384 / 384 / 384.
- Independently applied the documented priority rules to the supplied dataset in Python. All 2,400 stored rows matched their stored labels. **This is an in-sample consistency check using the supplied final thresholds, not held-out accuracy or a rerun of MATLAB training.**
- Removed personal authorship metadata from the packaged model, and scanned the publication files for the omitted member/faculty names, registration numbers and email addresses.

## Not checked here

MATLAB/Simulink was not available during repository preparation. The model was not opened or simulated in MATLAB, and the `.m` functions were not executed here. No fresh validation/test metrics, compatibility guarantee, hardware result or safety claim is made.

The current model identifies R2025a in its internal release metadata. The source README's R2021a claim was not used as a compatibility guarantee.

The fallback monitor-builder script is omitted because it expects an original model that is not included under its expected filename. The archive's repair helper, caches, backups and workspace dump are also omitted rather than presented as the supported entry point.
