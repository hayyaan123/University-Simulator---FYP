# tools/

Python scripts that are not part of the Godot build.

## Campus map

- `build_campus_from_osm.py`: turns the OpenStreetMap extract in `data/osm/` into `data/campus.json`. Run it with `python tools/build_campus_from_osm.py data/osm/monash_malaysia.osm data/campus.json`. It only needs the Python standard library.

## Semester 2 (planned)

- `prepare_data.py`: cleans OULAD / UCI data and the sim run logs (`decisions.csv`, `outcomes.csv`) and maps their columns to the `DecisionContext.to_features()` keys
- `train_models.py`: trains the small models (logistic regression, decision trees) with scikit-learn and prints accuracy
- `export_model.py`: writes a trained model to `ml/<name>.json` in the format in `docs/DATA_FORMATS.md`
- `check_export.py`: runs the exported JSON model on a test set in Python and compares its predictions with scikit-learn's, so the GDScript version can be trusted

Put raw datasets in `tools/datasets/`. That folder is git-ignored, so download the datasets there instead of committing them.
