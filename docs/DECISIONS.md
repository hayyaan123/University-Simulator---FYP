# Decision log

A short record of key technical decisions and why we made them. Add new decisions to the top.

| # | Decision | Why | Alternatives considered |
| --- | --- | --- | --- |
| 7 | The simulation runs continuously, semester after semester, until the user stops it. Stats are reported at the end of each semester | It's a what-if tool with no end-game. Long-run effects (stress building up, dropouts, cohorts moving through years) only show up over many semesters, and users can change parameters and watch the next semesters respond | Fixed-length runs (one week or one semester) that end, then Reset |
| 6 | GitHub repo with Issues + Project board | Repo already set up; Issues/board give us task tracking and evidence of project management | GitLab |
| 5 | Semester 2 ML: small models run in GDScript from JSON first; Python sidecar only if time allows | No plugins, works on every machine, fast, easy to explain. The planned models (logistic regression, trees) are simple to evaluate by hand | Python sidecar only; GDExtension ONNX plugin (community-maintained, harder setup) |
| 4 | Many small models, one per decision | Easier to train, test and explain than one large model | One combined model |
| 3 | Discrete-event simulation with continuous time | Travel time and lateness need minute-level precision; faster than ticking every agent every frame | Fixed time-step agent loop |
| 2 | GDScript (Godot Standard build) | Simple setup for the whole team; no .NET needed | C# (.NET build) |
| 1 | Godot 4.7 | Supervisor's suggestion; lightweight, open source, good 2D tools | Unity |

Hand-set probabilities are used until the ML stage. Real datasets (OULAD, UCI) are only needed for training in Semester 2.
