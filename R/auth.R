# Native OAuth Authorization Code + PKCE for local open-source applications.
# Based on https://developers.openai.com/siwc/token-sharing-open-source/sign-in

.oauth_auth <- "https://auth.openai.com/api/accounts/authorize"
.oauth_token <- "https://auth.openai.com/api/accounts/oauth/token"
.oauth_resource <- "https://api.openai.com/v1"
.oauth_scopes <- "openid profile email offline_access resource.invoke chatgpt.tokens.use.direct"
.oauth_service <- function() paste0(.storage_app_name(), "-ChatGPT-OAuth")

.oauth_config_path <- function() {
  path <- .storage_dir("config")
  dir.create(path, recursive = TRUE, mode = "0700", showWarnings = FALSE)
  file.path(path, "host-id.txt")
}

.oauth_random <- function(bytes = 32L) {
  out <- openssl::base64_encode(openssl::rand_bytes(bytes))
  gsub("=+$", "", chartr("+/", "-_", out))
}

.oauth_host_id <- function() {
  file <- .oauth_config_path()
  if (file.exists(file)) return(trimws(readLines(file, n = 1L, warn = FALSE)))
  # UUID v4 bytes, with RFC 4122 version/variant bits set.
  x <- as.integer(openssl::rand_bytes(16L))
  x[7] <- bitwOr(bitwAnd(x[7], 15L), 64L)
  x[9] <- bitwOr(bitwAnd(x[9], 63L), 128L)
  h <- sprintf("%02x", x)
  host <- paste0("urn:uuid:", paste(c(
    paste0(h[1:4], collapse = ""), paste0(h[5:6], collapse = ""),
    paste0(h[7:8], collapse = ""), paste0(h[9:10], collapse = ""),
    paste0(h[11:16], collapse = "")
  ), collapse = "-"))
  writeLines(host, file, useBytes = TRUE)
  host
}

# Credential blobs can exceed the Windows Credential Manager 2560-byte cap.
# Keep only a 32-byte encryption key in the OS keyring and store the complete
# authenticated-encrypted OAuth record in a private per-user data directory.
.oauth_secret_file <- function() {
  folder <- .storage_dir("data")
  dir.create(folder, recursive = TRUE, mode = "0700", showWarnings = FALSE)
  file.path(folder, "oauth-credentials.bin")
}

.oauth_encryption_key <- function(create = FALSE) {
  secret <- tryCatch(keyring::key_get(.oauth_service(), username = "local-key"),
                     error = function(e) NULL)
  if (is.null(secret)) {
    if (!create) stop("Clave local de cifrado no disponible; reconecta la cuenta.")
    secret <- sodium::bin2hex(sodium::random(32L))
    keyring::key_set_with_value(.oauth_service(), username = "local-key", password = secret)
  }
  sodium::hex2bin(secret)
}

.oauth_credential <- function() {
  file <- .oauth_recover_file(.oauth_secret_file())
  if (!file.exists(file)) return(NULL)
  cipher <- readBin(file, what = "raw", n = file.info(file)$size)
  if (length(cipher) <= 24L) stop("Registro OAuth local inv\u00e1lido.")
  nonce <- cipher[seq_len(24L)]
  payload <- cipher[-seq_len(24L)]
  value <- sodium::data_decrypt(payload, key = .oauth_encryption_key(), nonce = nonce)
  jsonlite::fromJSON(rawToChar(value), simplifyVector = FALSE)
}

.oauth_save <- function(cred) {
  key <- .oauth_encryption_key(create = TRUE)
  nonce <- sodium::random(24L)
  json <- jsonlite::toJSON(cred, auto_unbox = TRUE, null = "null")
  cipher <- sodium::data_encrypt(charToRaw(json), key = key, nonce = nonce)
  file <- .oauth_secret_file()
  tmp <- tempfile(tmpdir = dirname(file))
  on.exit(unlink(tmp), add = TRUE)
  writeBin(c(nonce, cipher), tmp)
  Sys.chmod(tmp, "0600")
  .oauth_replace_file(tmp, file)
  .oauth_save_registration(cred)
  invisible(TRUE)
}

.oauth_query <- function(items) {
  paste(paste0(vapply(names(items), utils::URLencode, character(1), reserved = TRUE), "=",
               vapply(items, utils::URLencode, character(1), reserved = TRUE)),
        collapse = "&")
}

.oauth_jwt_segment <- function(s) {
  s <- chartr("-_", "+/", s)
  missing <- (4L - nchar(s) %% 4L) %% 4L
  if (missing > 0L) s <- paste0(s, strrep("=", missing))
  rawToChar(openssl::base64_decode(s))
}

.oauth_validate_id <- function(id_token, client_id, nonce) {
  pieces <- strsplit(id_token, ".", fixed = TRUE)[[1L]]
  if (length(pieces) != 3L) stop("ID token OAuth malformado.", call. = FALSE)
  hdr <- jsonlite::fromJSON(.oauth_jwt_segment(pieces[[1L]]), simplifyVector = FALSE)
  if (!identical(hdr$alg, "RS256") || is.null(hdr$kid)) {
    stop("Algoritmo o identificador de firma OIDC no permitido.", call. = FALSE)
  }
  req <- httr2::request("https://auth.openai.com/.well-known/jwks.json") |>
    httr2::req_timeout(20)
  jwks <- jsonlite::fromJSON(httr2::resp_body_string(.connection_request(req, "identity")),
                             simplifyVector = FALSE)$keys
  matches <- Filter(function(k) identical(k$kid, hdr$kid) && identical(k$kty, "RSA") &&
                      (is.null(k$use) || identical(k$use, "sig")), jwks)
  if (length(matches) != 1L) stop("No se encontr\u00f3 una clave OIDC confiable.", call. = FALSE)
  # jose verifies the cryptographic signature, not just the JWT payload.
  key <- jose::read_jwk(jsonlite::toJSON(matches[[1L]], auto_unbox = TRUE))
  claims <- jose::jwt_decode_sig(id_token, key)
  now <- as.numeric(Sys.time())
  if (!identical(claims$iss, "https://auth.openai.com") ||
      !(client_id %in% unlist(claims$aud, use.names = FALSE)) ||
      !identical(claims$nonce, nonce) ||
      is.null(claims$sub) || !nzchar(claims$sub) ||
      is.null(claims$exp) || as.numeric(claims$exp) <= now ||
      (!is.null(claims$nbf) && as.numeric(claims$nbf) > now + 60)) {
    stop("ID token OIDC no super\u00f3 la validaci\u00f3n de identidad.", call. = FALSE)
  }
  claims
}

.oauth_callback <- function(req, pending) {
  headers <- list("Content-Type" = "text/plain; charset=utf-8",
                  "Cache-Control" = "no-store", "Referrer-Policy" = "no-referrer")
  if (!identical(req$PATH_INFO, "/auth/callback") ||
      !identical(req$REQUEST_METHOD, "GET")) {
    return(list(status = 404L, body = "Not found", headers = headers))
  }
  # parseQueryString is a public Shiny function, not an httpuv export.
  params <- tryCatch(shiny::parseQueryString(req$QUERY_STRING %||% ""),
                     error = function(e) NULL)
  if (is.null(params) || anyDuplicated(names(params)) ||
      !identical(params$state, pending$state)) {
    return(list(status = 400L, headers = headers,
                body = "Retorno OAuth no valido. Cierra esta pestana e inicia una nueva conexion."))
  }
  # Retain the code in R only; remove it from the browser's visible address.
  pending$callback <- params
  headers[["Content-Type"]] <- "text/html; charset=utf-8"
  list(status = 200L, headers = headers,
       body = paste0("<!doctype html><html lang='es'><head><meta charset='utf-8'>",
                     "<title>rcodeagent</title><script>history.replaceState(null,'',",
                     "location.pathname);</script></head><body><h2>rcodeagent</h2>",
                     "<p>Autorizacion recibida; la conexion aun no esta confirmada. Regresa a RStudio para comprobar el resultado.</p>",
                     "</body></html>"))
}

.oauth_start <- function(new_account = FALSE) {
  if (!is.logical(new_account) || length(new_account) != 1L || is.na(new_account)) stop("Selecci\u00f3n de cuenta no v\u00e1lida.")
  identity <- .oauth_with_lock(list(credential = .oauth_credential() %||% .oauth_registration(), host = .oauth_host_id()))
  if (new_account && !is.null(.oauth_with_lock(.oauth_credential()))) stop("Desconecta la cuenta actual antes de usar otra.")
  old <- if (new_account) NULL else identity$credential
  pending <- new.env(parent = emptyenv())
  pending$state <- .oauth_random()
  pending$nonce <- .oauth_random()
  pending$verifier <- .oauth_random(48L)
  digest <- openssl::sha256(charToRaw(pending$verifier))
  pending$challenge <- gsub("=+$", "", chartr("+/", "-_", openssl::base64_encode(digest)))
  pending$created_at <- Sys.time()
  pending$callback <- NULL
  pending$server <- NULL

  # Bind on loopback BEFORE sending the user to OpenAI.
  for (i in seq_len(8L)) {
    port <- if (i == 1L) 1455L else httpuv::randomPort()
    listener <- tryCatch(httpuv::startServer("127.0.0.1", port, list(call = function(req) {
      .oauth_callback(req, pending)
    })), error = function(e) NULL)
    if (!is.null(listener)) break
  }
  if (is.null(listener)) stop("No se pudo abrir un puerto de retorno OAuth en 127.0.0.1.")
  pending$server <- listener
  pending$redirect_uri <- paste0("http://127.0.0.1:", port, "/auth/callback")
  pending$old <- old
  pending$client_id <- if (is.null(old)) "dynamic_agent_client" else old$client_id
  values <- list(
    client_id = pending$client_id,
    redirect_uri = pending$redirect_uri,
    response_type = "code", scope = .oauth_scopes,
    resource = .oauth_resource, state = pending$state, nonce = pending$nonce,
    ext_agent_host_id = identity$host,
    code_challenge_method = "S256", code_challenge = pending$challenge
  )
  if (is.null(old)) {
    values$agent_name_hint <- "rcodeagent"
  } else {
    # Do not log this URL because it may contain an ID-token hint.
    if (!is.null(old$id_token) && nzchar(old$id_token)) values$id_token_hint <- old$id_token
    if (!is.null(old$email) && nzchar(old$email)) values$login_hint <- old$email
  }
  utils::browseURL(paste0(.oauth_auth, "?", .oauth_query(values)))
  pending
}

`%||%` <- function(a, b) if (is.null(a)) b else a

.oauth_stop <- function(pending) {
  if (!is.null(pending) && !is.null(pending$server)) {
    try(httpuv::stopServer(pending$server), silent = TRUE)
    pending$server <- NULL
  }
  invisible(NULL)
}

.oauth_finish <- function(pending) .oauth_with_lock({
  params <- pending$callback
  if (is.null(params)) stop("El navegador a\u00fan no ha devuelto la autorizaci\u00f3n.")
  if (as.numeric(difftime(Sys.time(), pending$created_at, units = "secs")) > 600) {
    stop("El intento OAuth expir\u00f3. Repite el inicio de sesi\u00f3n.", call. = FALSE)
  }
  if (!identical(params$state, pending$state)) stop("Estado OAuth inv\u00e1lido.")
  if (identical(params$error, "access_denied")) stop(structure(
    list(message = "Inicio de sesi\u00f3n cancelado o denegado.", call = NULL),
    class = c("rcodeagent_auth_cancelled", "error", "condition")))
  if (!is.null(params$error)) stop("Inicio de sesi\u00f3n cancelado o denegado.", call. = FALSE)
  if (is.null(params$code) || !nzchar(params$code)) stop("No se recibi\u00f3 el c\u00f3digo OAuth.")
  client_id <- if (identical(pending$client_id, "dynamic_agent_client")) {
    if (is.null(params$client_id) || !startsWith(params$client_id, "oaiapp_")) {
      stop("Registro din\u00e1mico de cliente OAuth incompleto.")
    }
    params$client_id
  } else {
    if (!is.null(params$client_id) && !identical(params$client_id, pending$client_id)) {
      stop("El cliente OAuth devuelto no coincide con el autorizado.")
    }
    pending$client_id
  }
  req <- httr2::request(.oauth_token) |>
    httr2::req_options(followlocation = FALSE) |>
    httr2::req_body_form(
      grant_type = "authorization_code", code = params$code,
      redirect_uri = pending$redirect_uri, client_id = client_id,
      code_verifier = pending$verifier, resource = .oauth_resource
    ) |> httr2::req_timeout(30)
  data <- httr2::resp_body_json(.connection_request(req, "oauth"), simplifyVector = FALSE)
  data <- .oauth_token_data(data)
  claims <- .oauth_validate_id(data$id_token, client_id, pending$nonce)
  if (!is.null(pending$old) && !identical(claims$sub, pending$old$subject)) {
    stop("La cuenta autenticada no corresponde a la sesi\u00f3n anterior.", call. = FALSE)
  }
  scopes <- strsplit(data$scope %||% "", " +")[[1L]]
  if (!("chatgpt.tokens.use.direct" %in% scopes)) {
    stop("La cuenta inici\u00f3 sesi\u00f3n, pero no autoriz\u00f3 usar el plan ChatGPT.", call. = FALSE)
  }
  cred <- list(
    client_id = client_id, ext_agent_host_id = .oauth_host_id(),
    issuer = claims$iss, subject = claims$sub, email = claims$email %||% "",
    id_token = data$id_token, access_token = data$access_token,
    refresh_token = data$refresh_token, scopes = scopes,
    expires_at = as.numeric(Sys.time()) + as.numeric(data$expires_in %||% 3600L),
    earliest_refresh_at = data$earliest_refresh_at %||% NULL
  )
  .oauth_save(cred)
  cred
})

.oauth_get_token <- function() .oauth_with_lock({
  cred <- .oauth_credential()
  if (is.null(cred)) stop("Primero pulsa 'Conectar con ChatGPT'.", call. = FALSE)
  if (!("chatgpt.tokens.use.direct" %in% unlist(cred$scopes))) {
    stop("Falta permiso para usar el plan de ChatGPT.", call. = FALSE)
  }
  if (as.numeric(cred$expires_at) < as.numeric(Sys.time()) + 120) {
    if (is.null(cred$refresh_token) || !nzchar(cred$refresh_token)) {
      stop("Sesi\u00f3n expirada. Vuelve a iniciar sesi\u00f3n.", call. = FALSE)
    }
    data <- tryCatch(.oauth_refresh_request(cred), rcodeagent_auth_terminal = function(e) {
      # Auxiliary metadata must never prevent invalid-token removal.
      tryCatch(.oauth_save_registration(cred), error = function(e) NULL)
      .oauth_drop_tokens()
      stop(e)
    })
    cred$access_token <- data$access_token
    cred$refresh_token <- data$refresh_token
    cred$expires_at <- as.numeric(Sys.time()) + as.numeric(data$expires_in %||% 3600L)
    cred$earliest_refresh_at <- data$earliest_refresh_at %||% NULL
    if (!is.null(data$scope)) cred$scopes <- strsplit(data$scope, " +")[[1L]]
    .oauth_save(cred)
  }
  if (!("chatgpt.tokens.use.direct" %in% unlist(cred$scopes))) {
    stop("Falta permiso para usar el plan de ChatGPT. Vuelve a autorizar la cuenta.", call. = FALSE)
  }
  cred$access_token
})

#' Show the authentication status without revealing credentials
#' @export
rcodeagent_status <- function() {
  x <- .oauth_with_lock(.oauth_credential())
  if (is.null(x)) return("Sin conexi\u00f3n. Pulsa 'Conectar con ChatGPT'.")
  paste0("Sesi\u00f3n OAuth local: ", x$email %||% "cuenta conectada",
         " \u00b7 Permiso del plan: ",
         if ("chatgpt.tokens.use.direct" %in% unlist(x$scopes)) "concedido" else "no concedido")
}

#' Open rcodeagent and sign in via a browser (no CLI needed)
#' @export
rcodeagent_login <- function() rcodeagent()

.oauth_disconnect <- function() .oauth_with_lock({
  cred <- tryCatch(.oauth_credential(), error = function(e) NULL)
  remote_revoked <- FALSE
  registration_preserved <- TRUE
  if (!is.null(cred)) {
    registration_preserved <- tryCatch({ .oauth_save_registration(cred); TRUE }, error = function(e) FALSE)
    remote_revoked <- tryCatch(.oauth_revoke(cred), error = function(e) FALSE)
  }
  .oauth_drop_tokens()
  invisible(list(remote_revoked = remote_revoked, local_removed = TRUE, registration_preserved = registration_preserved))
})
