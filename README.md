# Campus Simulator

A campus simulation built in Godot for a Monash final year project (FIT3161 / FIT3163 / FIT3188). It models how students move through a university semester. Each student has their own timetable and walks between buildings for their classes. They decide whether to attend, and they can arrive late when back-to-back classes are far apart. You can adjust 15 parameters (class lengths, gaps, room sizes, student numbers, deadlines and more) and watch four results trade off against each other at the end of every semester: grades, stress, energy and satisfaction.

The first version runs one week end to end: campus map, timetable, walking, lateness and attendance. Student states, errands and the semester calendar are being built now (see the [roadmap](docs/ROADMAP.md)).

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
autoload/        Params (settings), EventBus (signals), Stats (running totals)
sim/core/        SimEngine, EventQueue, SimEvent, SimTime, SimRunner
sim/campus/      Campus (graph + shortest paths)
sim/timetable/   TimetableGenerator, ClassSession
sim/students/    Student
decisions/       DecisionModel (base), DecisionContext; RuleDecision / MLDecision later
scenes/          Main scene, MapView; ParamPanel and Dashboard to come
data/            campus.json, units.json, scenarios/
tests/           GUT tests and test helpers
tools/           Python scripts for data and model training (Semester 2)
docs/            Architecture, student model, parameters, roadmap, decisions and more
```

## Docs

- [Architecture](docs/ARCHITECTURE.md): how the simulation works, and where new files go
- [Student model](docs/STUDENT_MODEL.md): grades, stress, energy and satisfaction, and what moves them
- [Code style](docs/CODE_STYLE.md)
- [Contributing](docs/CONTRIBUTING.md): setup, branches, pull requests
- [Data formats](docs/DATA_FORMATS.md): campus, units, scenarios, logs, ML models
- [Parameters](docs/PARAMETERS.md): the 15 things you can adjust, and why each one is there
- [Roadmap](docs/ROADMAP.md): scope, owners, sprints
- [Decision log](docs/DECISIONS.md)

## Team

Peshaant (lead), Hayyaan, Siw, Shuyu, Arya. Supervised by Tan Choon Ling.

## Map data

The campus is Monash University Malaysia, built from OpenStreetMap data (© OpenStreetMap contributors, available under the [Open Database Licence](https://www.openstreetmap.org/copyright)). See `tools/build_campus_from_osm.py`.

## Datasets (Semester 2)

- Kuzilek, J., Hlosta, M., & Zdrahal, Z. (2017). Open University Learning Analytics dataset. *Scientific Data, 4*, 170171.
- Realinho, V., Machado, J., Baptista, L., & Martins, M. V. (2022). Predicting student dropout and academic success. *Data, 7*(11), 146.
