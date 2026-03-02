# Trust Dynamics in Human-Robot Teams: Agent-Based Simulation (Trustv7)

An agent-based model implemented in NetLogo that simulates trust development, task delegation, and performance in human-robot teams. The model features trust-dependent delegation with an emergent over-reliance mechanism, calibrated against published meta-analytic benchmarks.

## Key Findings

- **Non-linear reliability-performance relationship**: Performance peaks at 95% reliability before declining, driven by trust-mediated misallocation of judgment tasks (cubic polynomial, ΔAIC = 79 over linear; η² = 0.851)
- **Metric-dependent predictor reversal**: Transparency drives allocation quality (η² = 0.090 on misallocation) but has no effect on aggregate performance (η² < 0.001) — standard metrics mask the difference
- **Trust calibration**: Saturating exponential trust trajectories match Hancock et al. (2021) meta-analytic benchmarks (R² = 0.850)

## Model Architecture

The model implements three interacting mechanisms:

1. **Adaptive Kalman trust filter** with stress- and transparency-modulated measurement noise
2. **Trust-dependent delegation** with quadratic probability for judgment tasks, enabling emergent over-reliance
3. **Task-type-sensitive success** with asymmetric modifiers (humans excel at judgment tasks, robots at routine tasks)

## Repository Contents

```
├── Trustv7.nlogo                  # NetLogo model with BehaviorSpace experiments
├── analysis/                      # Simulation output CSVs
│   ├── trustv7-analysis.r         # R analysis script (all figures and statistics)
├── README.md
├── data/                          # Simulation output CSVs
│   ├── Sweep_Reliability.csv
│   ├── Sweep_Reliability_x_Transparency.csv
│   └── TimeSeries_Baseline.csv
└── figures/                       # Generated figures (PNG + SVG)
    ├── Fig1_reliability_v7.*
    ├── Fig2_rel_x_trans_perf.*
    ├── Fig3_misallocation_interaction.*
    └── Fig4_trust_trajectory.*
```

## Requirements

- **NetLogo** 6.4.0 or later — [Download](https://ccl.northwestern.edu/netlogo/download.shtml)
- **R** 4.0+ with packages: `tidyverse`, `svglite`

## Quick Start

### Running the Simulation

1. Open `Trustv7.nlogo` in NetLogo
2. Click **Setup** then **Go** for a single interactive run
3. For experiments: **Tools → BehaviorSpace** and select an experiment

### BehaviorSpace Experiments

| Experiment | Design | Runs | Purpose |
|---|---|---|---|
| `Sweep_Reliability` | 15 levels × 50 reps | 750 | Reliability-performance curve |
| `Sweep_Reliability_x_Transparency` | 5 × 5 × 50 reps | 1,250 | Transparency moderation + misallocation |
| `Sweep_Reliability_x_Delegation` | 5 × 5 × 50 reps | 1,250 | Delegation sensitivity moderation |
| `Sweep_Transparency_x_Workload` | 5 × 5 × 50 reps | 1,250 | Stress buffering |
| `TimeSeries_Baseline` | 20 reps, every 20 ticks | 20 | Trust trajectory calibration |
| `TimeSeries_Transparency_Compare` | 3 levels × 20 reps | 60 | Transparency trajectory comparison |

### Running the Analysis

1. Open `trustv7-analysis-revised.r` in RStudio
2. Install dependencies: `install.packages(c("tidyverse", "svglite"))`
3. Run the script — it will prompt for 3 CSV files in order:
   - Reliability Sweep CSV
   - Reliability × Transparency CSV
   - TimeSeries Baseline CSV
4. Figures are saved as both PNG (300 dpi) and SVG

## Model Parameters

| Parameter | Default | Range | Description |
|---|---|---|---|
| `num-humans` | 3 | 1–5 | Number of human agents |
| `num-robots` | 3 | 1–5 | Number of robot agents |
| `robot-reliability` | 90 | 0–100 | Robot task success base rate (%) |
| `robot-transparency` | 50 | 0–100 | Robot communication of limitations (%) |
| `robot-autonomy` | 70 | 0–100 | Willingness to attempt difficult tasks (%) |
| `robot-comm-frequency` | 50 | 0–100 | Probability of status communication (%) |
| `initial-trust` | 50 | 0–100 | Starting trust level |
| `initial-tasks` | 30 | 1–100 | Number of tasks at setup |
| `delegation-sensitivity` | 0.5 | 0–1 | Scales delegation probability |
| `collaboration-rate` | 50 | 0–100 | Probability task requires collaboration (%) |
| `max-ticks` | 2000 | — | Simulation duration |

## Core Equations

**Adaptive Kalman trust filter:**

```
K(t) = P(t) / [P(t) + R(t)]
θ(t+1) = θ(t) + K(t) · [ρ_observed − θ(t)]
P(t+1) = (1 − K(t)) · P(t) + Q

R(t) = R_base × (1 + σ²) × (1 + (1 − τ)²)
```

where R_base = 10, Q = 0.5, σ = stress/100, τ = transparency/100.

**Trust-dependent delegation:**

```
P(delegate | routine)  = (θ/100) × δ
P(delegate | judgment) = (θ/100)² × δ
P(recognize mismatch)  = τ/100
```

**Task success with type modifiers:**

```
Human:  P = min(1, ε/d) × modifier   [judgment: ×1.3, routine: ×0.85]
Robot:  P = (ρ/100) × min(1, ψ/d) × modifier   [routine: ×1.2, judgment: ×0.6]
```

## Calibration Targets

| Benchmark | Target | Result | Status |
|---|---|---|---|
| Trust trajectory (Hancock et al., 2021) | Saturating exponential | R² = 0.850, asymptote = 90.5 | ✓ Pass |
| Reliability dominance (Hancock et al., 2011) | Strongest predictor | η² = 0.851 | ✓ Pass |
| Non-linear dynamics | Performance plateau | Cubic best, ΔAIC = 79 | ✓ Pass |
| Transparency → misallocation | Reduces misallocation | η² = 0.090, p < .001 | ✓ Pass |
| Transparency → performance (Chen et al., 2018) | ~27% improvement | η² < 0.001 | ✗ Not met |

The Chen et al. calibration failure is explained by emergent system-level compensation: transparency redirects task allocation without changing aggregate throughput. See paper Section 6.2.3.

## Citation

If you use this model in your research, please cite:

```
[Author]. (2026). Agent-based simulation of trust development in human-robot teams:
A calibrated framework with trust-dependent delegation. [Journal]. 
```

## License

This project is licensed under the Creative Commons Attribution 4.0 International License (CC BY 4.0).

## References

- Hancock, P. A., et al. (2011). A meta-analysis of factors affecting trust in human-robot interaction. *Human Factors*, 53(5), 517–527.
- Hancock, P. A., et al. (2021). Evolving trust in robots: Specification through sequential and comparative meta-analyses. *Human Factors*, 63(7), 1196–1229.
- Parasuraman, R., & Riley, V. (1997). Humans and automation: Use, misuse, disuse, abuse. *Human Factors*, 39(2), 230–253.
- Chen, J. Y., et al. (2018). Situation awareness-based agent transparency and human-autonomy teaming effectiveness. *Theoretical Issues in Ergonomics Science*, 19(3), 259–282.
- Hoff, K. A., & Bashir, M. (2015). Trust in automation: Integrating empirical evidence on factors that influence trust. *Human Factors*, 57(3), 407–434.
