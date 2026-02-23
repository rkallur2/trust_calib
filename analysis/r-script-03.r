# =============================================================================
# 03_interaction_analysis.R
# Reliability × Transparency crossed experiment
# Produces: Table 5 (cell means), interaction ANOVA, interaction plot
# =============================================================================

library(tidyverse)

# --- Load data ---------------------------------------------------------------
df_int <- read_csv("data/Sweep_Reliability_x_Transparency-table.csv",
                   skip = 6, show_col_types = FALSE)

cat("Loaded:", nrow(df_int), "rows\n")
cat("Reliability levels:", sort(unique(df_int$`robot-reliability`)), "\n")
cat("Transparency levels:", sort(unique(df_int$`robot-transparency`)), "\n\n")

# Data is final-tick only (1250 rows = 25 cells x 50 reps)
reliability <- df_int$`robot-reliability`
performance <- df_int$`get-task-success-rate`

# --- Two-way ANOVA -----------------------------------------------------------
df_int$rel_f <- as.factor(df_int$`robot-reliability`)
df_int$trans_f <- as.factor(df_int$`robot-transparency`)

aov_int <- aov(`get-task-success-rate` ~ rel_f * trans_f, data = df_int)
ss_int <- summary(aov_int)[[1]]
total_ss <- sum(ss_int[["Sum Sq"]])

cat("=== TWO-WAY ANOVA: Reliability × Transparency ===\n\n")
print(summary(aov_int))

cat("\nEffect sizes:\n")
for (i in 1:nrow(ss_int)) {
  cat(rownames(ss_int)[i], ": eta2 =",
      round(ss_int[["Sum Sq"]][i] / total_ss, 4), "\n")
}

# --- Table 5: Cell means -----------------------------------------------------
cat("\n=== TABLE 5: CELL MEANS ===\n\n")

cell_means <- df_int %>%
  group_by(`robot-reliability`, `robot-transparency`) %>%
  summarise(
    mean_perf = round(mean(`get-task-success-rate`, na.rm = TRUE), 1),
    .groups = "drop"
  ) %>%
  pivot_wider(names_from = `robot-transparency`,
              values_from = mean_perf,
              names_prefix = "Trans_")
print(cell_means, width = Inf)

# --- Interaction plot ---------------------------------------------------------
int_summary <- df_int %>%
  group_by(`robot-reliability`, `robot-transparency`) %>%
  summarise(
    mean_perf = mean(`get-task-success-rate`, na.rm = TRUE),
    se = sd(`get-task-success-rate`, na.rm = TRUE) / sqrt(n()),
    .groups = "drop"
  )

fig_int <- ggplot(int_summary,
                  aes(x = `robot-reliability`, y = mean_perf,
                      color = as.factor(`robot-transparency`),
                      group = as.factor(`robot-transparency`))) +
  geom_line(linewidth = 1) +
  geom_point(size = 3) +
  geom_errorbar(aes(ymin = mean_perf - 1.96 * se,
                    ymax = mean_perf + 1.96 * se),
                width = 2) +
  labs(x = "Robot Reliability (%)",
       y = "Task Success Rate (%)",
       color = "Transparency (%)",
       title = "Reliability × Transparency Interaction",
       subtitle = "5×5 factorial, 50 reps per cell (1,250 runs)") +
  theme_minimal(base_size = 12) +
  theme(legend.position = "bottom")

ggsave("figures/figure3_interaction.png", fig_int,
       width = 8, height = 6, dpi = 300)
cat("\nSaved: figures/figure3_interaction.png\n")
print(fig_int)

# --- Save results ------------------------------------------------------------
write_csv(as.data.frame(cell_means), "results/table5_cell_means.csv")

anova_table <- tibble(
  Source = rownames(ss_int),
  SS = round(ss_int[["Sum Sq"]], 1),
  df = ss_int[["Df"]],
  F_value = round(ss_int[["F value"]], 1),
  p_value = ss_int[["Pr(>F)"]],
  eta_sq = round(ss_int[["Sum Sq"]] / total_ss, 4)
)
write_csv(anova_table, "results/interaction_anova.csv")
cat("Saved: results/interaction_anova.csv\n")
