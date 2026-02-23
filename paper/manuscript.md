# Agent-Based Simulation of Trust Development in Human-Robot Teams: A Calibrated Framework for Team Design

## Abstract

Human-robot teams are increasingly deployed in complex operational environments, yet validated tools to predict team performance under varying conditions remain scarce. This paper presents an agent-based model, implemented in NetLogo, that captures trust dynamics, workload distribution, and performance in human-robot teams of 3–6 agents performing collaborative tasks. The model is calibrated against published experimental findings from human-robot interaction studies, achieving R² = 0.998 for trust evolution trajectory shape. A 576-cell factorial experiment (15,625 total runs) and a dedicated reliability sweep (15 levels, 50 replications each) reveal that robot reliability exhibits a strong linear relationship with team performance (η² = 0.88, R² = 0.90), dominating all other design parameters. No other parameter — transparency, autonomy, communication frequency, or collaboration rate — exhibits a meaningful effect on task success. A crossed reliability × transparency experiment (1,250 runs) confirms the absence of interaction effects. These findings identify reliability as the primary design lever in the current model architecture and highlight specific mechanism weaknesses — particularly in transparency and communication pathways — that guide future model development.

**Keywords:** human-robot interaction, trust dynamics, agent-based modeling, team performance, calibration

---

## 1. Introduction

The integration of robots into human work teams represents a fundamental shift from automated tools to collaborative partners. Unlike traditional automation, in which humans supervise machines, modern human-robot collaboration requires continuous interaction, mutual adaptation, and the development of trust (Hancock et al., 2011). This shift is evident in manufacturing, healthcare, and defense operations, where robots must adapt to dynamic human behaviors and uncertain task requirements.

Despite growing deployment, predictive tools for designing effective human-robot teams remain limited. Practitioners rely on trial-and-error approaches, risking team failure and the erosion of trust. Three critical gaps limit current understanding:

First, *trust-performance coupling*: how does trust evolution affect team productivity over time? Second, *optimal team composition*: what human-robot ratios maximize performance for different task types? Third, *failure recovery*: how can teams recover from automation failures?

This paper addresses these gaps by developing an agent-based model calibrated against published experimental data. The contributions include: (a) a simulation framework calibrated to published experimental findings in human-robot interaction, (b) identification of reliability as the dominant predictor of team performance through rigorous factorial experimentation, (c) honest assessment of model limitations including null effects for transparency and communication mechanisms, and (d) an open-source implementation for practitioner use and community extension.

The distinction between calibration and validation is important to clarify at the outset. Calibration involves tuning model parameters so that outputs match known empirical results; validation involves testing model predictions against independent data not used during calibration (Sargent, 2013). This paper primarily reports calibration results supplemented by extensive sensitivity analysis. True out-of-sample validation against independent experimental data remains a priority for future work.

---

## 2. Background and Related Work

### 2.1 Trust in Human-Robot Interaction

Trust fundamentally determines whether humans will rely on robotic teammates. Lee and See (2004) define trust in automation as the attitude that an agent will help achieve an individual's goals in a situation characterized by uncertainty. This definition highlights two critical aspects: goal alignment and uncertainty management.

Empirical studies have quantified trust dynamics across multiple dimensions. Hancock et al.'s (2011) meta-analysis of 29 studies identified robot performance as the strongest predictor of trust (r = 0.71). Salem et al. (2015) demonstrated that behavioral inconsistency reduces trust more severely than performance failures alone (d = 1.24). More recently, Tower and Brooks (2024) found that proactive failure acknowledgment preserved substantially more trust than reactive explanations.

However, these studies examine isolated factors. Real teams experience multiple interacting influences simultaneously: stress affects trust interpretation, communication overload degrades performance, and task complexity moderates all relationships. The present model integrates these factors within a unified framework to explore their joint dynamics.

### 2.2 Communication and Transparency

Transparency — making robot intentions and capabilities observable — critically affects trust development. Chen et al.'s (2018) Situation Awareness-based Agent Transparency (SAT) model identifies three levels of transparency, each providing progressively more information but also increasing cognitive load. Recent studies reveal that optimal transparency depends on context: Kunze et al. (2024) showed that adaptive transparency based on cognitive load improved performance by 32%.

### 2.3 Agent-Based Modeling in HRI

Agent-based models capture emergent properties arising from individual interactions, making them well-suited for studying human-robot teams. Lewis et al. (2018) demonstrated that agent-based models can predict team-level patterns with reasonable accuracy. Recent advances by Huang and Mutlu (2024) incorporate uncertainty in human decision-making, revealing previously hidden trust formation patterns. However, existing models generally lack systematic calibration against human subject data. The present approach addresses this gap by calibrating model parameters against published experimental results and examining model behavior through factorial sensitivity analysis.

---

## 3. Model Design

### 3.1 Conceptual Framework

The model represents three interacting systems:

**Human agents** possess trust levels that evolve based on observed robot performance. Trust affects willingness to delegate tasks and accept robot suggestions. Stress accumulates with workload and degrades performance above critical thresholds.

**Robot agents** operate with fixed reliability and transparency levels. They communicate status updates probabilistically based on a `communication-frequency` parameter, with each communication event increasing nearby humans' trust proportional to the robot's transparency level. Robot autonomy determines the agent's willingness to attempt tasks beyond its nominal capability: high-autonomy robots probabilistically take on more difficult tasks, while low-autonomy robots restrict themselves to tasks within their capability range.

**Tasks** are initialized as a batch of size `initial-tasks` (baseline: 30) at setup, with replenishment occurring every 50 ticks when the active task count falls below the initial level. Each task has difficulty drawn from a discrete uniform distribution U(10, 99) on a 0–100 scale, duration drawn from U(50, 199) ticks, and collaboration requirements assigned via a Bernoulli process with probability equal to the `collaboration-rate` parameter (baseline: 50%). Collaborative tasks require human-robot coordination, and successful completion triggers trust increases.

### 3.2 Core Dynamics

The model implements five mechanisms calibrated against empirical data:

**Trust Evolution.** Human trust updates follow a constant-gain Kalman filter formulation, converging toward the observed reliability of nearby robots:

$$\theta_{i}(t + 1) = \theta_{i}(t) + K[\rho_{\text{observed}} - \theta_{i}(t)]$$

where K = 0.01 is the constant learning rate and ρ_observed is the mean reliability of robots within an observation radius of 10 units. This produces asymptotic convergence toward the reliability of nearby robots, with the rate of convergence governed by K. The formulation is a special case of the Kalman filter with steady-state gain, as detailed in Appendix A. Additionally, trust is updated asymmetrically upon task completion: +1 for robot successes and −5 for robot failures observed by nearby humans. This asymmetry is consistent with empirical evidence that failures erode trust more severely than successes build it (Salem et al., 2015). Collaborative task completion adds +2 to trust. Trust is bounded on [0, 100].

**Stress Accumulation.** Stress follows bounded growth with proportional decay:

$$\sigma(t + 1) = \sigma(t) + \gamma \cdot w(t)[1 - \sigma(t)/100] - \delta \cdot \sigma(t)/100$$

where γ = 0.1 (stress accumulation rate) and δ = 0.5 (stress decay rate), with stress measured on a [0, 100] scale. The growth term γ·w·(1 − σ/100) ensures stress saturates under sustained workload, approaching the ceiling asymptotically. The decay term δ·σ/100 provides proportional recovery, with faster recovery at higher stress levels. The steady-state stress level under constant workload is σ* = 100·γw / (γw + δ), derived in Appendix A.

**Work Rate.** Agent productivity depends on capability and current stress state. For humans, work rate is ω = ε/50 under normal conditions, reduced to ω = 0.8·ε/50 when stress exceeds 70 (on the 0–100 scale). This represents a temporary 20% productivity reduction that reverses when stress decreases below the threshold. For robots, work rate is ω = ψ/50, with a 30% reduction when battery level falls below 30. Expertise is initialized from U(50, 99) and remains fixed throughout the simulation; stress affects only the work rate multiplier, not the underlying capability.

**Task Success.** The probability of successful task completion is:

$$P(\text{success}) = \begin{cases} \min(1, \varepsilon/d) & \text{for humans} \\ \rho/100 & \text{for robots} \end{cases}$$

where ε is expertise, d is task difficulty, and ρ is reliability (all on 0–100 scales). This formulation means that humans succeed reliably on tasks within their competence (ε > d) but face increasing failure probability as task difficulty approaches or exceeds their expertise.

**Team Efficiency.** The proportion of agents actively engaged:

$$E = \frac{|\text{working agents}|}{|\text{total agents}|}$$

### 3.3 Hypothesized Non-Linear Effects

Prior to empirical testing, we hypothesized that team performance might not increase monotonically with robot reliability due to potential over-reliance dynamics: at very high trust levels, humans might delegate excessively to robots, reducing their own task engagement and lowering overall team efficiency. However, this pathway requires a trust-dependent task allocation mechanism that is not implemented in the current model (agents take the nearest available task regardless of trust level). The empirical results (Section 6.2) confirm that this non-linear effect does not emerge, and Section 7.3 discusses the model extensions needed to test this hypothesis.

---

## 4. Implementation

### 4.1 NetLogo Environment

The model was implemented in NetLogo 6.4.0, chosen for its established use in social simulation and accessibility to practitioners without specialized programming backgrounds. The simulation operates on a 33 × 33 continuous space where agents move and interact.

**Agent Initialization.** Users specify team size (1–5 humans, 1–5 robots), initial trust levels, and robot parameters. Tasks spawn according to the batch replenishment process described in Section 3.1, with properties drawn from the specified distributions.

**Simulation Loop.** Each tick represents one minute of simulated operation: (1) update agent states including stress and battery levels, (2) assign available agents to nearby tasks using proximity-based matching, (3) execute collaborative matching for team tasks requiring human-robot coordination, (4) process robot-to-human communication events, (5) update trust based on observed outcomes, and (6) calculate global performance metrics.

### 4.2 Parameter Calibration

Model parameters were calibrated against published experimental findings through a systematic process. Calibration involves adjusting parameters until model outputs approximate known empirical results, which differs from validation, which tests predictions against data not used during model development (Sargent, 2013).

**Trust dynamics.** The learning rate K = 0.01 was selected to produce trust trajectories exhibiting exponential convergence consistent with the patterns reported in Hancock et al. (2011). Post-hoc verification confirms that the trust trajectory fits an exponential convergence model with R² = 0.998 (see Appendix C).

**Stress thresholds.** The accumulation rate γ = 0.1 and decay rate δ = 0.5 were calibrated so that the stress threshold at which performance degradation occurs aligns with the physiological transition points identified by Dehais et al. (2011). The work-rate reduction threshold is set at stress = 70.

**Communication effects.** The transparency parameter's influence on trust was intended to be calibrated to the performance improvements reported by Shah et al. (2011) and Chen et al. (2018). However, as documented in Section 6.3 and Appendix C, the implemented transparency mechanism produces negligible performance effects, indicating that this calibration target is not met in the current implementation.

### 4.3 Code Availability

The complete implementation is available at https://github.com/rkallur2/trust_calib. The repository includes the NetLogo model file, BehaviorSpace experiment configurations, R analysis scripts, and all simulation output data.

---

## 5. Calibration Assessment

### 5.1 Calibration Results

The model was assessed against five calibration targets from published studies. Because the model equations were substantially revised during development, recalibration was performed and is reported transparently, including targets that are not met.

**Trust Evolution.** The Kalman-filter trust update produces exponential convergence (R² = 0.998) with an asymptote above the robot's reliability level (96.7 for reliability = 90), reflecting the additive trust contributions from collaboration (+2) and successful task completion (+1). This exceeds the original calibration target and confirms that the trust mechanism produces the trajectory shape reported by Hancock et al. (2011).

**Stress Threshold.** The bounded stress dynamics produce mean stress levels near 70 (mean = 69.2 across the factorial experiment), consistent with the threshold identified by Kruijff et al. (2014). However, the performance difference between agents above and below the stress threshold is only 0.7 percentage points, indicating that the stress mechanism produces appropriate dynamics but its performance impact is negligible relative to the dominant reliability effect.

**Transparency Effect.** The model does not reproduce Chen et al.'s (2018) finding that transparency improves performance by 27%. The transparency mechanism (trust += transparency × 0.01 per communication event) is too weak relative to the direct reliability-success pathway. This represents a known model limitation (see Section 7.3).

### 5.2 Sensitivity Analysis

Sensitivity analysis was conducted through two complementary approaches: a factorial experiment crossing six parameters (576 unique combinations, ~27 replications per cell on average, 15,625 total runs at 1000 ticks each) and dedicated single-parameter sweeps for fine-grained characterization (15 levels for reliability, 50 replications each at 2000 ticks).

The factorial analysis reveals a strikingly simple result: robot reliability accounts for 87.7% of the variance in task success rate (η² = 0.877, F(2, 15612) = 55,695, p < 0.001). No other parameter reaches η² > 0.001 or exhibits a practically meaningful effect size. Collaboration rate achieves statistical significance (F(2, 15612) = 8.6, p < 0.001) due to the large sample size, but explains effectively zero variance.

**Table 2. Factorial ANOVA Results.**

| Parameter | df | SS | F | p | η² |
|---|---|---|---|---|---|
| Robot reliability | 2 | 1,849,139 | 55,695 | <0.001 | 0.877 |
| Collaboration rate | 2 | 286 | 8.6 | <0.001 | <0.001 |
| Robot autonomy | 3 | 83 | 1.7 | 0.171 | <0.001 |
| Robot transparency | 3 | 18 | 0.4 | 0.780 | <0.001 |
| Initial tasks | 1 | 14 | 0.8 | 0.362 | <0.001 |
| Comm. frequency | 1 | 8 | 0.5 | 0.491 | <0.001 |
| Residual | 15,612 | 259,168 | | | 0.123 |

The dedicated reliability sweep confirms and extends this finding with finer granularity across 15 levels (30–100% in 5-point increments). One-way ANOVA confirms the dominant effect (F(14, 735) = 492.6, p < 0.001, η² = 0.904). The reliability-performance relationship is linear (R² = 0.90), with no evidence of non-linearity: polynomial orders above 1 provide no improvement in AIC or adjusted R² (Table 3).

**Table 3. Polynomial Order Comparison (Reliability Sweep).**

| Order | AIC | Adj. R² | ΔAIC from best |
|---|---|---|---|
| 1 (linear) | 4222 | 0.902 | 0 (best) |
| 2 (quadratic) | 4223 | 0.902 | 1.1 |
| 3 (cubic) | 4224 | 0.902 | 1.8 |
| 6 (6th order) | 4226 | 0.902 | 3.9 |

Performance increases monotonically from 60.3% at reliability = 30 to 100% at reliability = 100, with no plateau, peak, or diminishing returns (Table 4). Trust closely tracks reliability through the Kalman-filter update (40.3 → 99.9), while stress remains invariant (~72) across all reliability levels.

**Table 4. Reliability Sweep Condition Means (n = 50 per level).**

| Reliability | Task Success M (SD) | Trust M | Stress M | Efficiency M |
|---|---|---|---|---|
| 30 | 60.3 (5.3) | 40.3 | 70.4 | 99.7 |
| 40 | 65.8 (5.1) | 51.4 | 71.5 | 98.0 |
| 50 | 70.5 (4.6) | 61.3 | 69.9 | 96.3 |
| 60 | 76.7 (4.8) | 73.5 | 72.3 | 98.3 |
| 70 | 83.1 (3.2) | 84.3 | 77.5 | 97.7 |
| 80 | 88.6 (2.7) | 93.0 | 73.4 | 95.7 |
| 90 | 93.9 (2.5) | 97.0 | 72.6 | 95.3 |
| 100 | 100.0 (0.0) | 99.9 | 71.8 | 100.0 |

### 5.3 Limitations of Current Assessment

The current calibration assessment does not include formal face validity evaluation by independent domain experts. This is acknowledged as a limitation. Future work should include structured expert review of model behavior by HRI researchers not involved in model development, following established protocols for simulation face validity (Sargent, 2013).

---

## 6. Results

### 6.1 Experimental Design

Model behavior was examined through three complementary experiments using the corrected Trustv5 implementation:

**Factorial experiment.** A 2 × 3 × 4 × 4 × 2 × 3 factorial design crossing six parameters (initial-tasks, robot-reliability, robot-autonomy, robot-transparency, robot-comm-frequency, collaboration-rate) produced 576 unique parameter combinations. BehaviorSpace generated approximately 27 replications per cell on average (15,625 total runs, 1000 ticks each, metrics recorded every 100 ticks). This design enables estimation of clean main effects and interactions.

**Reliability sweep.** A dedicated single-parameter experiment varied robot reliability from 30% to 100% in 5-percentage-point increments (15 levels × 50 replications = 750 runs, 2000 ticks each) while holding all other parameters at baseline values (3 humans, 3 robots, initial-trust = 50, robot-autonomy = 70, robot-transparency = 50, robot-comm-frequency = 50, collaboration-rate = 50). This provides fine-grained characterization of the reliability-performance relationship.

**Reliability × Transparency crossed experiment.** A 5 × 5 factorial crossing reliability (40, 55, 70, 85, 100) with transparency (10, 30, 50, 70, 90) at 50 replications per cell (1,250 total runs, 2000 ticks each) tests whether transparency moderates the reliability effect.

### 6.2 Linear Reliability Effect

Contrary to the initial hypothesis of a non-linear reliability-performance relationship, both the factorial experiment and the dedicated reliability sweep demonstrate a strong linear effect with no evidence of diminishing returns, plateaus, or over-reliance penalties.

The linear model (Performance ≈ 30.7 + 0.70 × Reliability) explains 90.2% of variance across 750 observations. Higher-order polynomials provide no improvement (ΔAIC < 4 for all orders; Table 3), indicating that the relationship is well-characterized as linear within the tested range (30–100%).

**Absence of over-reliance.** The hypothesized mechanism by which high reliability would reduce human engagement does not manifest in the model. Team efficiency remains consistently high (95–100%) across all reliability levels, indicating that humans maintain task engagement even when working with highly reliable robots. This occurs because the model's task allocation logic assigns agents to the nearest available task regardless of trust level — high trust does not trigger preferential delegation to robots in the current implementation.

**Trust-reliability coupling.** Trust closely tracks reliability (r > 0.99 across condition means), confirming that the Kalman-filter update mechanism produces appropriate convergence. At reliability = 30, mean trust stabilizes at 40.3; at reliability = 100, trust reaches 99.9. The trust update gain K = 0.01 produces complete convergence well within the 2000-tick simulation horizon.

**Stress independence.** Mean stress remains invariant across reliability levels (~72 on a 0–100 scale), confirming that the bounded stress dynamics depend on workload and task arrival patterns rather than robot performance characteristics.

### 6.3 Parameter Dominance and Null Effects

The factorial analysis reveals that reliability accounts for nearly all explainable variance in team performance (η² = 0.877). The remaining five parameters — transparency, autonomy, communication frequency, collaboration rate, and initial task load — collectively account for less than 0.1% of variance.

This dominance pattern has implications for both model interpretation and practical team design:

- **Transparency** (η² < 0.001, p = 0.78): The communication mechanism (trust += transparency × 0.01 per communication event) produces insufficient cumulative effect to differentiate performance across transparency levels within the simulation horizon.
- **Autonomy** (η² < 0.001, p = 0.17): While autonomy affects robots' willingness to attempt tasks beyond their capability, this mechanism does not translate into measurable performance differences, likely because capability differences are small relative to reliability effects.
- **Communication frequency** (η² < 0.001, p = 0.49): Communication events contribute marginal trust increments that are overwhelmed by the direct reliability-trust pathway.

A separate crossed experiment (5 reliability levels × 5 transparency levels, 50 replications per cell, 1,250 runs) confirms the absence of interaction effects. Transparency has no main effect (F(4, 1225) = 0.89, p = 0.468, η² < 0.001) and does not interact with reliability (F(16, 1225) = 0.92, p = 0.551, η² = 0.001). Cell means show task success rates that are effectively identical across transparency levels within each reliability condition (Table 5).

**Table 5. Reliability × Transparency Cell Means (Task Success %).**

| Reliability | Trans. 10 | Trans. 30 | Trans. 50 | Trans. 70 | Trans. 90 |
|---|---|---|---|---|---|
| 40 | 65.9 | 66.4 | 65.2 | 65.7 | 66.0 |
| 55 | 74.1 | 75.5 | 74.1 | 75.2 | 73.9 |
| 70 | 82.3 | 83.1 | 83.0 | 83.7 | 83.5 |
| 85 | 91.8 | 90.7 | 91.2 | 91.4 | 91.4 |
| 100 | 100.0 | 100.0 | 100.0 | 100.0 | 100.0 |

These null effects represent a limitation of the current model's mechanism design rather than a definitive finding about real human-robot teams, where transparency and communication are known to affect performance (Chen et al., 2018; Kunze et al., 2024). The implications for model development are discussed in Section 7.3.

---

## 7. Discussion

### 7.1 Theoretical Contributions

The findings advance understanding of human-robot team dynamics in three ways, while revealing important limitations of the current modeling approach.

**Reliability dominance.** The most striking finding is that robot reliability explains 88% of variance in team performance across a 576-cell factorial design, while all other parameters combined explain less than 0.1%. This suggests that in the current model architecture, the direct pathway from reliability to task success overwhelms indirect pathways through trust, communication, and stress. This finding is consistent with Hancock et al.'s (2011) meta-analytic conclusion that robot performance is the strongest predictor of trust (r = 0.71), but extends it by quantifying the dominance of reliability over other design parameters in a team performance context.

**Linear reliability-performance relationship.** Contrary to the hypothesis that performance would exhibit non-linear dynamics with an optimum below maximum reliability, the reliability sweep demonstrates a purely linear relationship (R² = 0.90) with no evidence of diminishing returns. The hypothesized over-reliance mechanism — in which high trust would reduce human engagement — does not emerge because the model's task allocation logic does not implement trust-dependent delegation. This absence is itself informative: it identifies trust-dependent task allocation as a necessary mechanism for over-reliance effects to manifest in future model iterations.

**Mechanism sensitivity.** The null effects for transparency, autonomy, and communication frequency indicate that these mechanisms, as currently implemented, are too weak to produce measurable performance effects. In the model, transparency contributes at most 0.01 × transparency_level per communication event — a cumulative effect that is orders of magnitude smaller than the direct reliability-success pathway. This suggests that future model iterations should strengthen these mechanisms or introduce pathways by which transparency and communication affect task allocation or error recovery directly.

### 7.2 Practical Implications

The current model's findings suggest that for team configurations matching the model's assumptions, maximizing robot reliability is the dominant design consideration. However, the practical implications should be interpreted cautiously given the model limitations discussed below.

**Reliability as the primary lever.** Within the model, every 10-percentage-point increase in reliability produces approximately a 7-percentage-point increase in task success rate. This linear relationship holds across the full tested range (30–100%) with no diminishing returns.

**Trust calibration is effective.** The Kalman-filter trust update produces appropriate convergence: trust stabilizes near the robot's actual reliability level within the simulation horizon. This suggests that steady-state trust calibration is achievable without explicit calibration interventions, at least when reliability is consistent.

**Stress is workload-driven, not reliability-driven.** Stress levels remain constant (~72) across all reliability levels, indicating that in the current model, stress management is a function of task arrival rate and workload distribution rather than robot performance.

### 7.3 Limitations

Several important limitations constrain the current work:

**Mechanism weakness for non-reliability parameters.** The most significant limitation is that transparency, autonomy, and communication frequency have negligible effects on performance. This likely reflects insufficient mechanism strength rather than genuine theoretical irrelevance. In the current implementation, transparency adds at most 1.0 trust points per communication event (transparency=100 × 0.01), while a single robot failure subtracts 5 trust points. These magnitudes make the communication pathway inconsequential relative to the direct performance observation pathway. Future iterations should implement stronger transparency mechanisms — for example, transparency could affect task allocation decisions, error interpretation, or workload distribution rather than only contributing additive trust increments.

**No trust-dependent task allocation.** The model assigns agents to the nearest available task regardless of trust level. This means the hypothesized over-reliance pathway (high trust → excessive delegation → reduced human engagement) cannot manifest. Implementing trust-weighted task allocation is the highest-priority extension for exploring non-linear reliability effects.

**Calibration vs. validation.** All empirical comparisons involve data used during parameter tuning. The model has not been tested against independent experimental data.

**Fixed agent capabilities.** Human agents do not learn or adapt their strategies over time.

**Simplified communication.** Robot communication is binary (communicate or not) rather than multimodal.

**Stress invariance to reliability.** The stress dynamics depend only on workload, which does not vary with reliability in the current task generation scheme. In real teams, robot failures may generate additional cognitive load and stress beyond the direct workload effect.

**No formal face validity.** The model has not undergone structured expert review by independent HRI researchers.

**Simulation horizon.** The factorial experiment ran to 1000 ticks while the sweep experiments ran to 2000 ticks. Some mechanisms may require longer horizons to differentiate.

### 7.4 Future Work

The most immediate priority is implementing trust-dependent task allocation, in which human agents preferentially delegate to robots when trust is high and retain tasks when trust is low. This mechanism is necessary for over-reliance effects to emerge and would test whether non-linear reliability-performance relationships appear when delegation dynamics are present.

Second, strengthening the transparency and communication mechanisms so they affect task allocation, error interpretation, or workload distribution — not just trust level — would allow the model to explore the interaction effects documented in the empirical literature (Chen et al., 2018; Kunze et al., 2024).

Third, out-of-sample validation against independent experimental data remains essential. The calibration targets (Hancock et al., 2011; Desai et al., 2013; Kruijff et al., 2014) were used to set parameters; testing predictions against held-out data would establish predictive validity.

Additional directions include incorporating agent learning, extending to larger teams, implementing variable reliability (rather than fixed), and introducing task dependencies and priority structures.

---

## 8. Conclusion

This paper presents an agent-based framework, calibrated against published experimental findings, for exploring trust dynamics and performance in human-robot teams. A 576-cell factorial experiment and dedicated parameter sweeps reveal that robot reliability dominates team performance (η² = 0.88) with a linear relationship (R² = 0.90, no diminishing returns), while transparency, autonomy, and communication frequency have negligible effects in the current implementation.

These results yield two classes of contribution. First, the positive finding: reliability's dominance and trust's effective calibration via the Kalman-filter mechanism provide a validated baseline for team performance prediction. Second, the null findings for transparency and communication identify specific mechanism weaknesses that guide future model development — particularly the need for trust-dependent task allocation and stronger transparency pathways.

The open-source implementation enables community extension and, most importantly, provides a concrete framework against which future experimental validation efforts can be organized.

---

## Declaration of Generative AI and AI-Assisted Technologies in the Writing Process

During the preparation of this work, the author used a generative AI tool to improve grammar and writing style. After using this tool, the author reviewed and edited the content as needed and takes full responsibility for the content of the publication.

## Funding

This study did not receive any funding.

## Compliance with Ethical Standards

**Conflict of interest.** The author declares no conflict of interest.

## Availability of Data

The agent-based model, simulation data, and statistical analysis scripts are available at https://github.com/rkallur2/trust_calib under a Creative Commons license.

---

## References

Chen, J. Y., Lakhmani, S. G., Stowers, K., Selkowitz, A. R., Wright, J. L., & Barnes, M. (2018). Situation awareness-based agent transparency and human-autonomy teaming effectiveness. *Theoretical Issues in Ergonomics Science*, 19(3), 259–282.

Dehais, F., Sisbot, E. A., Alami, R., & Causse, M. (2011). Physiological and subjective evaluation of a human–robot object hand-over task. *Applied Ergonomics*, 42(6), 785–791.

Desai, M., Kaniarasu, P., Medvedev, M., Steinfeld, A., & Yanco, H. (2013). Impact of robot failures and feedback on real-time trust. In *Proceedings of the 8th ACM/IEEE International Conference on Human-Robot Interaction* (pp. 251–258).

Hancock, P. A., Billings, D. R., Schaefer, K. E., Chen, J. Y., De Visser, E. J., & Parasuraman, R. (2011). A meta-analysis of factors affecting trust in human-robot interaction. *Human Factors*, 53(5), 517–527.

Huang, C. M., & Mutlu, B. (2024). Quantum-inspired modeling of human decision-making in human-robot interaction. *Nature Human Behaviour*, 8(3), 412–425.

Kruijff, G. J. M., Kruijff-Korbayová, I., Keshavdas, S., Larochelle, B., Janíček, M., Colas, F., ... & Grewe, P. (2014). Designing, developing, and deploying systems to support human–robot teams in disaster response. *Advanced Robotics*, 28(23), 1547–1570.

Kunze, A., Summerskill, S. J., Marshall, R., & Filtness, A. J. (2024). Adaptive transparency in human-robot teaming: Real-time cognitive load-based adjustments. *ACM Transactions on Interactive Intelligent Systems*, 14(1), 1–32.

Lee, J. D., & See, K. A. (2004). Trust in automation: Designing for appropriate reliance. *Human Factors*, 46(1), 50–80.

Lewis, M., Sycara, K., & Walker, P. (2018). The role of trust in human-robot interaction. In *Foundations of Trusted Autonomy* (pp. 135–159). Springer.

Salem, M., Lakatos, G., Amirabdollahian, F., & Dautenhahn, K. (2015). Would you trust a (faulty) robot? Effects of error, task type and personality on human-robot cooperation and trust. In *Proceedings of the 10th ACM/IEEE International Conference on Human-Robot Interaction* (pp. 141–148).

Sargent, R. G. (2013). Verification and validation of simulation models. *Journal of Simulation*, 7(1), 12–24.

Shah, J., Wiken, J., Williams, B., & Breazeal, C. (2011). Improved human-robot team performance using chaski, a human-inspired plan execution system. In *Proceedings of the 6th ACM/IEEE International Conference on Human-Robot Interaction* (pp. 29–36).

Tower, D. C., & Brooks, C. (2024). Proactive failure acknowledgment as a trust preservation strategy in human-robot teams. *Journal of Experimental Psychology: Applied*, 30(1), 78–92.

---

## APPENDIX A: Mathematical Framework

### A.1 Notation and Definitions

**Table A1: Mathematical Notation**

| Symbol | Domain | Description |
|---|---|---|
| **Agents** | | |
| H = {h₁, ..., hₘ} | Set | Human agents |
| R = {r₁, ..., rₙ} | Set | Robot agents |
| **State Variables** | | |
| θᵢ(t) | [0, 100] | Trust level of human i at time t |
| εᵢ(t) | [50, 99] | Expertise of human i (fixed at initialization) |
| σᵢ(t) | [0, 100] | Stress level of human i |
| wᵢ(t) | ℝ⁺ | Workload of agent i |
| ρⱼ | [0, 100] | Reliability of robot j |
| τⱼ | [0, 100] | Transparency of robot j |
| ψⱼ | [60, 99] | Capability of robot j |
| **Tasks** | | |
| T(t) | Set | Available tasks at time t |
| dₖ | [10, 99] | Difficulty of task k |
| χₖ | {0, 1} | Collaboration requirement |
| **Parameters** | | |
| K | 0.01 | Trust learning rate (constant gain) |
| γ | 0.1 | Stress accumulation rate |
| δ | 0.5 | Stress decay rate |

### A.2 Trust Update: Relationship to Kalman Filtering

The implemented trust update uses a constant-gain formulation:

$$\theta_{i}(t + 1) = \theta_{i}(t) + K[\rho_{\text{observed}} - \theta_{i}(t)]$$

This can be understood as a special case of the Kalman filter where the gain has converged to a steady-state value. The full Kalman filter formulation, from which the simplification derives, involves time-varying gain computed from prediction and observation covariances:

**State prediction:** $\hat{\theta}_{i}(t | t-1) = \theta_{i}(t-1)$

**Prediction covariance:** $P_{i}(t | t-1) = P_{i}(t-1 | t-1) + Q$

**Kalman gain:** $K_{i}(t) = P_{i}(t | t-1) / [P_{i}(t | t-1) + R]$

**State update:** $\theta_{i}(t | t) = \hat{\theta}_{i}(t | t-1) + K_{i}(t)[y_{i}(t) - \hat{\theta}_{i}(t | t-1)]$

**Covariance update:** $P_{i}(t | t) = [1 - K_{i}(t)] P_{i}(t | t-1)$

In the steady state, $K_{i}(t)$ converges to a constant determined by the ratio Q/R. The implemented model uses the constant-gain simplification directly, with K = 0.01 selected through calibration.

**Observation Model:**

$$y_{i}(t) = \frac{\sum_{r_{j} \in \mathcal{N}_{i}(t)} [\rho_{j} \cdot \mathbb{1}_{\text{success}}(r_{j},t) + \tau_{j} \cdot c_{ij}(t)]}{|\mathcal{N}_{i}(t)|}$$

### A.3 Stress Dynamics Derivation

Starting from the continuous model:

$$\frac{d\sigma}{dt} = \gamma w(t)[1 - \sigma(t)] - \delta \sigma(t)$$

Discretization using Euler method (Δt = 1):

$$\sigma(t + 1) = \sigma(t) + \gamma w(t)[1 - \sigma(t)] - \delta \sigma(t)$$

Steady-state analysis (dσ/dt = 0):

$$\sigma^{*} = \frac{\gamma w}{\gamma w + \delta}$$

### A.4 Coalition Formation

For collaborative tasks, optimal coalition:

$$C^{*} = \arg\max_{C \subseteq (H \cup R)} U(C, \tau_{k})$$

Utility function:

$$U(C, \tau_{k}) = \sum_{i \in C} \text{capable}(i, \tau_{k}) - \lambda \sum_{i,j \in C, i \neq j} d(i,j)$$

### A.5 Information Theory

Communication value:

$$I(\theta; c) = H(\theta) - H(\theta | c)$$

Team coordination entropy:

$$H(C) = -\sum_{C \in \mathcal{P}(H \cup R)} P(C) \log P(C)$$

---

## APPENDIX B: NetLogo Implementation

### B.1 ODD Protocol Documentation

**Overview.** Purpose: simulate trust and performance dynamics in human-robot teams. Entities: humans (turtles), robots (turtles), tasks (patches). State variables: see Table A1. Scales: spatial, 33 × 33 grid; temporal, 1 tick = 1 minute.

**Design Concepts.** Basic principles: trust-based task allocation with stress moderation. Emergence: team-level performance arises from individual agent interactions without top-down coordination. Adaptation: trust updates based on local observations of robot performance. Objectives: agents seek to complete available tasks; no explicit optimization by individual agents. Learning: constant-gain Kalman filter trust updates (see Section 3.2 and Appendix A.2). Prediction: human agents implicitly predict robot reliability through their trust state. Sensing: local observation within radius 10. Interaction: direct (collaborative tasks) and indirect (through shared task environment). Stochasticity: task difficulty U(10, 99), task duration U(50, 199), initial positions (uniform random), collaboration requirement Bernoulli(collaboration-rate/100), task replenishment every 50 ticks when count drops below initial-tasks. Collectives: ad hoc teams form for collaborative tasks via coalition formation. Observation: all state variables recorded.

### B.2 Core Procedures (Pseudocode)

```
to setup
  clear-all
  create-humans num-humans [
    set trust-in-robots initial-trust
    set expertise 50 + random 50      ;; U(50, 99)
    set stress-level random 30         ;; U(0, 29)
    set color blue
    setxy random-xcor random-ycor
  ]
  create-robots num-robots [
    set reliability robot-reliability
    set transparency robot-transparency
    set autonomy-level robot-autonomy
    set capability 60 + random 40      ;; U(60, 99)
    set battery-level 100
    set color red
    setxy random-xcor random-ycor
  ]
  create-tasks initial-tasks           ;; batch generation
  reset-ticks
end

to go
  update-states
  assign-tasks
  execute-tasks
  handle-collaboration
  communicate
  update-trust
  complete-tasks
  calculate-metrics
  ;; Replenish tasks every 50 ticks if count < initial-tasks
  if ticks mod 50 = 0 and count tasks < initial-tasks [
    generate-tasks
  ]
  tick
end

to update-trust  ;; Kalman-filter-inspired convergence
  ask humans [
    let observed-performance mean [reliability] of nearby-robots
    let K 0.01  ;; constant gain
    set trust-in-robots trust-in-robots +
      K * (observed-performance - trust-in-robots)
  ]
end

to update-stress  ;; Bounded growth with proportional decay
  ask humans [
    let gamma 0.1
    let delta 0.5
    let sigma-norm stress-level / 100
    let growth gamma * workload * (1 - sigma-norm)
    let decay delta * sigma-norm
    set stress-level stress-level + (growth - decay) * 100
    set stress-level max 0 min 100 stress-level
  ]
end

to complete-task  ;; Difficulty-dependent success
  if agent is human [
    success-probability = min(100, expertise / difficulty * 100)
  ]
  if agent is robot [
    success-probability = reliability
  ]
  ;; Trust asymmetry: +1 on success, -5 on failure
end
```

### B.3 Parameter Settings

```xml
<?xml version="1.0" encoding="UTF-8"?>
<parameters>
  <experiment name="baseline">
    <param name="num-humans" value="3"/>
    <param name="num-robots" value="3"/>
    <param name="initial-trust" value="50"/>
    <param name="robot-reliability" value="90"/>
    <param name="robot-transparency" value="50"/>
    <param name="robot-autonomy" value="70"/>
    <param name="collaboration-rate" value="50"/>
    <param name="max-ticks" value="2000"/>
  </experiment>
</parameters>
```

---

## APPENDIX C: Calibration Assessment

### C.1 Calibration Verification

The corrected model (Trustv5) was assessed against the original calibration targets. Because the model equations were substantially revised during development — including the trust update mechanism, stress dynamics, and task success probability — recalibration was necessary. Three of the five original targets could be evaluated; two require model extensions not present in the current implementation.

**Table C1: Calibration Assessment Results.**

| Target Study | Metric | Published Finding | Trustv5 Result | Assessment |
|---|---|---|---|---|
| Hancock et al. (2011) | Trust trajectory | Exponential convergence | R² = 0.998 (exponential fit, asymptote = 96.7) | **Pass.** Kalman-filter trust update produces exponential convergence by design. |
| Desai et al. (2013) | Trust recovery after failure | 23% improvement | Not testable | **Requires extension.** Current model uses fixed reliability; trust recovery from transient failures requires variable-reliability implementation. |
| Salem et al. (2015) | Trust drop from inconsistency | d = 1.24 | d = 5.6 (reliability 90 vs 40) | **Not comparable.** Model tests reliability level differences, not behavioral inconsistency within a single robot. |
| Chen et al. (2018) | Transparency effect | 27% improvement | 0% improvement (η² < 0.001) | **Fails.** Transparency mechanism is too weak to produce measurable performance effects (see Section 6.3). |
| Kruijff et al. (2014) | Stress threshold | ~70% | Threshold coded at 70; mean stress = 69.2; performance difference above/below threshold = 0.7 percentage points | **Partially met.** The stress threshold exists at the correct value, but its performance impact is negligible relative to the dominant reliability effect. |

### C.2 Interpretation

The corrected model achieves strong calibration for trust dynamics (Hancock target), confirming that the Kalman-filter mechanism produces appropriate convergence behavior. However, the model does not achieve calibration for transparency effects (Chen) or behavioral inconsistency (Salem), reflecting mechanism limitations identified in Section 6.3.

The failure to calibrate against Chen et al. (2018) is a direct consequence of the transparency mechanism's weakness: transparency contributes at most 1.0 trust points per communication event, while the reliability-trust pathway dominates all trust dynamics. Achieving this calibration target would require strengthening the transparency mechanism to directly affect task allocation or error interpretation, as discussed in Section 7.4.

The stress threshold (Kruijff) is implemented at the correct physiological transition point (70 on a 0–100 scale), but its performance impact is masked by the overwhelming reliability effect. In operational environments where reliability is held constant (as in Kruijff et al.'s search-and-rescue context), the stress threshold would likely produce larger performance effects.
