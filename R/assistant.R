# Model-selected proposals. No tool directly writes files or executes R.
.assistant_tools <- function(can_edit = TRUE) {
  proposal <- function(name, description) list(
    type = "function", name = name, description = description, strict = TRUE,
    parameters = list(type = "object", additionalProperties = FALSE,
      properties = list(
        explanation = list(type = "string", description = "Explicaci\u00f3n breve en el idioma solicitado por el usuario."),
        code = list(type = "string", description = "C\u00f3digo R completo, sin bloques Markdown.")),
      required = c("explanation", "code")))
  tools <- list(proposal("propose_new_script", "Proponer un script R nuevo solicitado por el usuario, sin ejecutarlo."))
  tools <- c(tools, list(proposal("propose_execution",
    "Proponer c\u00f3digo R para ejecuci\u00f3n solicitada expresamente en el mensaje actual. En Auto el servidor lo enviar\u00e1 sin otra confirmaci\u00f3n, tras validar destino y permisos. Esta herramienta no ejecuta nada por s\u00ed misma.")))
  if (can_edit) tools <- c(list(proposal("propose_editor_edit",
    "Proponer el reemplazo completo de la selecci\u00f3n o documento compartido cuando el usuario solicita editarlo en Auto. La cadena vac\u00eda elimina todo ese contexto. Nunca ejecuta el c\u00f3digo.")), tools)
  tools
}

.interpret_response <- function(result) {
  calls <- result$calls %||% list()
  text <- result$text %||% ""
  if (!length(calls)) {
    if (!is.character(text) || length(text) != 1L || !nzchar(trimws(text))) {
      stop("El asistente no devolvi\u00f3 una respuesta. Repite la consulta.", call. = FALSE)
    }
    return(list(action = "chat", message = text, code = ""))
  }
  if (length(calls) != 1L) stop("Se recibieron varias propuestas; solicita un cambio a la vez.", call. = FALSE)
  call <- calls[[1L]]
  action <- switch(call$name %||% "", propose_editor_edit = "modify",
                   propose_new_script = "generate", propose_execution = "execute", NULL)
  if (is.null(action)) stop("El asistente solicit\u00f3 una herramienta no autorizada.", call. = FALSE)
  arguments <- tryCatch(jsonlite::fromJSON(call$arguments, simplifyVector = FALSE),
                        error = function(e) NULL)
  scalar_text <- function(x, allow_empty = FALSE) is.character(x) && length(x) == 1L && !is.na(x) &&
    (allow_empty || nzchar(trimws(x)))
  if (!is.list(arguments) || !setequal(names(arguments), c("explanation", "code")) ||
      anyDuplicated(names(arguments)) || !scalar_text(arguments$code, allow_empty = identical(action, "modify")) ||
      !scalar_text(arguments$explanation) || nchar(arguments$code) > 60000L ||
      nchar(arguments$explanation) > 8000L) {
    stop("La propuesta no tiene un formato v\u00e1lido. Solicita el cambio de nuevo.", call. = FALSE)
  }
  tryCatch(parse(text = arguments$code), error = function(e) {
    stop("La propuesta no supera la validaci\u00f3n sint\u00e1ctica de R.", call. = FALSE)
  })
  list(action = action, message = arguments$explanation, code = arguments$code)
}

.assistant_reply <- function(prompt, model, can_edit = TRUE, mode = "normal", effort = "medium") {
  effort <- .validate_effort(effort)
  mode <- .permission_mode(mode)
  if (identical(mode, "normal")) {
    result <- .responses_stream(prompt, model, effort = effort)
    if (!is.character(result) || length(result) != 1L) stop("El modo Normal solo admite respuestas de chat.", call. = FALSE)
    reply <- .interpret_response(list(text = as.character(result), calls = list()))
    reply$usage <- attr(result, "usage")
    return(reply)
  }
  result <- .responses_stream(prompt, model, tools = .assistant_tools(can_edit), effort = effort)
  reply <- .interpret_response(result)
  reply$usage <- result$usage
  if (!can_edit && identical(reply$action, "modify")) {
    stop("No hay un documento compartido que pueda editarse.", call. = FALSE)
  }
  reply
}
