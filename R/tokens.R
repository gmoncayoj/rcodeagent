.model_context_limit <- function(model, catalog = NULL) {
  details <- attr(catalog, "details")
  row <- if (!is.null(details)) details[[model]] else NULL
  supplied <- row$context_window %||% row$context_window_tokens
  if (is.numeric(supplied) && length(supplied) == 1L && is.finite(supplied) && supplied > 0) return(supplied)
  # Official model cards checked 2026-10-13. Do not infer limits for unknown slugs.
  known <- c("gpt-6.1-sol" = 1050000, "gpt-6-luna" = 1050000,
    "gpt-6-astra" = 1050000, "gpt-4o" = 128000)
  unname(known[model])
}

.estimate_tokens <- function(text) ceiling(nchar(enc2utf8(text), type = "bytes") / 3)

.normalize_usage <- function(usage) {
  fields <- c("input_tokens", "output_tokens", "total_tokens")
  if (!is.list(usage) || !all(vapply(fields, function(name) {
    value <- usage[[name]]
    is.numeric(value) && length(value) == 1L && is.finite(value) && value >= 0
  }, logical(1L)))) return(NULL)
  usage[fields]
}

.token_label <- function(used, maximum, estimated = FALSE) {
  number <- function(x) format(round(x), big.mark = ",", scientific = FALSE, trim = TRUE)
  paste0(if (estimated) "\u2248 " else "", number(used), "/",
    if (length(maximum) == 1L && !is.na(maximum)) number(maximum) else "?")
}
