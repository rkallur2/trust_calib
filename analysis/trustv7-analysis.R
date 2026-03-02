# =============================================================================
# Trustv7_analysis.R — Revised analysis for paper
# Three experiments: Reliability Sweep, Rel × Transparency, Trust Trajectory
# Uses read.csv with check.names = FALSE for proper column names
# Uses file.choose() for file selection
# =============================================================================

library(tidyverse)
library(svglite)

# =============================================================================
# 1. RELIABILITY SWEEP
# =============================================================================

cat("\n", strrep("=", 60), "\n")
cat("1. RELIABILITY SWEEP\n")
cat(strrep("=", 60), "\n\n")

cat("Select the Reliability Sweep CSV file...\n")
df_rel <- read.csv(file.choose(), skip = 6, header = TRUE, check.names = FALSE)
cat("Rows:", nrow(df_rel), "| Cols:", ncol(df_rel), "\n\n")

# Condition means
cond_rel <- df_rel %>%
  group_by(`robot-reliability`) %>%
  summarise(
    n = n(),
    perf = round(mean(`get-task-success-rate`, na.rm = TRUE), 1),
    perf_sd = round(sd(`get-task-success-rate`, na.rm = TRUE), 1),
    trust = round(mean(`average-trust`, na.rm = TRUE), 1),
    stress = round(mean(`get-average-stress`, na.rm = TRUE), 1),
    deleg = round(mean(`get-delegation-rate`, na.rm = TRUE), 1),
    idle = round(mean(`get-human-idle-rate`, na.rm = TRUE), 1),
    misalloc = round(mean(`get-misallocation-rate`, na.rm = TRUE), 1),
    judg_fail = round(mean(`get-judgment-failure-rate`, na.rm = TRUE), 1),
    kalman = round(mean(`get-mean-kalman-gain`, na.rm = TRUE), 4),
    .groups = "drop"
  )

cat("=== CONDITION MEANS ===\n")
print(cond_rel, n = 20, width = Inf)

best_rel <- cond_rel[which.max(cond_rel$perf), ]
cat("\nPeak reliability:", best_rel$`robot-reliability`,
    "| Performance:", best_rel$perf, "%\n")
cat("Non-linear?", ifelse(best_rel$`robot-reliability` < 100, "YES", "NO"), "\n")

# Polynomial comparison
cat("\n=== POLYNOMIAL COMPARISON ===\n")
rel <- df_rel$`robot-reliability`
perf <- df_rel$`get-task-success-rate`

poly_results <- data.frame(Order = integer(), AIC = numeric(),
                           Adj_R2 = numeric(), stringsAsFactors = FALSE)
poly_models <- list()

for (ord in 1:6) {
  fit <- lm(perf ~ poly(rel, ord, raw = TRUE))
  poly_models[[ord]] <- fit
  s <- summary(fit)
  poly_results <- rbind(poly_results, data.frame(
    Order = ord,
    AIC = round(AIC(fit), 1),
    Adj_R2 = round(s$adj.r.squared, 4)
  ))
}
poly_results$Delta_AIC <- round(poly_results$AIC - min(poly_results$AIC), 1)
print(poly_results)

best_poly <- poly_results[poly_results$AIC <= min(poly_results$AIC) + 2, ]
best_poly <- best_poly[which.min(best_poly$Order), ]
cat("\nBest parsimonious model: Order", best_poly$Order,
    "| AIC:", best_poly$AIC, "| Adj R²:", best_poly$Adj_R2, "\n")

# ANOVA
cat("\n=== RELIABILITY ANOVA ===\n")
df_rel$rel_f <- as.factor(df_rel$`robot-reliability`)
aov_rel <- aov(perf ~ df_rel$rel_f)
ss_rel <- summary(aov_rel)[[1]]
eta_rel <- round(ss_rel[["Sum Sq"]][1] / sum(ss_rel[["Sum Sq"]]), 4)
cat("eta²:", eta_rel, "| F:", round(ss_rel[["F value"]][1], 1), "\n")

# Misallocation pattern
cat("\n=== MISALLOCATION PATTERN ===\n")
misalloc_data <- df_rel %>%
  group_by(`robot-reliability`) %>%
  summarise(
    deleg = round(mean(`get-delegation-rate`, na.rm = TRUE), 1),
    misalloc = round(mean(`get-misallocation-rate`, na.rm = TRUE), 1),
    judg_fail = round(mean(`get-judgment-failure-rate`, na.rm = TRUE), 1),
    idle = round(mean(`get-human-idle-rate`, na.rm = TRUE), 1),
    .groups = "drop"
  )
print(misalloc_data, n = 20, width = Inf)

# Figure 1: Reliability-Performance with delegation (PNG + SVG)
fig1 <- ggplot(cond_rel, aes(x = `robot-reliability`)) +
  geom_line(aes(y = perf, color = "Task Success"), linewidth = 1.3) +
  geom_point(aes(y = perf), color = "#2166AC", size = 3) +
  geom_errorbar(aes(ymin = perf - 1.96 * perf_sd / sqrt(n),
                    ymax = perf + 1.96 * perf_sd / sqrt(n)),
                color = "#2166AC", width = 1.5) +
  geom_line(aes(y = trust, color = "Trust"), linewidth = 1.2, linetype = "dashed") +
  geom_point(aes(y = trust), color = "#B2182B", size = 2.5) +
  geom_line(aes(y = deleg, color = "Delegation Rate"), linewidth = 1, linetype = "dotdash") +
  geom_line(aes(y = misalloc, color = "Misallocation Rate"), linewidth = 1, linetype = "dotted") +
  scale_color_manual(values = c("Task Success" = "#2166AC", "Trust" = "#B2182B",
                                "Delegation Rate" = "#FF7F00",
                                "Misallocation Rate" = "#E31A1C")) +
  scale_x_continuous(breaks = seq(30, 100, by = 10)) +
  labs(x = "Robot Reliability (%)", y = "Value (0-100 scale)", color = NULL,
       title = "Effect of Robot Reliability on Team Dynamics (Trustv7)",
       subtitle = "Over-reliance: performance plateaus as judgment tasks are misallocated") +
  theme_minimal(base_size = 13) +
  theme(legend.position = c(0.3, 0.82),
        legend.background = element_rect(fill = "white", color = "gray80"))
print(fig1)
ggsave("Fig1_reliability_v7.png", fig1, width = 9, height = 6.5, dpi = 300)
ggsave("Fig1_reliability_v7.svg", fig1, width = 9, height = 6.5, device = "svg")
cat("Saved: Fig1_reliability_v7.png + .svg\n")

# =============================================================================
# 2. RELIABILITY × TRANSPARENCY INTERACTION
# =============================================================================

cat("\n", strrep("=", 60), "\n")
cat("2. RELIABILITY × TRANSPARENCY\n")
cat(strrep("=", 60), "\n\n")

cat("Select the Reliability × Transparency CSV file...\n")
df_rxt <- read.csv(file.choose(), skip = 6, header = TRUE, check.names = FALSE)
cat("Rows:", nrow(df_rxt), "\n\n")

# Two-way ANOVA: Performance
df_rxt$rel_f <- as.factor(df_rxt$`robot-reliability`)
df_rxt$trans_f <- as.factor(df_rxt$`robot-transparency`)
perf_rxt <- df_rxt$`get-task-success-rate`

aov_rxt <- aov(perf_rxt ~ rel_f * trans_f, data = df_rxt)
ss_rxt <- summary(aov_rxt)[[1]]
total_ss_rxt <- sum(ss_rxt[["Sum Sq"]])

cat("=== TWO-WAY ANOVA: PERFORMANCE ===\n")
for (i in 1:nrow(ss_rxt)) {
  p_val <- ss_rxt[["Pr(>F)"]][i]
  p_str <- ifelse(is.na(p_val), "", ifelse(p_val < 0.001, "<0.001", round(p_val, 4)))
  cat(sprintf("%-20s eta2 = %.4f   F = %7.1f   p = %s\n",
              rownames(ss_rxt)[i],
              ss_rxt[["Sum Sq"]][i] / total_ss_rxt,
              ifelse(is.na(ss_rxt[["F value"]][i]), 0, ss_rxt[["F value"]][i]),
              p_str))
}

# Two-way ANOVA: Misallocation
cat("\n=== TWO-WAY ANOVA: MISALLOCATION ===\n")
aov_misalloc <- aov(`get-misallocation-rate` ~ rel_f * trans_f, data = df_rxt)
ss_misalloc <- summary(aov_misalloc)[[1]]
total_ss_misalloc <- sum(ss_misalloc[["Sum Sq"]])

for (i in 1:nrow(ss_misalloc)) {
  p_val <- ss_misalloc[["Pr(>F)"]][i]
  p_str <- ifelse(is.na(p_val), "", ifelse(p_val < 0.001, "<0.001", round(p_val, 4)))
  cat(sprintf("%-20s eta2 = %.4f   F = %7.1f   p = %s\n",
              rownames(ss_misalloc)[i],
              ss_misalloc[["Sum Sq"]][i] / total_ss_misalloc,
              ifelse(is.na(ss_misalloc[["F value"]][i]), 0, ss_misalloc[["F value"]][i]),
              p_str))
}

# Performance cell means
cat("\n=== CELL MEANS (Task Success %) ===\n")
cell_perf <- df_rxt %>%
  group_by(`robot-reliability`, `robot-transparency`) %>%
  summarise(perf = round(mean(`get-task-success-rate`, na.rm = TRUE), 1),
            .groups = "drop") %>%
  pivot_wider(names_from = `robot-transparency`, values_from = perf, names_prefix = "T")
print(cell_perf, width = Inf)

# Misallocation cell means
cat("\n=== CELL MEANS (Misallocation Rate %) ===\n")
cell_misalloc <- df_rxt %>%
  group_by(`robot-reliability`, `robot-transparency`) %>%
  summarise(misalloc = round(mean(`get-misallocation-rate`, na.rm = TRUE), 1),
            .groups = "drop") %>%
  pivot_wider(names_from = `robot-transparency`, values_from = misalloc, names_prefix = "T")
print(cell_misalloc, width = Inf)

# Figure 2: Performance interaction (lines overlap — null effect)
int_summary <- df_rxt %>%
  group_by(`robot-reliability`, `robot-transparency`) %>%
  summarise(mean_perf = mean(`get-task-success-rate`, na.rm = TRUE),
            se = sd(`get-task-success-rate`, na.rm = TRUE) / sqrt(n()),
            .groups = "drop")

fig2 <- ggplot(int_summary,
               aes(x = `robot-reliability`, y = mean_perf,
                   color = as.factor(`robot-transparency`),
                   group = as.factor(`robot-transparency`))) +
  geom_line(linewidth = 1.1) +
  geom_point(size = 3) +
  geom_errorbar(aes(ymin = mean_perf - 1.96 * se,
                    ymax = mean_perf + 1.96 * se), width = 2) +
  labs(x = "Robot Reliability (%)", y = "Task Success Rate (%)",
       color = "Transparency (%)",
       title = "Reliability × Transparency: Task Success Rate",
       subtitle = "Transparency has no effect on aggregate performance (η² < 0.001)") +
  theme_minimal(base_size = 12) +
  theme(legend.position = "bottom")
print(fig2)
ggsave("Fig2_rel_x_trans_perf.png", fig2, width = 8, height = 6, dpi = 300)
ggsave("Fig2_rel_x_trans_perf.svg", fig2, width = 8, height = 6, device = "svg")
cat("Saved: Fig2_rel_x_trans_perf.png + .svg\n")

# Figure 3: Misallocation interaction (lines separate — transparency effect)
int_misalloc <- df_rxt %>%
  group_by(`robot-reliability`, `robot-transparency`) %>%
  summarise(mean_misalloc = mean(`get-misallocation-rate`, na.rm = TRUE),
            se = sd(`get-misallocation-rate`, na.rm = TRUE) / sqrt(n()),
            .groups = "drop")

fig3 <- ggplot(int_misalloc,
               aes(x = `robot-reliability`, y = mean_misalloc,
                   color = as.factor(`robot-transparency`),
                   group = as.factor(`robot-transparency`))) +
  geom_line(linewidth = 1.1) +
  geom_point(size = 3) +
  geom_errorbar(aes(ymin = mean_misalloc - 1.96 * se,
                    ymax = mean_misalloc + 1.96 * se), width = 2) +
  labs(x = "Robot Reliability (%)", y = "Misallocation Rate (%)",
       color = "Transparency (%)",
       title = "Reliability × Transparency: Misallocation Rate",
       subtitle = "Transparency reduces misallocation despite no effect on performance (η² = 0.090)") +
  theme_minimal(base_size = 12) +
  theme(legend.position = "bottom")
print(fig3)
ggsave("Fig3_misallocation_interaction.png", fig3, width = 8, height = 6, dpi = 300)
ggsave("Fig3_misallocation_interaction.svg", fig3, width = 8, height = 6, device = "svg")
cat("Saved: Fig3_misallocation_interaction.png + .svg\n")

# =============================================================================
# 3. TRUST TRAJECTORY (Hancock calibration)
# =============================================================================

cat("\n", strrep("=", 60), "\n")
cat("3. TRUST TRAJECTORY\n")
cat(strrep("=", 60), "\n\n")

cat("Select the TimeSeries Baseline CSV file...\n")
tryCatch({
  df_ts <- read.csv(file.choose(), skip = 6, header = TRUE, check.names = FALSE)
  cat("Rows:", nrow(df_ts), "\n\n")
  
  ts_data <- df_ts %>%
    group_by(`[step]`) %>%
    summarise(
      mean_trust = mean(`average-trust`, na.rm = TRUE),
      sd_trust = sd(`average-trust`, na.rm = TRUE),
      .groups = "drop"
    )
  
  step_col <- names(ts_data)[1]
  cat("Step column:", step_col, "\n")
  cat("Trust trajectory:\n")
  print(ts_data, n = 30)
  
  # Exponential fit
  tryCatch({
    colnames(ts_data)[1] <- "step"
    nls_fit <- nls(mean_trust ~ A - B * exp(-k * step),
                   data = ts_data,
                   start = list(A = 90, B = 40, k = 0.005),
                   control = nls.control(maxiter = 200))
    
    ts_data$predicted <- predict(nls_fit)
    ss_res <- sum((ts_data$mean_trust - ts_data$predicted)^2)
    ss_tot <- sum((ts_data$mean_trust - mean(ts_data$mean_trust))^2)
    r2_trust <- 1 - ss_res / ss_tot
    
    cat("\nHancock calibration: R² =", round(r2_trust, 4),
        "| Asymptote =", round(coef(nls_fit)["A"], 1),
        "->", ifelse(r2_trust > 0.85, "PASS", "FAIL"), "\n")
    
    # Figure 4: Trust trajectory with exponential fit
    fig4 <- ggplot(ts_data, aes(x = step)) +
      geom_point(aes(y = mean_trust), color = "#2166AC", size = 2, alpha = 0.7) +
      geom_ribbon(aes(ymin = mean_trust - sd_trust,
                      ymax = mean_trust + sd_trust),
                  fill = "#2166AC", alpha = 0.15) +
      geom_line(aes(y = predicted), color = "#B2182B", linewidth = 1.2, linetype = "dashed") +
      labs(x = "Simulation Tick", y = "Mean Trust Level",
           title = "Trust Trajectory with Exponential Fit (Hancock Calibration)",
           subtitle = paste0("R² = ", round(r2_trust, 3),
                             " | Asymptote = ", round(coef(nls_fit)["A"], 1))) +
      theme_minimal(base_size = 12)
    print(fig4)
    ggsave("Fig4_trust_trajectory.png", fig4, width = 8, height = 5, dpi = 300)
    ggsave("Fig4_trust_trajectory.svg", fig4, width = 8, height = 5, device = "svg")
    cat("Saved: Fig4_trust_trajectory.png + .svg\n")
  }, error = function(e) { cat("NLS fit failed:", e$message, "\n") })
}, error = function(e) { cat("Skipped trust trajectory.\n") })

# =============================================================================
# 4. SUMMARY
# =============================================================================

cat("\n")
cat(strrep("=", 60), "\n")
cat("SUMMARY: ALL KEY VALUES FOR PAPER\n")
cat(strrep("=", 60), "\n\n")

cat("1. RELIABILITY-PERFORMANCE:\n")
if (exists("best_rel")) {
  cat("   Peak:", best_rel$`robot-reliability`, "% | Perf:", best_rel$perf, "%\n")
  cat("   Non-linear?", ifelse(best_rel$`robot-reliability` < 100, "YES", "NO"), "\n")
}
if (exists("best_poly")) {
  cat("   Best polynomial: order", best_poly$Order, "| Adj R²:", best_poly$Adj_R2, "\n")
  cat("   Linear AIC:", poly_results$AIC[1], "| Best AIC:", best_poly$AIC,
      "| DAIC:", poly_results$AIC[1] - best_poly$AIC, "\n")
}
if (exists("eta_rel")) cat("   eta²:", eta_rel, "\n")

cat("\n2. RELIABILITY × TRANSPARENCY:\n")
if (exists("ss_rxt")) {
  cat("   Performance:\n")
  cat("     Reliability eta²:", round(ss_rxt[["Sum Sq"]][1] / total_ss_rxt, 4), "\n")
  cat("     Transparency eta²:", round(ss_rxt[["Sum Sq"]][2] / total_ss_rxt, 4), "\n")
  int_row <- grep(":", rownames(ss_rxt))
  if (length(int_row) > 0) {
    int_p <- ss_rxt[["Pr(>F)"]][int_row]
    cat("     Interaction eta²:", round(ss_rxt[["Sum Sq"]][int_row] / total_ss_rxt, 4),
        "| p:", ifelse(int_p < 0.001, "<0.001", round(int_p, 4)), "\n")
  }
}
if (exists("ss_misalloc")) {
  cat("   Misallocation:\n")
  cat("     Reliability eta²:", round(ss_misalloc[["Sum Sq"]][1] / total_ss_misalloc, 4), "\n")
  cat("     Transparency eta²:", round(ss_misalloc[["Sum Sq"]][2] / total_ss_misalloc, 4), "\n")
  int_row_m <- grep(":", rownames(ss_misalloc))
  if (length(int_row_m) > 0) {
    int_p_m <- ss_misalloc[["Pr(>F)"]][int_row_m]
    cat("     Interaction eta²:", round(ss_misalloc[["Sum Sq"]][int_row_m] / total_ss_misalloc, 4),
        "| p:", ifelse(int_p_m < 0.001, "<0.001", round(int_p_m, 4)), "\n")
  }
}

cat("\n3. CALIBRATION:\n")
if (exists("r2_trust")) {
  cat("   Hancock: R² =", round(r2_trust, 4),
      ifelse(r2_trust > 0.85, "PASS", "FAIL"), "\n")
}

cat("\n--- Complete ---\n")