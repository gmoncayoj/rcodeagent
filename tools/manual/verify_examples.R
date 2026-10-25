# Parse all documented R snippets; execute only the authored synthetic examples.
for (language in c("es", "en")) {
  text <- paste(readLines(file.path("docs", "manual", paste0("manual-", language, ".md")),
    encoding = "UTF-8", warn = FALSE), collapse = "\n")
  blocks <- regmatches(text, gregexpr("(?s)```r\\n.*?```", text, perl = TRUE))[[1L]]
  evaluated <- 0L
  for (block in blocks) {
    code <- sub("^```r\\n", "", sub("```$", "", block))
    parsed <- parse(text = code)
    if (!grepl("puntajes <-|scores <-|pre  <-", code)) next
    env <- new.env(parent = globalenv())
    eval(parsed, env)
    evaluated <- evaluated + 1L
    if (grepl("na.rm = TRUE", code, fixed = TRUE)) {
      stopifnot(isTRUE(all.equal(if (language == "es") env$promedio else env$average, 16.25)))
      stopifnot(identical(if (language == "es") env$n_validos else env$n_valid, 4L))
    }
    if (grepl("paired = TRUE", code, fixed = TRUE)) {
      result <- if (language == "es") env$resultado else env$result
      stopifnot(inherits(result, "htest"), isTRUE(all.equal(unname(result$statistic), 4)))
      stopifnot(isTRUE(all.equal(unname(result$parameter), 5)))
    }
  }
  stopifnot(evaluated == 3L)
  cat(language, ": all snippets parse; three synthetic examples execute correctly.\n")
}
