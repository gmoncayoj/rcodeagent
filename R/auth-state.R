# These helpers operate only on this process's selected per-user profile.
.oauth_move_file <- function(from, to) file.rename(from, to)

.oauth_recover_file <- function(path) {
  backup <- paste0(path, ".bak")
  if (!file.exists(path) && file.exists(backup) && !.oauth_move_file(backup, path)) {
    stop("No se pudo recuperar el registro OAuth local.", call. = FALSE)
  }
  path
}

.oauth_replace_file <- function(temporary, path) {
  backup <- paste0(path, ".bak")
  .oauth_recover_file(path)
  if (file.exists(backup) && !file.remove(backup)) stop("No se pudo actualizar el registro OAuth.")
  existed <- file.exists(path)
  if (existed && !.oauth_move_file(path, backup)) stop("No se pudo actualizar el registro OAuth.")
  if (!.oauth_move_file(temporary, path)) {
    if (existed && !.oauth_move_file(backup, path)) {
      stop("No se pudo restaurar la sesi\u00f3n OAuth; la copia cifrada anterior se conserva como .bak.")
    }
    stop("No fue posible conservar la sesi\u00f3n OAuth cifrada.")
  }
  if (existed) unlink(backup)
  invisible(TRUE)
}

.oauth_with_lock <- function(code) {
  folder <- .storage_dir("data")
  dir.create(folder, recursive = TRUE, mode = "0700", showWarnings = FALSE)
  lock <- filelock::lock(file.path(folder, "oauth-session.lock"), timeout = 35000)
  if (is.null(lock)) stop("La sesi\u00f3n OAuth est\u00e1 ocupada. Reintenta cuando termine la operaci\u00f3n actual.", call. = FALSE)
  on.exit(filelock::unlock(lock), add = TRUE)
  force(code)
}

.oauth_registration_path <- function(client_id = NULL) {
  folder <- .storage_dir("config")
  dir.create(folder, recursive = TRUE, mode = "0700", showWarnings = FALSE)
  if (is.null(client_id)) return(file.path(folder, "oauth-registration.json"))
  if (!is.character(client_id) || length(client_id) != 1L || is.na(client_id) ||
      !grepl("^oaiapp_[A-Za-z0-9_-]+$", client_id) || nchar(client_id) > 200L) stop("La identidad OAuth guardada no es v\u00e1lida.")
  folder <- file.path(folder, "oauth-registrations")
  dir.create(folder, recursive = TRUE, mode = "0700", showWarnings = FALSE)
  file.path(folder, paste0(client_id, ".json"))
}

.oauth_save_registration <- function(cred) {
  if (!is.character(cred$client_id) || length(cred$client_id) != 1L ||
      !grepl("^oaiapp_[A-Za-z0-9_-]+$", cred$client_id) ||
      !is.character(cred$subject) || length(cred$subject) != 1L || !nzchar(cred$subject)) {
    stop("La identidad OAuth guardada no es v\u00e1lida.")
  }
  registration <- list(client_id = cred$client_id, subject = cred$subject,
    email = if (is.character(cred$email) && length(cred$email) == 1L) cred$email else "")
  # Preserve client/account mappings separately; never archive tokens or login hints.
  records <- Filter(Negate(is.null), list(.oauth_registration(), registration))
  saved <- .oauth_registration_path(registration$client_id)
  if (file.exists(saved)) {
    previous <- jsonlite::fromJSON(saved, simplifyVector = FALSE)
    if (!identical(previous$subject, registration$subject)) stop("La cuenta autenticada no corresponde a la sesi\u00f3n anterior.")
  }
  for (record in records) {
    saved <- .oauth_registration_path(record$client_id)
    staged <- tempfile(tmpdir = dirname(saved))
    on.exit(unlink(staged), add = TRUE)
    writeLines(jsonlite::toJSON(record, auto_unbox = TRUE), staged, useBytes = TRUE)
    Sys.chmod(staged, "0600")
    .oauth_replace_file(staged, saved)
  }
  file <- .oauth_registration_path()
  temporary <- tempfile(tmpdir = dirname(file))
  on.exit(unlink(temporary), add = TRUE)
  writeLines(jsonlite::toJSON(registration, auto_unbox = TRUE), temporary, useBytes = TRUE)
  Sys.chmod(temporary, "0600")
  .oauth_replace_file(temporary, file)
}

.oauth_registration <- function() {
  file <- .oauth_recover_file(.oauth_registration_path())
  if (!file.exists(file)) return(NULL)
  if (file.info(file)$size > 8192) stop("La identidad OAuth guardada no es v\u00e1lida.")
  value <- jsonlite::fromJSON(file, simplifyVector = FALSE)
  if (!is.character(value$client_id) || length(value$client_id) != 1L ||
      !grepl("^oaiapp_[A-Za-z0-9_-]+$", value$client_id) ||
      !is.character(value$subject) || length(value$subject) != 1L || !nzchar(value$subject)) {
    stop("La identidad OAuth guardada no es v\u00e1lida.")
  }
  value[c("client_id", "subject", "email")]
}

.oauth_drop_tokens <- function() {
  files <- c(.oauth_secret_file(), paste0(.oauth_secret_file(), ".bak"))
  for (file in files) if (file.exists(file) && !file.remove(file)) stop("No se pudo retirar la credencial local.")
  invisible(TRUE)
}

.oauth_token_data <- function(data) {
  if (!is.list(data)) stop("La respuesta OAuth no es v\u00e1lida.", call. = FALSE)
  scalar <- function(x) is.character(x) && length(x) == 1L && !is.na(x) &&
    nzchar(x) && nchar(x) <= 64000L && !grepl("[[:space:][:cntrl:]]", x)
  lifetime <- data$expires_in
  if (!scalar(data$access_token) || !scalar(data$refresh_token) ||
      !is.numeric(lifetime) || length(lifetime) != 1L || !is.finite(lifetime) || lifetime <= 0 ||
      (!is.null(data$token_type) && !identical(tolower(data$token_type), "bearer")) ||
      (!is.null(data$scope) && (!is.character(data$scope) || length(data$scope) != 1L || is.na(data$scope)))) {
    stop("La respuesta de renovaci\u00f3n OAuth contiene un token o vencimiento inv\u00e1lido.", call. = FALSE)
  }
  data
}

.oauth_refresh_request <- function(cred) {
  req <- httr2::request(.oauth_token) |>
    httr2::req_options(followlocation = FALSE) |>
    httr2::req_body_form(grant_type = "refresh_token", client_id = cred$client_id,
      refresh_token = cred$refresh_token, resource = .oauth_resource) |>
    httr2::req_timeout(30) |>
    httr2::req_error(is_error = function(resp) FALSE)
  response <- httr2::req_perform(req)
  data <- tryCatch(httr2::resp_body_json(response, simplifyVector = FALSE), error = function(e) NULL)
  status <- httr2::resp_status(response)
  if (status >= 400L) {
    code <- if (!is.list(data)) NULL else if (is.list(data$error)) data$error$code else data$error
    terminal <- is.character(code) && length(code) == 1L && code %in% c("invalid_grant",
      "invalid_refresh_token", "token_expired", "refresh_token_expired", "refresh_token_invalidated", "refresh_token_reused")
    if (isTRUE(terminal)) stop(structure(list(message = "La sesi\u00f3n OAuth ya no es v\u00e1lida. Vuelve a iniciar sesi\u00f3n.", call = NULL),
      class = c("rcodeagent_auth_terminal", "error", "condition")))
    stop(paste0("No se pudo renovar la sesi\u00f3n OAuth (HTTP ", status, "). Reintenta o revisa la conexi\u00f3n."), call. = FALSE)
  }
  .oauth_token_data(data)
}

.oauth_revoke <- function(cred) {
  # Discovery is fixed; a returned endpoint must remain on the trusted HTTPS issuer.
  request <- httr2::request("https://auth.openai.com/.well-known/openid-configuration") |>
    httr2::req_options(followlocation = FALSE) |>
    httr2::req_timeout(5) |>
    httr2::req_retry(max_tries = 2, retry_on_failure = TRUE, backoff = function(n) 0.25)
  metadata <- httr2::resp_body_json(httr2::req_perform(request), simplifyVector = FALSE)
  endpoint <- metadata$revocation_endpoint
  if (!is.character(endpoint) || length(endpoint) != 1L || is.na(endpoint) ||
      !grepl("^https://auth[.]openai[.]com/[A-Za-z0-9/_-]+$", endpoint)) {
    stop("El servicio no devolvi\u00f3 un destino de revocaci\u00f3n confiable.")
  }
  request <- httr2::request(endpoint) |>
    httr2::req_options(followlocation = FALSE) |>
    httr2::req_body_form(token = cred$refresh_token, token_type_hint = "refresh_token", client_id = cred$client_id) |>
    httr2::req_timeout(5) |>
    httr2::req_retry(max_tries = 2, retry_on_failure = TRUE, backoff = function(n) 0.25)
  identical(httr2::resp_status(httr2::req_perform(request)), 200L)
}
