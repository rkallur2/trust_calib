# =============================================================================
# 01_scenario_factorial_analysis.R
# Factorial ANOVA from All Scenarios Comparison (576-cell design)
# Produces: Table 2 (ANOVA), marginal means, main effect plots
# =============================================================================

library(tidyverse)

# --- Load data ---------------------------------------------------------------
df_raw <- read_csv("data/Trustv5_All_Scenarios_Comparison-table.csv",
                   skip = 6, show_col_types = FALSE)

cat("Loaded:", nrow(df_raw), "rows x", ncol(df_raw), "columns\n\n")

# --- Filter to final tick per run --------------------------------------------
df <- df_raw %>%
  group_by(`[run number]`) %>%
  filter(`[step]` == max(`[step]`)) %>%
  ungroup()

cat("Final-tick observations:", nrow(df), "\n\n")

# --- Design summary ----------------------------------------------------------
params <- c("initial-tasks", "robot-reliability", "robot-autonomy",
            "robot-transparency", "robot-comm-frequency", "collaboration-rate")

cat("=== FACTORIAL DESIGN ===\n\n")
for (p in params) {
  vals <- sort(unique(df[[p]]))
  cat(p, ":", length(vals), "levels ->", paste(vals, collapse = ", "), "\n")
}

n_combos <- df %>% select(all_of(params)) %>% distinct() %>% nrow()
cat("\nUnique combinations:", n_combos, "\n")
cat("Total runs:", nrow(df), "\n")
cat("Mean reps per cell:", round(nrow(df) / n_combos, 1), "\n\n")

# --- Main effects ANOVA (Table 2) -------------------------------------------
df_aov <- df %>% mutate(across(all_of(params), as.factor))

formula_main <- as.formula(
  paste("`get-task-success-rate` ~",
        paste(paste0("`", params, "`"), collapse = " + "))
)

aov_main <- aov(formula_main, data = df_aov)
ss <- summary(aov_main)[[1]]
ss_total <- sum(ss[["Sum Sq"]])

cat("=== TABLE 2: FACTORIAL ANOVA ===\n\n")
for (i in 1:nrow(ss)) {
  cat(sprintf("%-25s  SS=%10.1f  df=%5d  eta2=%.4f  F=%8.1f  p=%s\n",
      rownames(ss)[i], ss[["Sum Sq"]][i], ss[["Df"]][i],
      ss[["Sum Sq"]][i] / ss_total,
      ifelse(is.na(ss[["F value"]][i]), 0, ss[["F value"]][i]),
      ifelse(is.na(ss[["Pr(>F)"]][i]), "",
             ifelse(ss[["Pr(>F)"]][i] < 0.001, "<0.001",
                    round(ss[["Pr(>F)"]][i], 4)))))
}

# --- Marginal means per parameter --------------------------------------------
cat("\n=== MARGINAL MEANS ===\n\n")

for (p in params) {
  p_summary <- df %>%
    group_by(.data[[p]]) %>%
    summarise(
      n = n(),
      mean_perf = round(mean(`get-task-success-rate`, na.rm = TRUE), 1),
      sd_perf = round(sd(`get-task-success-rate`, na.rm = TRUE), 1),
      .groups = "drop"
    )
  cat(p, ":\n")
  print(p_summary)
  cat("\n")
}

# --- Reliability means (key result) ------------------------------------------
cat("=== RELIABILITY EFFECT (from factorial) ===\n\n")
df %>%
  group_by(`robot-reliability`) %>%
  summarise(
    n = n(),
    mean_success = round(mean(`get-task-success-rate`, na.rm = TRUE), 1),
    sd_success = round(sd(`get-task-success-rate`, na.rm = TRUE), 1),
    mean_trust = round(mean(`average-trust`, na.rm = TRUE), 1),
    mean_stress = round(mean(`get-average-stress`, na.rm = TRUE), 1),
    .groups = "drop"
  ) %>%
  print()

# --- Main effect plots -------------------------------------------------------
for (p in params) {
  p_data <- df %>%
    group_by(.data[[p]]) %>%
    summarise(
      mean_perf = mean(`get-task-success-rate`, na.rm = TRUE),
      se = sd(`get-task-success-rate`, na.rm = TRUE) / sqrt(n()),
      .groups = "drop"
    )

  p_plot <- ggplot(p_data, aes(x = .data[[p]], y = mean_perf)) +
    geom_line(linewidth = 1, color = "steelblue") +
    geom_point(size = 3, color = "steelblue") +
    geom_errorbar(aes(ymin = mean_perf - 1.96 * se, ymax = mean_perf + 1.96 * se),
                  width = 1, color = "steelblue") +
    labs(x = p, y = "Task Success Rate (%)",
         title = paste("Main Effect:", p)) +
    theme_minimal(base_size = 12)

  fname <- paste0("figures/main_effect_", gsub("-", "_", p), ".png")
  ggsave(fname, p_plot, width = 7, height = 5, dpi = 300)
  cat("Saved:", fname, "\n")
}

# --- Save results ------------------------------------------------------------
effect_table <- tibble(
  Parameter = rownames(ss),
  SS = round(ss[["Sum Sq"]], 1),
  df = ss[["Df"]],
  F_value = round(ss[["F value"]], 1),
  p_value = ss[["Pr(>F)"]],
  eta_sq = round(ss[["Sum Sq"]] / ss_total, 4)
)
write_csv(effect_table, "results/table2_factorial_anova.csv")
cat("\nSaved: results/table2_factorial_anova.csv\n")
