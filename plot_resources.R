suppressMessages(library(tidyverse))
suppressMessages(library(lubridate))

parse_duration <- function(d) {
  d[is.na(d) | d == "-"] <- "0s"
  h <- as.numeric(str_extract(d, "[0-9]+(?=h)"))
  m <- as.numeric(str_extract(d, "[0-9]+(?=m(?!s))"))
  s <- as.numeric(str_extract(d, "[0-9]+(?=s)"))
  ms <- as.numeric(str_extract(d, "[0-9]+(?=ms)"))
  
  h[is.na(h)] <- 0
  m[is.na(m)] <- 0
  s[is.na(s)] <- 0
  ms[is.na(ms)] <- 0
  
  return(h * 3600 + m * 60 + s + ms / 1000)
}

parse_memory <- function(m) {
  m[is.na(m) | m == "-"] <- "0 GB"
  val <- as.numeric(str_extract(m, "[0-9.]+"))
  unit <- str_extract(m, "[A-Z]+")
  
  multiplier <- rep(1, length(unit))
  multiplier[unit == "TB"] <- 1024
  multiplier[unit == "MB"] <- 1/1024
  multiplier[unit == "KB"] <- 1/(1024^2)
  multiplier[unit == "B"] <- 1/(1024^3)
  
  return(val * multiplier)
}

parse_trace <- function(file, name) {
  df <- read_tsv(file, show_col_types = FALSE)
  
  # parse submit time
  df$submit_time <- ymd_hms(df$submit)
  
  # parse duration and %cpu
  df$realtime_sec <- parse_duration(df$realtime)
  df$cpu_percent <- as.numeric(str_remove(df$`%cpu`, "%"))
  df$cpu_percent[is.na(df$cpu_percent)] <- 0
  
  # parse peak_rss
  df$mem_gb <- parse_memory(df$peak_rss)
  
  # Pipeline Wall time (hours)
  # Correctly calculate completion time for each task and take the max
  complete_time <- df$submit_time + df$realtime_sec
  wall_time <- as.numeric(difftime(max(complete_time, na.rm=TRUE), min(df$submit_time, na.rm=TRUE), units = "hours"))
  
  # Total CPU Time (hours)
  cpu_time <- sum(df$realtime_sec * (df$cpu_percent / 100), na.rm=TRUE) / 3600
  
  # Max Peak Memory of any single task (GB)
  max_mem <- max(df$mem_gb, na.rm=TRUE)
  
  tibble(
    Pipeline = name,
    `Wall Time (Hours)` = wall_time,
    `Total CPU Time (Hours)` = cpu_time,
    `Max Task Memory (GB)` = max_mem
  )
}

star_file <- "results_star_salmon_batch1/pipeline_info/execution_trace_2026-06-09_21-43-01.txt"
salmon_file <- "results_salmon_pseudo_batch1/pipeline_info/execution_trace_2026-06-10_06-44-04.txt"

res <- bind_rows(
  parse_trace(star_file, "STAR + Salmon"),
  parse_trace(salmon_file, "Salmon Pseudo")
)

res_long <- res %>%
  pivot_longer(cols = -Pipeline, names_to = "Metric", values_to = "Value")

# Add text labels
res_long$Label <- sprintf("%.1f", res_long$Value)

p <- ggplot(res_long, aes(x = Pipeline, y = Value, fill = Pipeline)) +
  geom_bar(stat = "identity", width = 0.5, alpha = 0.85) +
  geom_text(aes(label = Label), vjust = -0.5, size = 5) +
  facet_wrap(~Metric, scales = "free_y") +
  theme_bw(base_size = 14) +
  labs(
    title = "Computational Resource Comparison",
    subtitle = "Traditional Alignment (STAR) vs Pseudo-alignment (Salmon)",
    x = "",
    y = "Metric Value"
  ) +
  scale_fill_manual(values = c("STAR + Salmon" = "#d62728", "Salmon Pseudo" = "#2ca02c")) +
  theme(legend.position = "none",
        axis.text.x = element_text(angle = 45, hjust = 1, size = 12, face = "bold"),
        strip.text = element_text(size = 13, face = "bold")) +
  scale_y_continuous(expand = expansion(mult = c(0, 0.2)))

ggsave("Pipeline_Resource_Comparison.pdf", plot = p, width = 10, height = 6)
cat("Comparison generated: Pipeline_Resource_Comparison.pdf\n")
