# DSM-SRH
![MATLAB](https://img.shields.io/badge/MATLAB-R2023b-orange)
![Optimization Toolbox](https://img.shields.io/badge/Toolbox-Optimization-blue)
![License](https://img.shields.io/badge/License-MIT-green)

## Script for testing DSM code based on internship project

this repository contains MATLAB code developed for a microgrid demand Side Management DSM case study, conducted while a traineeship at UCPP in Ajaccio, Corsica. The project investigates how optimization techniques can coordinate PV generation, grid and flexible loads with an objective function of minimize operational costs.
The optimization approach are implemented as Linear Programming model and Mixed Integer Linear Programming frameworks, for a Microgrid representing a typical three-node system consisting of PV generation, Grid and Loads demand, where this final load incorporates flexible loads such as Dispatchable loads and Schedulable loads (for the MILP framework).

the system is modeled with operational constraints susch as:
Energy requirements
Power limits
Time window operational restriction
Continuous constraints
and Single start constraints

Repository Structure
DSM-SRH
│
│
├── run_LP
│   ├── MGdMatrices_vec.m
│   └── energy_data.csv
│
├── run_MILP
|   |── Datasets
│       ├── energy_data.csv
│       ├── PyranoBelleJournee.csv
│       ├── PyranoMauvaiseJournee.csv
│   ├── Helper Functions
│       ├── buildBaselineScenario.m
│       ├── compareBaselines
│       ├── MGdIneqBlock.m
│       ├── MGdMatrices_Zpls.m
│       ├── preprocessIrradiance.m
│   ├── objectivefunction.m
│   ├── runMILP.m
│   └── plotVisualizations
│       ├── plotEnergySystem  
│       ├── compareScenarios
│ 
├── Microgrid_baselineScenario
│   └── MicrogridProjectUCP.m
|   |── Datasets
│       ├── energy_data.csv
│       ├── PyranoBelleJournee.csv
│       ├── PyranoMauvaiseJournee.csv
│   ├── Helper Functions
│       ├── buildBaselineScenarioMinutes.m
│       ├── MGdIneqBlockminutes.m
│       ├── MGdMatrices_Zplsminutes.m
│       ├── preprocessIrradiance.m
│
├── plotEnergySystemminutes.m
│
├── Visualization Outputs
│   ├── EnergyFlows.png
│   ├── CostVsRevenue.png
│   ├── CumulativeNetCost.png
│   ├── TotalLoadProfile.png
│   └── TotalLoadProfile2.png
│
└── README.md


%% Requirements
to run scripts MATLAB R2023b or later is required
Note: MATLAB is proprietary software and requires a valid MathWorks license to run the scripts.
Solvers used:
- linprog (LP framework)
- intlinprog (MILP framework)

Author:
Cristhian Almendares

Master of Engineering
Sustainable Technology Management
SRH University

Note:
Some portions of the MATLAB code structure and documentation were developed with assistance from AI-based tools (Copilot agents). All generated code was reviewed, validated, and integrated by the author. The final implementation, testing, and methodological decisions remain the responsibility of the project author.
