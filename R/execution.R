# Execution proposals are data. Only the UI server can create and consume grants.
.execution_text <- function(code) {
  if (!is.character(code) || length(code) != 1L || is.na(code) || nchar(code) > 60000L || !nzchar(trimws(code))) {
    stop("El c\u00f3digo de ejecuci\u00f3n debe ser un texto no vac\u00edo de hasta 60 000 caracteres.", call. = FALSE)
  }
  parsed <- tryCatch(parse(text = code, keep.source = TRUE), error = function(e) {
    stop("El rango no contiene una expresi\u00f3n R completa. Elige las l\u00edneas completas.", call. = FALSE)
  })
  if (!length(parsed)) stop("El rango est\u00e1 vac\u00edo o solo contiene comentarios.", call. = FALSE)
  code
}

.execution_intent <- function(prompt, snapshot) {
  none <- list(kind = "none", direct = FALSE, write = FALSE, authorized = FALSE)
  if (!is.character(prompt) || length(prompt) != 1L || is.na(prompt) || nchar(prompt) > 16000L) return(none)
  text <- trimws(prompt)
  text <- gsub("[[:space:]]+", " ", text)
  text <- sub("[.!]$", "", text)
  text <- sub("^(por favor[, ]+|please )", "", text, ignore.case = TRUE)
  unquoted <- gsub('"([^"\\\\]|\\\\.)*"|\'([^\'\\\\]|\\\\.)*\'|`[^`]*`|\u00ab[^\u00bb]*\u00bb|\u201c[^\u201d]*\u201d|\u2018[^\u2019]*\u2019', " ", text, perl = TRUE)
  if (grepl(paste0("\\b(cuando|when|unless|until|despu\u00e9s|despues|after)\\b|\\bsi\\b|\\bif\\b|",
      "\\b(no|not|never)\\b|\\b(sin|without) .*(ejecut|run|execute)|\\b(don.t) (run|execute)"),
      unquoted, perl = TRUE, ignore.case = TRUE)) return(none)
  if (grepl("^(ejecuta|ejec\u00fatalo|ejecutalo|execute|run)$", text, ignore.case = TRUE)) {
    return(list(kind = "context", direct = TRUE, write = FALSE, authorized = TRUE))
  }
  install <- regmatches(text, regexec("^(instala|install) (el |the )?(paquete |package )?([a-z][a-z0-9.]*)$", text, perl = TRUE, ignore.case = TRUE))[[1L]]
  if (length(install)) return(list(kind = "install", direct = TRUE, write = FALSE, authorized = TRUE, package = install[[5L]]))
  match <- regmatches(text, regexec("^(carga|activa|load|attach) (la |el |the )?(librer\u00eda |libreria |biblioteca |library |paquete |package )?([a-z][a-z0-9.]*)$", text, perl = TRUE, ignore.case = TRUE))[[1L]]
  if (length(match)) return(list(kind = "library", direct = TRUE, write = TRUE, package = match[[5L]]))
  match <- regmatches(text, regexec("^(ejecuta|execute|run) library\\(([a-z][a-z0-9.]*)\\)(,? (sin agregarlo al script|without adding it to the script))?$", text, perl = TRUE, ignore.case = TRUE))[[1L]]
  if (length(match)) return(list(kind = "library", direct = TRUE, write = FALSE, package = match[[3L]]))
  match <- regmatches(text, regexec("^(ejecuta|execute|run) (la |las |the )?(l\u00ednea|linea|l\u00edneas|lineas|line|lines) ([0-9]+)( (a|al|hasta|to|through) ([0-9]+))?$", text, perl = TRUE, ignore.case = TRUE))[[1L]]
  if (length(match)) return(list(kind = "lines", direct = TRUE, write = FALSE,
    first = suppressWarnings(as.numeric(match[[5L]])), last = suppressWarnings(as.numeric(if (nzchar(match[[8L]])) match[[8L]] else match[[5L]]))))
  if (grepl("^(ejecuta|execute|run) (la |the )?(selecci\u00f3n|seleccion|selection)$", text, perl = TRUE, ignore.case = TRUE)) {
    return(list(kind = "selection", direct = TRUE, write = FALSE))
  }
  # Only an imperative in the current user message authorizes a model proposal.
  imperative <- grepl("^(ejecuta|ejec\u00fatalo|ejecutalo|execute|run)( |$)", unquoted, perl = TRUE, ignore.case = TRUE)
  combined <- grepl(paste0("^(genera|crea|corrige|modifica|escribe|generate|create|fix|modify|edit|write)( .+)? ",
    "(y|and) (ejecuta|ejec\u00fatalo|ejecutalo|ejecutarlo|execute|run)\\b"), unquoted, perl = TRUE, ignore.case = TRUE)
  if (imperative || combined) { none$kind <- "request"; none$authorized <- TRUE }
  none
}

.execution_code <- function(intent, snapshot) {
  if (!.editor_allows_r(snapshot)) stop("Elige un destino de c\u00f3digo R antes de ejecutar.", call. = FALSE)
  code <- switch(intent$kind,
    library = paste0("library(", intent$package, ")"),
    install = paste0('install.packages("', intent$package, '")'),
    selection = {
      if (is.null(snapshot$range)) stop("Captura una selecci\u00f3n de c\u00f3digo antes de ejecutarla.", call. = FALSE)
      snapshot$text
    },
    context = snapshot$text,
    lines = {
      lines <- strsplit(gsub("\r\n", "\n", snapshot$full, fixed = TRUE), "\n", fixed = TRUE)[[1L]]
      first <- intent$first; last <- intent$last
      if (length(first) != 1L || length(last) != 1L || !is.finite(first) || !is.finite(last) ||
          first < 1 || last < first || last > length(lines)) stop("El rango de l\u00edneas est\u00e1 fuera del documento.", call. = FALSE)
      # A parseable interior line can still belong to an incomplete larger expression.
      whole <- tryCatch(parse(text = paste(lines, collapse = "\n"), keep.source = TRUE), error = function(e) {
        stop("No se pueden comprobar las l\u00edneas con el documento incompleto. Completa la expresi\u00f3n o captura una selecci\u00f3n expl\u00edcita.", call. = FALSE)
      })
      for (ref in attr(whole, "srcref")) {
        span <- as.integer(ref)[c(1L, 3L)]
        if (span[[1L]] <= last && span[[2L]] >= first && (span[[1L]] < first || span[[2L]] > last)) {
          stop("El rango no contiene la expresi\u00f3n R completa. Elige las l\u00edneas completas.", call. = FALSE)
        }
      }
      paste(lines[seq.int(first, last)], collapse = "\n")
    }, stop("La ejecuci\u00f3n necesita un alcance expl\u00edcito o una confirmaci\u00f3n puntual.", call. = FALSE))
  .execution_text(code)
}

.has_library_call <- function(text, package) {
  parsed <- tryCatch(parse(text = text, keep.source = FALSE), error = function(e) expression())
  any(vapply(as.list(parsed), function(call) {
    if (!is.call(call) || !identical(call[[1L]], as.name("library")) || length(call) < 2L) return(FALSE)
    args <- as.list(call)[-1L]
    argument <- if ("package" %in% names(args)) args$package else args[[1L]]
    if (isTRUE(args$character.only) && is.symbol(argument)) return(FALSE)
    value <- if (is.symbol(argument)) as.character(argument) else argument
    is.character(value) && length(value) == 1L && identical(value, package)
  }, logical(1L)))
}

.new_execution_grant <- function(request_id, lease, snapshot, code) {
  .execution_text(code)
  if (!.editor_allows_r(snapshot)) stop("El destino de ejecuci\u00f3n no est\u00e1 autorizado.", call. = FALSE)
  grant <- new.env(parent = emptyenv())
  grant$used <- FALSE
  grant$request_id <- request_id
  grant$lease <- lease
  grant$snapshot <- snapshot
  grant$code <- code
  grant
}

.consume_execution_grant <- function(grant, request_id, lease, snapshot, code) {
  if (!is.environment(grant) || !identical(grant$used, FALSE)) return(FALSE)
  grant$used <- TRUE # An uncertain or failed attempt can never consume this authorization again.
  identical(grant$request_id, request_id) && identical(grant$lease, lease) &&
    identical(grant$snapshot, snapshot) && identical(grant$code, code)
}

.validate_execution_target <- function(snapshot) {
  current <- .rstudio_call("getSourceEditorContext", id = snapshot$id)
  if (!is.character(current$contents) || !identical(current$id, snapshot$id) ||
      !identical(current$path %||% "", snapshot$path) ||
      !identical(paste(current$contents, collapse = "\n"), snapshot$full)) {
    stop(structure(list(message = "El destino cambi\u00f3. No se enviar\u00e1 c\u00f3digo a la consola; vuelve a capturarlo.", call = NULL),
      class = c("rcodeagent_editor_conflict", "error", "condition")))
  }
  invisible(TRUE)
}

.execution_requires_review <- function(code) {
  parsed <- parse(text = .execution_text(code), keep.source = FALSE)
  sensitive <- c("unlink", "file.remove", "file.rename", "file.copy", "dir.create", "system", "system2", "shell",
    "remove.packages", "update.packages", "download.file", "quit", "q", "restartSession",
    "source", "sys.source", "eval", "evalq", "eval.parent", "do.call", "get", "getFromNamespace", "load")
  walk <- function(node) {
    if (is.pairlist(node)) return(any(vapply(as.list(node), walk, logical(1L))))
    if (!is.call(node)) return(FALSE)
    head <- node[[1L]]
    if (is.call(head)) {
      if (!as.character(head[[1L]]) %in% c("::", ":::")) return(TRUE)
      name <- as.character(head[[3L]])
    } else name <- as.character(head)
    if (length(name) != 1L || name %in% sensitive) return(TRUE)
    any(vapply(as.list(node)[-1L], walk, logical(1L)))
  }
  any(vapply(as.list(parsed), walk, logical(1L)))
}

.console_execution_ready <- function() {
  # Native idle probe succeeded; the user explicitly accepted RStudio queueing.
  # This is capability, never execution authorization. Each dispatch still needs a grant.
  TRUE
}

.console_input_empty <- function() {
  # Read only the current console *input*, never its output/history or R objects.
  # This check is deliberately not represented as a busy-session detector.
  console <- .rstudio_call("getConsoleEditorContext")
  if (!is.list(console) || !identical(console$id, "#console") || !is.character(console$contents) ||
      !length(console$contents) || anyNA(console$contents)) stop("No se pudo comprobar la entrada de la consola.", call. = FALSE)
  if (any(nzchar(trimws(console$contents)))) stop("Hay texto pendiente en la entrada de la consola. Term\u00ednalo o canc\u00e9lalo antes de ejecutar.", call. = FALSE)
  invisible(TRUE)
}

.submit_console_execution <- function(code, snapshot) {
  .execution_text(code)
  if (!.console_execution_ready()) {
    stop("La ejecuci\u00f3n est\u00e1 preparada, pero requiere validar primero el env\u00edo nativo de RStudio. No se envi\u00f3 c\u00f3digo a la consola.", call. = FALSE)
  }
  .console_input_empty()
  .validate_execution_target(snapshot) # Final target read directly precedes the effect.
  .rstudio_call("sendToConsole", code = code, execute = TRUE, echo = TRUE, focus = FALSE, animate = FALSE)
  invisible(TRUE)
}
