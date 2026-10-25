.export_conversation <- function(chat, path, format, language = "es") {
  if (!is.character(format) || length(format) != 1L || is.na(format) || !(format %in% c("html", "json", "md", "pdf"))) stop("Formato de exportaci\u00f3n no v\u00e1lido.")
  chat <- .validate_conversation(chat)
  label <- function(x) .tr_ui(x, language)
  blocks <- lapply(chat$messages, function(item) paste0("## ", label(item$role), "\n\n", item$text,
    if (nzchar(item$code %||% "")) paste0("\n\n```r\n", item$code, "\n```"),
    if (isTRUE(item$edit_applied)) paste0("\n\n> ", label("Auto: cambio aplicado al destino elegido. Guarda el archivo para conservarlo.")), "\n"))
  markdown <- paste(c(paste0("# ", chat$title), paste0("rcodeagent \u00b7 ", chat$updated), unlist(blocks)), collapse = "\n\n")
  if (format == "json") {
    writeLines(enc2utf8(jsonlite::toJSON(chat, auto_unbox = TRUE, pretty = TRUE, null = "null")), path, useBytes = TRUE)
  } else if (format == "md") {
    writeLines(enc2utf8(markdown), path, useBytes = TRUE)
  } else if (format == "html") {
    sections <- lapply(chat$messages, function(item) htmltools::tags$section(
      class = if (item$role == "Usuario") "user" else "assistant",
      htmltools::tags$h2(label(item$role)),
      if (item$role == "Usuario") htmltools::tags$p(style = "white-space:pre-wrap", item$text) else .render_markdown(item$text),
      if (nzchar(item$code %||% "")) htmltools::tags$pre(htmltools::tags$code(item$code)),
      if (isTRUE(item$edit_applied)) htmltools::tags$p(label("Auto: cambio aplicado al destino elegido. Guarda el archivo para conservarlo."))))
    page <- htmltools::tags$html(lang = language,
      htmltools::tags$head(htmltools::tags$meta(charset = "utf-8"), htmltools::tags$title(chat$title),
        htmltools::tags$style(htmltools::HTML("body{font:16px/1.65 system-ui,sans-serif;max-width:900px;margin:40px auto;padding:0 24px;color:#172a35}section{padding:20px 0;border-top:1px solid #d5e0e6}.user{background:#eff6f8;padding:20px;border-radius:10px}h2{font-size:14px;color:#24576b}pre{white-space:pre-wrap;background:#edf2f5;padding:16px;border-radius:8px}code{font-family:monospace}table{border-collapse:collapse}td,th{border:1px solid #ccc;padding:6px}p,li{overflow-wrap:anywhere}@media print{body{margin:0}}"))),
      htmltools::tags$body(htmltools::tags$h1(chat$title), htmltools::tags$p(paste("rcodeagent", chat$updated, sep = " \u00b7 ")), sections))
    writeLines(enc2utf8(paste0("<!doctype html>\n", as.character(page))), path, useBytes = TRUE)
  } else {
    .export_pdf(chat, path, language)
  }
  invisible(path)
}

.export_pdf <- function(chat, path, language) {
  if (!capabilities("cairo")) stop("PDF requiere Cairo en esta instalaci\u00f3n de R.")
  grDevices::cairo_pdf(path, width = 8.27, height = 11.69, family = "sans", onefile = TRUE)
  on.exit(grDevices::dev.off(), add = TRUE)
  page <- 0L
  y <- 0
  new_page <- function() {
    page <<- page + 1L
    grid::grid.newpage()
    grid::grid.text("rcodeagent", x = .08, y = .96, just = "left", gp = grid::gpar(fontsize = 10, col = "#24576b"))
    grid::grid.text(as.character(page), x = .92, y = .04, just = "right", gp = grid::gpar(fontsize = 9, col = "#536b76"))
    y <<- .91
  }
  line <- function(text, size = 10, bold = FALSE, mono = FALSE) {
    height <- (size * 1.55) / (72 * 11.69)
    if (y - height < .08) new_page()
    grid::grid.text(enc2utf8(text), x = .08, y = y, just = c("left", "top"),
      gp = grid::gpar(fontsize = size, fontface = if (bold) "bold" else "plain", fontfamily = if (mono) "mono" else "sans", col = "#172a35"))
    y <<- y - height
  }
  wrap <- function(text, size = 10, mono = FALSE, bold = FALSE) {
    fits <- function(value) grid::convertWidth(grid::grobWidth(grid::textGrob(value,
      gp = grid::gpar(fontsize = size, fontfamily = if (mono) "mono" else "sans",
        fontface = if (bold) "bold" else "plain"))), "inches", valueOnly = TRUE) <= 8.27 * .84
    for (paragraph in strsplit(text, "\n", fixed = TRUE)[[1L]]) {
      if (!nzchar(paragraph)) { line("", size); next }
      remaining <- paragraph
      while (nzchar(remaining)) {
        end <- min(nchar(remaining), max(1L, floor(96 * 10 / size)))
        while (end > 1L && !fits(substr(remaining, 1L, end))) end <- end - 1L
        if (!mono && end < nchar(remaining)) {
          spaces <- gregexpr(" ", substr(remaining, 1L, end), fixed = TRUE)[[1L]]
          if (any(spaces > 1L)) end <- max(spaces[spaces > 1L])
        }
        line(substr(remaining, 1L, end), size, bold, mono)
        remaining <- substring(remaining, end + 1L)
        if (!mono) remaining <- sub("^ +", "", remaining)
      }
    }
  }
  new_page()
  wrap(chat$title, size = 16, bold = TRUE)
  line(chat$updated, size = 9)
  for (item in chat$messages) {
    line("")
    line(.tr_ui(item$role, language), size = 11, bold = TRUE)
    if (item$role == "Usuario") wrap(item$text) else {
      document <- xml2::read_html(paste0("<body>", .render_markdown(item$text), "</body>"), options = "NONET")
      blocks <- xml2::xml_find_all(document, ".//body/*")
      for (block in blocks) {
        name <- xml2::xml_name(block)
        if (name %in% c("ul", "ol")) {
          for (child in xml2::xml_children(block)) wrap(paste0("\u2022 ", xml2::xml_text(child)))
        } else if (name == "table") {
          for (row in xml2::xml_find_all(block, ".//tr")) {
            cells <- vapply(as.list(xml2::xml_children(row)), xml2::xml_text, character(1L))
            wrap(paste(cells, collapse = " | "), mono = TRUE)
          }
        } else wrap(xml2::xml_text(block), mono = name == "pre", bold = name %in% paste0("h", 1:6))
        line("")
      }
    }
    if (nzchar(item$code %||% "")) wrap(item$code, mono = TRUE)
    if (isTRUE(item$edit_applied)) wrap(.tr_ui("Auto: cambio aplicado al destino elegido. Guarda el archivo para conservarlo.", language))
  }
}
