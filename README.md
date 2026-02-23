# Human-Robot Trust Dynamics ABM (Trustv5)

[![NetLogo 6.4.0](https://img.shields.io/badge/NetLogo-6.4.0-blue)](https://ccl.northwestern.edu/netlogo/)
[![License: CC BY 4.0](https://img.shields.io/badge/License-CC%20BY%204.0-lightgrey.svg)](https://creativecommons.org/licenses/by/4.0/)

## Overview

Agent-based model simulating trust development, stress dynamics, and performance in human-robot teams. Implemented in NetLogo 6.4.0, the model captures Kalman-filter-based trust convergence, bounded stress accumulation, and difficulty-dependent task success in teams of 1–5 humans and 1–5 robots.

**Paper:** "Agent-Based Simulation of Trust Development in Human-Robot Teams: A Calibrated Framework for Team Design"

## Key Findings

- Robot reliability explains **88% of variance** in team performance (η² = 0.877)
- Reliability-performance relationship is **linear** (R² = 0.90, no diminishing returns)
- Transparency, autonomy, and communication frequency have **negligible effects** (<0.1% variance each)
- Trust converges exponentially toward robot reliability (R² = 0.998 for exponential fit)

## Repository Structure

```
trust_calib/
├── README.md
├── model/
│   └── Trustv5.nlogo                          # NetLogo model (corrected implementation)
├── experiments/
│   ├── sweep_experiments.xml                  # BehaviorSpace single-parameter sweeps
│   └── scenario_comparison.xml                # BehaviorSpace factorial comparison
├── analysis/
│   ├── 01_scenario_factorial_analysis.R       # Factorial ANOVA and main effects
│   ├── 02_reliability_sweep_analysis.R        # Polynomial fit and reliability curve
│   └── 03_interaction_analysis.R              # Reliability × Transparency interaction
├── data/
│   ├── Trustv5_All_Scenarios_Comparison-table.csv
│   ├── Sweep_Reliability-table.csv
│   └── Sweep_Reliability_x_Transparency-table.csv
└── paper/
    └── manuscript.md                          # Final manuscript
```

## Quick Start

1. Install [NetLogo 6.4.0](https://ccl.northwestern.edu/netlogo/download.shtml)
2. Open `model/Trustv5.nlogo`
3. Click **Setup** then **Go** to run a single simulation
4. For batch experiments: Tools → BehaviorSpace → Import `experiments/sweep_experiments.xml`

## Running Experiments

### Via NetLogo GUI
1. Open Trustv5.nlogo → Tools → BehaviorSpace
2. Select experiment → Run → Choose Table output

### Via Command Line (requires Java 17+)
```bash
java -Xmx4g -cp "path/to/NetLogo/app/*" org.nlogo.headless.Main \
  --model model/Trustv5.nlogo \
  --experiment "Sweep_Reliability" \
  --table data/Sweep_Reliability-table.csv \
  --threads 4
```

## Model Parameters

| Parameter | Slider Name | Baseline | Range |
|-----------|------------|----------|-------|
| Team size (humans) | num-humans | 3 | 1–5 |
| Team size (robots) | num-robots | 3 | 1–5 |
| Initial trust | initial-trust | 50 | 0–100 |
| Robot reliability | robot-reliability | 90 | 0–100 |
| Robot transparency | robot-transparency | 50 | 0–100 |
| Robot autonomy | robot-autonomy | 70 | 0–100 |
| Communication freq. | robot-comm-frequency | 50 | 0–100 |
| Collaboration rate | collaboration-rate | 50 | 0–100 |
| Initial tasks | initial-tasks | 30 | 1–100 |
| Simulation length | max-ticks | 2000 | 1–10000 |

## Core Equations

**Trust (Kalman filter):** θ(t+1) = θ(t) + 0.01 × [ρ_observed − θ(t)]

**Stress (bounded):** σ(t+1) = σ(t) + 0.1·w(t)·[1 − σ(t)/100] − 0.5·σ(t)/100

**Task success:** P(success) = min(1, expertise/difficulty) for humans; reliability/100 for robots

**Work rate:** ω = ε/50 (normal), ω = 0.8·ε/50 (stress > 70)

## Citation

```bibtex
@article{kalluri2025trust,
  title={Agent-Based Simulation of Trust Development in Human-Robot Teams: A Calibrated Framework for Team Design},
  author={Kalluri, Ravi},
  year={2025}
}
```

## License

This work is licensed under a Creative Commons Attribution 4.0 International License.
