# tools/

These Python scripts are for Semester 2. They are not part of the Godot build.

Planned scripts:

- `prepare_data.py`: cleans OULAD / UCI data and the sim run logs (`decisions.csv`, `outcomes.csv`) and maps their columns to the `DecisionContext.to_features()` keys
- `train_models.py`: trains the small models (logistic regression, decision trees) with scikit-learn and prints accuracy
- `export_model.py`: writes a trained model to `ml/<name>.json` in the format in `docs/DATA_FORMATS.md`
- `check_export.py`: runs the exported JSON model on a test set in Python and compares its predictions with scikit-learn's, so the GDScript version can be trusted

Put raw datasets in `tools/datasets/`. That folder is git-ignored, so download the datasets there instead of committing them.
