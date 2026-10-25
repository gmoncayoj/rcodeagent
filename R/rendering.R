# Render Markdown as a restricted fragment; model HTML is never trusted.
.render_markdown <- function(text) {
  html <- commonmark::markdown_html(text, extensions = c("table", "strikethrough"))
  document <- xml2::read_html(paste0("<html><body>", html, "</body></html>"),
    options = c("RECOVER", "NOERROR", "NOWARNING", "NONET"))
  body <- xml2::xml_find_first(document, ".//body")
  allowed <- c("p", "em", "strong", "code", "pre", "ul", "ol", "li",
               paste0("h", 1:6), "blockquote", "hr", "br", "a",
               "table", "thead", "tbody", "tr", "th", "td")
  for (node in rev(as.list(xml2::xml_find_all(body, ".//*")))) {
    if (!(xml2::xml_name(node) %in% allowed)) xml2::xml_remove(node)
  }
  xml2::xml_remove(xml2::xml_find_all(body, ".//comment()"))
  for (node in as.list(xml2::xml_find_all(body, ".//*"))) {
    href <- xml2::xml_attr(node, "href")
    for (attribute in names(xml2::xml_attrs(node))) xml2::xml_set_attr(node, attribute, NULL)
    if (identical(xml2::xml_name(node), "a") && !is.na(href) &&
        grepl("^(https?://|mailto:)", href, ignore.case = TRUE) &&
        !grepl("[[:cntrl:]]", href)) {
      xml2::xml_set_attr(node, "href", href)
      xml2::xml_set_attr(node, "target", "_blank")
      xml2::xml_set_attr(node, "rel", "noopener noreferrer")
    }
  }
  shiny::HTML(paste(vapply(as.list(xml2::xml_contents(body)), as.character, character(1L)), collapse = ""))
}

.permission_mode <- function(value) {
  if (!is.character(value) || length(value) != 1L || is.na(value) ||
      !(value %in% c("normal", "auto"))) {
    stop("El modo solicitado no est\u00e1 disponible.", call. = FALSE)
  }
  value
}
