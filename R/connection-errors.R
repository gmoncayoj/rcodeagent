# Keep connection diagnostics useful without copying response bodies or credentials.
.connection_request <- function(request, stage = c("oauth", "models", "identity")) {
  stage <- match.arg(stage)
  response <- httr2::req_perform(request |>
    httr2::req_options(followlocation = FALSE) |>
    httr2::req_error(is_error = function(resp) FALSE))
  status <- httr2::resp_status(response)
  if (status < 300L) return(response)
  body <- tryCatch(httr2::resp_body_json(response, simplifyVector = FALSE), error = function(e) NULL)
  code <- NULL
  shape <- "other"
  if (is.list(body)) {
    if (is.list(body$error)) {
      shape <- "error_object"
      code <- body$error$code %||% body$error$type
    } else if (is.character(body$error)) {
      shape <- "error_string"
      code <- body$error
    } else if (!is.null(body$detail)) shape <- "detail"
  }
  allowed_codes <- c("invalid_request", "invalid_grant", "invalid_client", "invalid_scope",
    "unauthorized_client", "unsupported_grant_type", "access_denied", "server_error",
    "temporarily_unavailable", "invalid_token", "insufficient_scope", "model_not_found",
    "subscription_sharing_user_not_eligible", "subscription_sharing_usage_limit_exceeded",
    "subscription_sharing_usage_unavailable", "subscription_sharing_unsupported_capability",
    "subscription_sharing_route_not_supported", "subscription_sharing_invalid_user",
    "subscription_sharing_user_unavailable", "chatpass_v2_scope_not_authorized",
    "chatpass_v2_invalid_authorization_context")
  if (!is.character(code) || length(code) != 1L || is.na(code) || !(code %in% allowed_codes)) code <- NULL
  request_id <- httr2::resp_header(response, "x-request-id") %||% httr2::resp_header(response, "request-id")
  if (!is.character(request_id) || length(request_id) != 1L || is.na(request_id) ||
      !grepl("^(req[-_][A-Za-z0-9_-]{1,100}|[A-Fa-f0-9]{8}-[A-Fa-f0-9]{4}-[A-Fa-f0-9]{4}-[A-Fa-f0-9]{4}-[A-Fa-f0-9]{12})$", request_id)) request_id <- NULL
  error <- structure(list(message = "OpenAI connection request failed.", call = NULL,
    stage = stage, status = status, provider_code = code, request_id = request_id, body_shape = shape),
    class = c("rcodeagent_connection_http_error", "error", "condition"))
  error$message <- .connection_error_message(error, "en")
  stop(error)
}

.connection_error_message <- function(error, language = "en") {
  if (!inherits(error, "rcodeagent_connection_http_error")) return(.request_error_message(error))
  english <- identical(language, "en")
  stages <- if (english) c(oauth = "OAuth token exchange", models = "Model catalog", identity = "Identity verification keys") else
    c(oauth = "Intercambio OAuth", models = "Cat\u00e1logo de modelos", identity = "Claves de verificaci\u00f3n de identidad")
  parts <- c(unname(stages[[error$stage]]), paste("HTTP", error$status),
    if (!is.null(error$provider_code)) paste0(if (english) "code: " else "c\u00f3digo: ", error$provider_code),
    if (!is.null(error$request_id)) paste0("request ID: ", error$request_id),
    paste0(if (english) "response: " else "respuesta: ", error$body_shape))
  paste0(if (english) "OpenAI connection failed. " else "Fall\u00f3 la conexi\u00f3n con OpenAI. ", paste(parts, collapse = "; "), ".")
}
