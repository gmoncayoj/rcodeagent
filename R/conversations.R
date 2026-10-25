.conversation_dir <- function() {
  path <- getOption("rcodeagent.history_dir", file.path(.storage_dir("data"), "conversations"))
  if (!dir.exists(path) && !dir.create(path, recursive = TRUE, mode = "0700")) {
    stop("No se puede crear el historial local.")
  }
  normalizePath(path, winslash = "/", mustWork = TRUE)
}

.conversation_path <- function(id) {
  if (!is.character(id) || length(id) != 1L || is.na(id) || !grepl("^[a-f0-9]{32}$", id)) {
    stop("Identificador de conversaci\u00f3n no v\u00e1lido.", call. = FALSE)
  }
  root <- .conversation_dir()
  path <- file.path(root, paste0(id, ".json"))
  resolved <- normalizePath(path, winslash = "/", mustWork = FALSE)
  if (!startsWith(tolower(resolved), paste0(tolower(root), "/"))) stop("Ruta de historial no v\u00e1lida.")
  path
}

.new_conversation <- function() {
  list(version = 1L, id = paste(sprintf("%02x", as.integer(openssl::rand_bytes(16L))), collapse = ""),
    title = "Nueva conversaci\u00f3n", updated = format(Sys.time(), "%Y-%m-%d %H:%M:%S"),
    messages = list(), attachments = list(), model = "", effort = "medium",
    usage = list(input_tokens = 0, output_tokens = 0, total_tokens = 0))
}

.validate_conversation <- function(chat) {
  scalar <- function(x, limit) is.character(x) && length(x) == 1L && !is.na(x) && nchar(x) <= limit
  if (!is.list(chat) || !identical(as.integer(chat$version), 1L) ||
      !scalar(chat$id, 32L) || !grepl("^[a-f0-9]{32}$", chat$id) ||
      !scalar(chat$title, 120L) || !scalar(chat$updated, 40L) ||
      !is.list(chat$messages) || length(chat$messages) > 1000L || !is.list(chat$attachments)) {
    stop("El historial no tiene un formato v\u00e1lido.")
  }
  for (item in chat$messages) {
    if (!is.list(item) || !scalar(item$role, 12L) || !(item$role %in% c("Usuario", "Asistente")) ||
        !scalar(item$text, 2097152L) || !scalar(item$code %||% "", 60000L)) stop("Mensaje de historial inv\u00e1lido.")
  }
  chat$messages <- lapply(chat$messages, function(item) {
    if (!is.null(item$edit_applied) && (!is.logical(item$edit_applied) || length(item$edit_applied) != 1L || is.na(item$edit_applied))) stop("Mensaje de historial inv\u00e1lido.")
    list(role = item$role, text = item$text, code = item$code %||% "", edit_applied = isTRUE(item$edit_applied))
  })
  for (file in chat$attachments) {
    .context_name(file$name)
    if (!scalar(file$text, 524288L)) stop("Archivo de historial inv\u00e1lido.")
  }
  .attachment_prompt(chat$attachments)
  .validate_effort(chat$effort %||% "medium")
  if (!scalar(chat$model %||% "", 200L)) stop("Modelo de historial inv\u00e1lido.")
  total <- chat$usage$total_tokens %||% 0
  if (!is.numeric(total) || length(total) != 1L || !is.finite(total) || total < 0) stop("Uso de historial inv\u00e1lido.")
  chat$usage <- list(total_tokens = total, last = .normalize_usage(chat$usage$last),
    last_model = if (scalar(chat$usage$last_model, 200L)) chat$usage$last_model else NULL)
  # Whitelist fields; never restore persisted permission flags or credentials.
  chat[c("version", "id", "title", "updated", "messages", "attachments", "model", "effort", "usage")]
}

.save_conversation <- function(chat) {
  chat <- .validate_conversation(chat)
  path <- .conversation_path(chat$id)
  temporary <- tempfile("chat-", tmpdir = dirname(path), fileext = ".tmp")
  backup <- paste0(temporary, ".bak")
  on.exit(unlink(temporary), add = TRUE)
  json <- jsonlite::toJSON(chat, auto_unbox = TRUE, null = "null", pretty = TRUE)
  if (nchar(json, type = "bytes") > 16777216L) stop("La conversaci\u00f3n supera 16 MB.")
  writeLines(enc2utf8(json), temporary, useBytes = TRUE)
  Sys.chmod(temporary, "0600")
  existed <- file.exists(path)
  if (existed && !file.rename(path, backup)) stop("No se pudo actualizar el historial.")
  if (!file.rename(temporary, path)) {
    if (existed && !file.rename(backup, path)) stop("No se pudo guardar ni restaurar el historial. La copia anterior se conserva como .bak.")
    stop("No se pudo guardar el historial.")
  }
  if (existed) unlink(backup)
  invisible(chat$id)
}

.load_conversation <- function(id) {
  path <- .conversation_path(id)
  if (!file.exists(path) || file.info(path)$size > 16777216L) stop("Conversaci\u00f3n no disponible.")
  chat <- .validate_conversation(jsonlite::fromJSON(path, simplifyVector = FALSE))
  if (!identical(chat$id, id)) stop("La conversaci\u00f3n no corresponde al archivo seleccionado.")
  chat
}

.list_conversations <- function() {
  ids <- sub("\\.json$", "", list.files(.conversation_dir(), pattern = "^[a-f0-9]{32}\\.json$"))
  chats <- Filter(Negate(is.null), lapply(ids, function(id) tryCatch(.load_conversation(id), error = function(e) NULL)))
  chats[order(vapply(chats, function(x) x$updated, character(1L)), decreasing = TRUE)]
}

.delete_conversation <- function(id) {
  path <- .conversation_path(id)
  if (file.exists(path) && !file.remove(path)) stop("No se pudo eliminar la conversaci\u00f3n.")
  invisible(TRUE)
}
