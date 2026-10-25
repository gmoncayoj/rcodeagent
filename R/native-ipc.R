# Narrow client for the native RStudio Job channel, not an arbitrary-code bridge.
.native_ipc_state <- new.env(parent = emptyenv())

.native_api_data <- function(value) {
  if (is.null(value)) return(TRUE)
  if (any(!names(attributes(value)) %in% c("names", "class"))) return(FALSE)
  if (is.object(value) && !all(class(value) %in% c("document_range", "document_position"))) return(FALSE)
  if (typeof(value) == "list") return(all(vapply(value, .native_api_data, logical(1L))))
  typeof(value) %in% c("logical", "integer", "double", "character")
}

.native_api_expression <- function(method, args) {
  signatures <- list(isAvailable = c("version_needed", "child_ok"), getSourceEditorContext = "id",
    insertText = c("location", "text", "id"), documentOpen = c("path", "line", "col", "moveCursor"),
    documentNew = c("text", "type", "position", "execute"), documentClose = c("id", "save"),
    selectFile = c("caption", "label", "path", "filter", "existing"), getActiveProject = character(),
    viewer = c("url", "height"), getConsoleEditorContext = character(),
    sendToConsole = c("code", "execute", "echo", "focus", "animate"))
  if (!is.character(method) || length(method) != 1L || is.na(method) || !(method %in% names(signatures))) {
    stop("Llamada al editor no permitida.", call. = FALSE)
  }
  if (!is.list(args) || (length(args) && (is.null(names(args)) || anyNA(names(args)) ||
      any(!nzchar(names(args))) || anyDuplicated(names(args)) || any(!names(args) %in% signatures[[method]])))) {
    stop("Los argumentos de la API del editor no est\u00e1n permitidos.", call. = FALSE)
  }
  if (!all(vapply(args, .native_api_data, logical(1L)))) stop("La API del editor solo admite datos.", call. = FALSE)
  if (method == "documentNew" && !isFALSE(args$execute %||% FALSE)) stop("No se permite ejecutar c\u00f3digo.", call. = FALSE)
  if (method == "sendToConsole") {
    if (!setequal(names(args), signatures$sendToConsole) || !isTRUE(args$execute) || !isTRUE(args$echo) ||
        !isFALSE(args$focus) || !isFALSE(args$animate)) stop("La operaci\u00f3n de consola solo admite sus argumentos fijos.", call. = FALSE)
    .execution_text(args$code)
  }
  if (method == "viewer" && !.viewer_url_allowed(args$url)) {
    stop("El Viewer solo admite la direcci\u00f3n local del complemento.", call. = FALSE)
  }
  # Only these fixed public functions can be represented on the native channel.
  # Quote all values, so a payload can never become an executable expression.
  head <- call("::", as.name("rstudioapi"), as.name(if (method == "insertText") "callFun" else method))
  if (method == "insertText") args <- c(list("insertText"), args)
  quoted <- lapply(args, function(value) call("quote", value))
  as.call(c(list(head), quoted))
}

.rstudio_call <- function(method, ...) {
  args <- list(...)
  .native_api_expression(method, args) # Validate before invoking either public API path.
  if (!rstudioapi::isBackgroundJob()) {
    if (method == "insertText") return(do.call(rstudioapi::callFun, c(list("insertText"), args)))
    return(do.call(getExportedValue("rstudioapi", method), args))
  }
  .native_api_request(method, args,
    timeout = if (method == "selectFile") 120 else getOption("rstudioapi.remote.timeout", 10))
}

.native_api_request <- function(method, args, timeout = 10) {
  request_call <- .native_api_expression(method, args)
  write <- identical(method, "insertText")
  stage <- "validate_channel"
  effect <- method %in% c("insertText", "documentOpen", "documentNew", "documentClose", "sendToConsole")
  fail <- function(message) {
    .native_ipc_state$failed <- TRUE
    stop(structure(list(message = message, call = NULL, native_stage = stage, effect_uncertain = effect && owned),
      class = c("rcodeagent_ipc_error", "error", "condition")))
  }
  owned <- FALSE
  completed <- FALSE
  if (isTRUE(.native_ipc_state$failed)) fail("El canal del editor requiere reiniciar rcodeagent. Cierra el complemento y vuelve a abrirlo.")
  if (isTRUE(.native_ipc_state$busy)) fail("Ya hay una operaci\u00f3n del editor en curso. Reinicia rcodeagent.")
  .native_ipc_state$busy <- TRUE
  temporary <- NULL
  request <- Sys.getenv("RSTUDIOAPI_IPC_REQUESTS_FILE", unset = "")
  response <- Sys.getenv("RSTUDIOAPI_IPC_RESPONSE_FILE", unset = "")
  on.exit({
    if (owned && !completed) .native_ipc_state$failed <- TRUE
    .native_ipc_state$busy <- FALSE
    if (!is.null(temporary)) unlink(temporary)
    if (owned) unlink(c(request, response))
  }, add = TRUE)
  secret <- Sys.getenv("RSTUDIOAPI_IPC_SHARED_SECRET", unset = "")
  if (!nzchar(request) || !nzchar(response) || !nzchar(secret) || identical(request, response) ||
      !dir.exists(dirname(request)) || !dir.exists(dirname(response))) fail("No hay un canal nativo v\u00e1lido con RStudio.")
  if (file.exists(request) || file.exists(response)) fail("El canal del editor tiene una operaci\u00f3n incompleta. Reinicia rcodeagent.")
  if (!is.numeric(timeout) || length(timeout) != 1L || !is.finite(timeout) || timeout <= 0) timeout <- 10
  temporary <- tempfile("rcodeagent-request-", tmpdir = dirname(request))
  stage <- "publish_request"
  tryCatch({
    saveRDS(list(secret = secret, call = request_call), temporary)
    if (!file.rename(temporary, request)) fail("No se pudo publicar la solicitud al editor.")
  }, error = function(e) {
    if (inherits(e, "rcodeagent_ipc_error")) stop(e)
    fail("No se pudo abrir el canal de solicitud del editor.")
  })
  owned <- TRUE
  stage <- "await_acknowledgement"
  deadline <- Sys.time() + timeout
  repeat {
    # Native RStudio removes the request after closing a successful response.
    # For an error it acknowledges first; read that same response until complete.
    if (!file.exists(request) && file.exists(response)) {
      stage <- "read_response"
      read <- tryCatch(withCallingHandlers(list(ok = TRUE, value = readRDS(response)),
        warning = function(w) invokeRestart("muffleWarning")), error = function(e) list(ok = FALSE))
      if (isTRUE(read$ok)) {
        completed <- TRUE
        if (inherits(read$value, "error")) stop(read$value)
        return(read$value)
      }
    }
    if (Sys.time() >= deadline) {
      fail(if (write) paste("No se pudo confirmar la escritura en RStudio; podr\u00eda haberse aplicado.",
        "Auto se desactiva. Revisa el destino y reinicia el complemento antes de reintentar.") else if (effect) {
        paste("RStudio no confirm\u00f3 la operaci\u00f3n del editor a tiempo.",
          "La operaci\u00f3n podr\u00eda haberse aplicado. Revisa el editor antes de reintentar. Reinicia el complemento.")
      } else "RStudio no confirm\u00f3 la operaci\u00f3n del editor a tiempo. Reinicia el complemento.")
    }
    Sys.sleep(.01)
  }
}
