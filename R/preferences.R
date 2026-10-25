.preferences_path <- function() getOption("rcodeagent.preferences_file",
  file.path(.storage_dir("config"), "preferences.json"))

.read_preferences <- function() {
  default <- list(language = "en")
  tryCatch({
    path <- .preferences_path()
    if (!file.exists(path) || file.info(path)$size > 8192) return(default)
    value <- jsonlite::fromJSON(path, simplifyVector = FALSE)$language
    if (!is.character(value) || length(value) != 1L || is.na(value) || !(value %in% c("es", "en"))) return(default)
    list(language = value)
  }, error = function(e) default)
}

.save_preferences <- function(language) {
  if (!is.character(language) || length(language) != 1L || is.na(language) || !(language %in% c("es", "en"))) {
    stop("Idioma de interfaz no v\u00e1lido.")
  }
  path <- .preferences_path()
  if (!dir.exists(dirname(path)) && !dir.create(dirname(path), recursive = TRUE, mode = "0700")) stop("No se pudo guardar la preferencia de idioma.")
  temporary <- tempfile("preferences-", tmpdir = dirname(path))
  backup <- paste0(temporary, ".bak")
  on.exit(unlink(temporary), add = TRUE)
  writeLines(jsonlite::toJSON(list(language = language), auto_unbox = TRUE), temporary, useBytes = TRUE)
  Sys.chmod(temporary, "0600")
  existed <- file.exists(path)
  if (existed && !file.rename(path, backup)) stop("No se pudo guardar la preferencia de idioma.")
  if (!file.rename(temporary, path)) {
    if (existed) file.rename(backup, path)
    stop("No se pudo guardar la preferencia de idioma.")
  }
  if (existed) unlink(backup)
  invisible(language)
}
