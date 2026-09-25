# University Simulator 2026

A campus simulation built in Godot for a Monash final year project (FIT3161 / FIT3163 / FIT3188). It models how students move through a university week. Each student has their own timetable and walks between buildings for their classes. They decide whether to attend, and they can arrive late when back-to-back classes are far apart. You can adjust parameters (class lengths, gaps, walking speed, room sizes, student numbers and more) and watch attendance, lateness, room use and crowding change on the dashboard.

In Semester 2, small machine learning models trained on real student data (OULAD, UCI Dropout) take over the student decisions while the simulation runs.

## Quick start

1. Install **Godot 4.7.x (Standard, not .NET)**.
2. Clone this repo and open `project.godot`.
3. Install **GUT 9.x** from the AssetLib into `addons/gut` and enable the plugin.
4. Press F5 to run, or run the tests:
   ```
   godot --headless -s addons/gut/gut_cmdln.gd
   ```

## Project structure

```
autoload/    Params (settings), EventBus (signals), Stats (running totals)
sim/         SimEngine, EventQueue, SimEvent, SimTime, Student, ClassSession, Campus, SimRunner
decisions/   DecisionModel (base), DecisionContext; RuleDecision / MLDecision later
scenes/      Main scene; MapView, ParamPanel, Dashboard to come
data/        campus.json, units.json, scenarios/
tests/       GUT tests and test helpers
tools/       Python scripts for data and model training (Semester 2)
docs/        Architecture, code style, contributing, data formats, roadmap, decisions
```

## Docs

- [Architecture](docs/ARCHITECTURE.md): how the simulation works
- [Code style](docs/CODE_STYLE.md)
- [Contributing](docs/CONTRIBUTING.md): setup, branches, pull requests
- [Data formats](docs/DATA_FORMATS.md): campus, units, scenarios, logs, ML models
- [Parameters and effects](docs/PARAMETERS.md): what you can adjust and what the sim measures (proposal)
- [Roadmap](docs/ROADMAP.md): scope, owners, sprints
- [Decision log](docs/DECISIONS.md)

## Team

Peshaant (lead), Hayyaan, Siw, Shuyu, Arya. Supervised by Tan Choon Ling.

## Datasets (Semester 2)

- Kuzilek, J., Hlosta, M., & Zdrahal, Z. (2017). Open University Learning Analytics dataset. *Scientific Data, 4*, 170171.
- Realinho, V., Machado, J., Baptista, L., & Martins, M. V. (2022). Predicting student dropout and academic success. *Data, 7*(11), 146.
