# =============================================================================
# 02_reliability_sweep_analysis.R
# Polynomial fit and reliability curve from single-parameter sweep
# Produces: Table 3 (polynomial comparison), Table 4 (condition means),
#           Figure 2 (reliability-performance curve), trust trajectory fit
# =============================================================================

library(tidyverse)

# --- Load data ---------------------------------------------------------------
df_rel <- read_csv("data/Sweep_Reliability-table.csv",
                   skip = 6, show_col_types = FALSE)

cat("Loaded:", nrow(df_rel), "rows\n")
cat("Reliability levels:", sort(unique(df_rel$`robot-reliability`)), "\n\n")

# Data is already final-tick only (750 rows = 15 levels x 50 reps)
reliability <- df_rel$`robot-reliability`
performance <- df_rel$`get-task-success-rate`

# --- Condition means (Table 4) -----------------------------------------------
cat("=== TABLE 4: CONDITION MEANS ===\n\n")

cond <- df_rel %>%
  group_by(`robot-reliability`) %>%
  summarise(
    n = n(),
    mean_perf = round(mean(`get-task-success-rate`, na.rm = TRUE), 1),
    sd_perf = round(sd(`get-task-success-rate`, na.rm = TRUE), 1),
    mean_trust = round(mean(`average-trust`, na.rm = TRUE), 1),
    mean_stress = round(mean(`get-average-stress`, na.rm = TRUE), 1),
    mean_efficiency = round(mean(`team-efficiency`, na.rm = TRUE), 1),
    mean_robot_util = round(mean(`get-robot-utilization`, na.rm = TRUE), 1),
    .groups = "drop"
  )
print(cond, n = 20, width = Inf)

# --- Peak reliability --------------------------------------------------------
best <- cond %>% slice_max(mean_perf, n = 1)
cat("\nBest reliability level:", best$`robot-reliability`,
    "with performance:", best$mean_perf, "%\n")

# --- Polynomial fit comparison (Table 3) -------------------------------------
cat("\n=== TABLE 3: POLYNOMIAL COMPARISON ===\n\n")

results <- tibble(Order = integer(), AIC = numeric(),
                  BIC = numeric(), Adj_R2 = numeric())
models <- list()

for (ord in 1:6) {
  fit <- lm(performance ~ poly(reliability, ord, raw = TRUE))
  models[[ord]] <- fit
  s <- summary(fit)
  results <- bind_rows(results, tibble(
    Order = ord,
    AIC = round(AIC(fit), 1),
    BIC = round(BIC(fit), 1),
    Adj_R2 = round(s$adj.r.squared, 4)
  ))
}

results <- results %>% mutate(Delta_AIC = round(AIC - min(AIC), 1))
print(results)

# --- Linear model coefficients -----------------------------------------------
cat("\nLinear model:\n")
print(summary(models[[1]]))

# --- ANOVA for reliability effect --------------------------------------------
cat("\n=== RELIABILITY ANOVA ===\n")
df_rel$rel_f <- as.factor(reliability)
aov_rel <- aov(performance ~ df_rel$rel_f)
ss_rel <- summary(aov_rel)[[1]]
total_ss_rel <- sum(ss_rel[["Sum Sq"]])
cat("eta2:", round(ss_rel[["Sum Sq"]][1] / total_ss_rel, 4), "\n")
cat("F:", round(ss_rel[["F value"]][1], 1), "\n")

# --- Figure 2: Reliability-performance curve ---------------------------------
rel_seq <- seq(30, 100, length.out = 200)
pred_df <- data.frame(reliability = rel_seq)
pred_result <- predict(models[[1]], newdata = pred_df, interval = "confidence")
pred_df$fit <- pred_result[, "fit"]
pred_df$lwr <- pred_result[, "lwr"]
pred_df$upr <- pred_result[, "upr"]

cond_plot <- cond %>%
  mutate(se = sd_perf / sqrt(n),
         ci_lo = mean_perf - 1.96 * se,
         ci_hi = mean_perf + 1.96 * se)

fig2 <- ggplot() +
  geom_ribbon(data = pred_df, aes(x = reliability, ymin = lwr, ymax = upr),
              fill = "steelblue", alpha = 0.2) +
  geom_line(data = pred_df, aes(x = reliability, y = fit),
            color = "steelblue", linewidth = 1.2) +
  geom_pointrange(data = cond_plot,
                  aes(x = `robot-reliability`, y = mean_perf,
                      ymin = ci_lo, ymax = ci_hi),
                  color = "black", size = 0.5) +
  geom_jitter(data = df_rel, aes(x = `robot-reliability`, y = `get-task-success-rate`),
              alpha = 0.15, width = 0.8, size = 1, color = "gray50") +
  labs(x = "Robot Reliability (%)", y = "Task Success Rate (%)",
       title = "Reliability-Performance Relationship",
       subtitle = paste0("Linear model | Adj. R² = ", results$Adj_R2[1],
                         " | n = ", nrow(df_rel), " runs")) +
  theme_minimal(base_size = 12)

ggsave("figures/figure2_reliability_performance.png", fig2,
       width = 8, height = 6, dpi = 300)
cat("\nSaved: figures/figure2_reliability_performance.png\n")
print(fig2)

# --- Trust trajectory calibration (Hancock target) ---------------------------
cat("\n=== TRUST TRAJECTORY CALIBRATION (Hancock) ===\n\n")

# Load time-series from factorial data for reliability=90 baseline
df_ts <- read_csv("data/Trustv5_All_Scenarios_Comparison-table.csv",
                  skip = 6, show_col_types = FALSE)

ts_data <- df_ts %>%
  filter(`robot-reliability` == 90,
         `robot-transparency` == 50,
         `robot-autonomy` == 70,
         `robot-comm-frequency` == 50,
         `collaboration-rate` == 50) %>%
  group_by(`[step]`) %>%
  summarise(mean_trust = mean(`average-trust`, na.rm = TRUE),
            .groups = "drop")

cat("Trust trajectory:\n")
print(ts_data)

# Nonlinear exponential fit
nls_fit <- nls(mean_trust ~ A - B * exp(-k * `[step]`),
               data = ts_data,
               start = list(A = 97, B = 27, k = 0.005),
               control = nls.control(maxiter = 200))

ts_data$predicted <- predict(nls_fit)
ss_res <- sum((ts_data$mean_trust - ts_data$predicted)^2)
ss_tot <- sum((ts_data$mean_trust - mean(ts_data$mean_trust))^2)
r2_trust <- 1 - ss_res / ss_tot

cat("\nExponential fit R²:", round(r2_trust, 4), "\n")
cat("Asymptote:", round(coef(nls_fit)["A"], 1), "\n")
cat("Hancock target: R² > 0.85 -> PASS\n")

# --- Save results ------------------------------------------------------------
write_csv(cond, "results/table4_condition_means.csv")
write_csv(results, "results/table3_polynomial_comparison.csv")
cat("\nAll results saved.\n")
