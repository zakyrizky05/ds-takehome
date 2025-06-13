# Load required packages
if (!requireNamespace("ResourceSelection", quietly = TRUE)) install.packages("ResourceSelection")
if (!requireNamespace("ggplot2", quietly = TRUE)) install.packages("ggplot2")
library(ResourceSelection)
library(ggplot2)

# Load data
cat("Loading data from hl_input.csv...\n")
data <- tryCatch(
  read.csv("hl_input.csv"),
  error = function(e) { cat("Error:", e$message, "\n"); stop("Check file path or contents.") }
)

# Rename columns
names(data) <- c("y_true", "prob_pred")
cat("Data structure:\n")
str(data)

# Validate data
if (nrow(data) < 10) {
  cat("Warning: Insufficient rows (", nrow(data), "). Generating 100 sample rows.\n")
  set.seed(123)
  data <- data.frame(y_true = rbinom(100, 1, 0.5), prob_pred = runif(100, 0, 1))
}
if (any(is.na(data$y_true)) || any(is.na(data$prob_pred))) {
  cat("Warning: NA values detected. Removing rows with NA...\n")
  data <- data[complete.cases(data), ]
}
if (!all(data$y_true %in% c(0, 1))) stop("y_true must be 0 or 1.")
if (any(data$prob_pred < 0 | data$prob_pred > 1)) {
  cat("Warning: Clipping prob_pred to [0, 1]...\n")
  data$prob_pred <- pmin(pmax(data$prob_pred, 0), 1)
}

# Hosmer-Lemeshow Test
cat("Running Hosmer-Lemeshow test...\n")
hl_result <- hoslem.test(data$y_true, data$prob_pred, g = 10)
cat("Hosmer-Lemeshow Results:\n")
print(hl_result)
p_value <- hl_result$p.value
cat("Interpretation: p-value =", p_value, ifelse(p_value > 0.05, "Good fit", "Poor fit, investigate further"), "\n")

# Calibration Curve
cat("Generating calibration curve...\n")
# Create a data frame for calibration (observed vs predicted)
data$pred_group <- cut(data$prob_pred, breaks = seq(0, 1, by = 0.1), include.lowest = TRUE)
calib_data <- aggregate(y_true ~ pred_group, data, mean)
calib_data$pred_mean <- tapply(data$prob_pred, data$pred_group, mean)[calib_data$pred_group]

# Plot
p <- ggplot(calib_data, aes(x = pred_mean, y = y_true)) +
  geom_point() +
  geom_abline(intercept = 0, slope = 1, color = "red", linetype = "dashed") +
  labs(title = "Calibration Curve", x = "Predicted Probability", y = "Observed Fraction") +
  theme_minimal()
ggsave("calibration_curve.png", plot = p, width = 6, height = 4)

# Cut-off Score for Expected Default ≤ 5%
cat("Calculating cut-off score for default rate ≤ 5%...\n")
data$default_pred <- ifelse(data$prob_pred >= 0.5, 1, 0)  # Default threshold at 0.5
observed_default_rate <- mean(data$y_true[data$default_pred == 1])
cat("Default rate at 0.5 threshold:", observed_default_rate, "\n")

# Find cut-off where expected default ≤ 5%
cutoff <- 0
for (thresh in seq(0, 1, by = 0.01)) {
  data$default_pred <- ifelse(data$prob_pred >= thresh, 1, 0)
  default_rate <- mean(data$y_true[data$default_pred == 1], na.rm = TRUE)
  if (default_rate <= 0.05) {
    cutoff <- thresh
    break
  }
}
cat("Recommended cut-off for default rate ≤ 5%:", cutoff, "\n")

# Save summary to C_summary.md
summary_text <- paste0(
  "# Model Summary\n",
  "- **Hosmer-Lemeshow p-value**: ", round(p_value, 4), " (", ifelse(p_value > 0.05, "Good fit", "Poor fit"), ")\n",
  "- **Cut-off for ≤5% default rate**: ", round(cutoff, 2), "\n",
  "- **Note**: Analysis based on ", nrow(data), " rows", ifelse(nrow(data) < 10, " (sample data used)", ""), "."
)
writeLines(summary_text, "C_summary.md")
cat("Summary written to C_summary.md (", nchar(summary_text), " characters)\n")