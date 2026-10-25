test_that("conversation exports omit credentials and render safe standalone HTML", {
  chat <- rcodeagent:::.new_conversation()
  chat$title <- "Análisis de José"
  chat$messages <- list(list(role = "Usuario", text = "<script>alert(1)</script>", code = ""),
    list(role = "Asistente", text = "**Resultado**\n\n```r\nx <- 2\n```\n<script>bad()</script>", code = ""))
  chat$access_token <- "never-export-this"
  chat$auto_mode <- TRUE
  for (format in c("html", "json", "md", "pdf")) {
    path <- tempfile(fileext = paste0(".", format))
    rcodeagent:::.export_conversation(chat, path, format, "es")
    expect_gt(file.info(path)$size, 100)
    if (format == "pdf") {
      expect_identical(rawToChar(readBin(path, "raw", 4)), "%PDF")
    } else {
      content <- paste(readLines(path, warn = FALSE, encoding = "UTF-8"), collapse = "\n")
      expect_false(grepl("never-export-this", content, fixed = TRUE))
      if (format == "html") {
        expect_false(grepl("<script", content, fixed = TRUE))
        expect_match(content, "<strong>Resultado</strong>", fixed = TRUE)
      }
      if (format == "json") expect_null(jsonlite::fromJSON(path)$auto_mode)
    }
  }
  expect_error(rcodeagent:::.export_conversation(chat, tempfile(), "exe"))
})
