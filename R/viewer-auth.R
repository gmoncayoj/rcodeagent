.viewer_url_allowed <- function(url, require_capability = FALSE) {
  if (!is.character(url) || length(url) != 1L || is.na(url)) return(FALSE)
  pattern <- "^http://127[.]0[.]0[.]1:([0-9]{1,5})/?(#rcodeagent=[a-f0-9]{64})?$"
  match <- regexec(pattern, url, perl = TRUE)
  parts <- regmatches(url, match)[[1L]]
  length(parts) > 1L && as.integer(parts[[2L]]) > 0L && as.integer(parts[[2L]]) <= 65535L &&
    (!require_capability || grepl("#rcodeagent=[a-f0-9]{64}$", url))
}

.viewer_request_allowed <- function(request, origin) {
  if (!.viewer_url_allowed(paste0(origin, "/"))) return(FALSE)
  host <- request$HTTP_HOST
  source <- request$HTTP_ORIGIN
  is.character(host) && length(host) == 1L && !is.na(host) &&
    identical(host, sub("^http://", "", origin)) &&
    (is.null(source) || (is.character(source) && length(source) == 1L && !is.na(source) && identical(source, origin)))
}

.viewer_client_allowed <- function(request, fragment, origin, capability) {
  .viewer_request_allowed(request, origin) && is.character(capability) && length(capability) == 1L &&
    !is.na(capability) && grepl("^[a-f0-9]{64}$", capability) &&
    is.character(fragment) && length(fragment) == 1L && !is.na(fragment) &&
    identical(fragment, paste0("#rcodeagent=", capability))
}
