.edit_lines <- function(text) {
  if (!is.character(text) || length(text) != 1L || is.na(text) || nchar(text) > 60000L) {
    stop("El texto de la edici\u00f3n no es v\u00e1lido.", call. = FALSE)
  }
  if (!nzchar(text)) return(character())
  pieces <- strsplit(paste0(text, "\n."), "\n", fixed = TRUE)[[1L]]
  pieces[-length(pieces)]
}

.edit_digest <- function(text) as.character(openssl::sha256(charToRaw(enc2utf8(text))))

.make_edit_patch <- function(before, after) {
  old <- .edit_lines(before)
  new <- .edit_lines(after)
  prefix <- 0L
  while (prefix < min(length(old), length(new)) && identical(old[[prefix + 1L]], new[[prefix + 1L]])) prefix <- prefix + 1L
  suffix <- 0L
  while (suffix < min(length(old), length(new)) - prefix &&
      identical(old[[length(old) - suffix]], new[[length(new) - suffix]])) suffix <- suffix + 1L
  part <- function(x, start, count) if (count > 0L) x[seq.int(start, length.out = count)] else character()
  a <- part(old, prefix + 1L, length(old) - prefix - suffix)
  b <- part(new, prefix + 1L, length(new) - prefix - suffix)
  n <- length(a); m <- length(b)
  # Bound both work and memory for long or highly repetitive proposals.
  if (n && m && as.double(n) * m <= 250000) {
    lcs <- matrix(0L, n + 1L, m + 1L)
    for (i in seq.int(n, 1L)) for (j in seq.int(m, 1L)) {
      lcs[i, j] <- if (identical(a[[i]], b[[j]])) 1L + lcs[i + 1L, j + 1L] else max(lcs[i + 1L, j], lcs[i, j + 1L])
    }
    i <- 1L; j <- 1L; k <- 1L
    types <- character(n + m); texts <- character(n + m)
    while (i <= n && j <= m) {
      if (identical(a[[i]], b[[j]])) {
        types[[k]] <- "context"; texts[[k]] <- a[[i]]; i <- i + 1L; j <- j + 1L
      } else if (lcs[i + 1L, j] >= lcs[i, j + 1L]) {
        types[[k]] <- "delete"; texts[[k]] <- a[[i]]; i <- i + 1L
      } else { types[[k]] <- "add"; texts[[k]] <- b[[j]]; j <- j + 1L }
      k <- k + 1L
    }
    for (tail_type in c("delete", "add")) {
      tail_text <- if (tail_type == "delete") part(a, i, n - i + 1L) else part(b, j, m - j + 1L)
      if (length(tail_text)) {
        indices <- seq.int(k, length.out = length(tail_text))
        types[indices] <- tail_type; texts[indices] <- tail_text; k <- k + length(tail_text)
      }
    }
    types <- utils::head(types, k - 1L); texts <- utils::head(texts, k - 1L)
  } else { types <- c(rep("delete", n), rep("add", m)); texts <- c(a, b) }
  types <- c(rep("context", prefix), types, rep("context", suffix))
  texts <- c(utils::head(old, prefix), texts, if (suffix) utils::tail(old, suffix) else character())
  old_number <- cumsum(types != "add"); new_number <- cumsum(types != "delete")
  changed <- types != "context"
  starts <- which(changed & c(TRUE, utils::head(!changed, -1L)))
  ends <- which(changed & c(utils::tail(!changed, -1L), TRUE))
  hunks <- lapply(seq_along(starts), function(i) {
    indices <- seq.int(starts[[i]], ends[[i]])
    list(start = if (starts[[i]] == 1L) 1L else old_number[[starts[[i]] - 1L]] + 1L,
      remove = texts[indices[types[indices] == "delete"]], insert = texts[indices[types[indices] == "add"]])
  })
  old_number[types == "add"] <- NA_integer_; new_number[types == "delete"] <- NA_integer_
  list(version = 1L, before = .edit_digest(before), after = .edit_digest(after), hunks = hunks,
    rows = data.frame(type = types, text = texts, old = old_number, new = new_number, stringsAsFactors = FALSE))
}

.apply_edit_patch <- function(text, patch) {
  if (!is.list(patch) || !identical(patch$version, 1L) || !identical(.edit_digest(text), patch$before) || !is.list(patch$hunks)) {
    stop("El contenido cambi\u00f3 o no coincide con la base del parche.", call. = FALSE)
  }
  lines <- .edit_lines(text); result <- character(); cursor <- 1L
  for (hunk in patch$hunks) {
    start <- hunk$start; count <- length(hunk$remove)
    if (!is.numeric(start) || length(start) != 1L || is.na(start) || start != as.integer(start) ||
        start < cursor || start > length(lines) + 1L || start + count > length(lines) + 1L ||
        !is.character(hunk$remove) || !is.character(hunk$insert)) stop("El parche de edici\u00f3n no es v\u00e1lido.")
    removed <- if (count) lines[seq.int(start, length.out = count)] else character()
    if (!identical(removed, hunk$remove)) stop("El contenido no coincide con el parche.")
    if (start > cursor) result <- c(result, lines[seq.int(cursor, start - 1L)])
    result <- c(result, hunk$insert)
    cursor <- start + count
  }
  if (cursor <= length(lines)) result <- c(result, lines[seq.int(cursor, length(lines))])
  result <- paste(result, collapse = "\n")
  if (!identical(.edit_digest(result), patch$after)) stop("El resultado no coincide con el parche aprobado.")
  result
}

.edit_diff_lines <- function(patch, context = 3L) {
  rows <- patch$rows
  changed <- which(rows$type != "context")
  if (!length(changed)) return(rows[0L, , drop = FALSE])
  keep <- sort(unique(unlist(lapply(changed, function(i) seq.int(max(1L, i - context), min(nrow(rows), i + context))))))
  rows[keep, , drop = FALSE]
}

.edit_diff_view <- function(before, after, language = "es") {
  rows <- .edit_diff_lines(.make_edit_patch(before, after))
  if (!nrow(rows)) return(shiny::p(.tr_ui("Sin cambios en el c\u00f3digo.", language)))
  shiny::div(class = "rg-edit-diff",
    shiny::p(.tr_ui("\u2212 l\u00edneas eliminadas \u00b7 + l\u00edneas a\u00f1adidas", language)),
    shiny::tags$table(`aria-label` = .tr_ui("Cambios propuestos", language),
      shiny::tags$tbody(lapply(seq_len(nrow(rows)), function(i) shiny::tags$tr(class = paste0("rg-diff-", rows$type[[i]]),
        shiny::tags$td(class = "rg-diff-number", if (!is.na(rows$old[[i]])) rows$old[[i]] else ""),
        shiny::tags$td(class = "rg-diff-number", if (!is.na(rows$new[[i]])) rows$new[[i]] else ""),
        shiny::tags$td(shiny::tags$code(paste0(switch(rows$type[[i]], add = "+ ", delete = "\u2212 ", "  "), rows$text[[i]]))))))))
}
