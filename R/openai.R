# Direct Requests to the public OpenAI API with ChatGPT-plan OAuth credentials.
# This route requires store=false and stream=true.
.models_for_account <- function() {
  token <- .oauth_get_token()
  req <- httr2::request("https://api.openai.com/v1/models") |>
    httr2::req_headers(Authorization = paste("Bearer", token)) |>
    httr2::req_timeout(30)
  data <- httr2::resp_body_json(.connection_request(req, "models"), simplifyVector = FALSE)
  rows <- Filter(function(x) identical(x$visibility, "list") &&
                   !is.null(x$slug), data$models %||% list())
  if (!length(rows)) stop("No se devolvieron modelos visibles para esta cuenta.", call. = FALSE)
  names <- vapply(rows, function(x) x$display_name %||% x$slug, character(1L))
  slugs <- vapply(rows, function(x) x$slug, character(1L))
  models <- stats::setNames(slugs, names)
  attr(models, "details") <- stats::setNames(rows, slugs)
  models
}

.validate_effort <- function(value) {
  if (!is.character(value) || length(value) != 1L || is.na(value) ||
      !(value %in% c("low", "medium", "high", "xhigh"))) {
    stop("Selecciona un esfuerzo: Bajo, Medio, Alto o Muy alto.", call. = FALSE)
  }
  value
}

.response_body <- function(prompt, model, tools = NULL, effort = "medium") {
  if (!nzchar(model)) stop("Selecciona un modelo del cat\u00e1logo de tu cuenta.", call. = FALSE)
  body <- list(model = model,
               input = list(list(role = "user", content = prompt)),
               store = FALSE, stream = TRUE,
               reasoning = list(effort = .validate_effort(effort)))
  if (!is.null(tools)) {
    body$tools <- tools
    body$tool_choice <- "auto"
    body$parallel_tool_calls <- FALSE
  }
  body
}

.responses_stream <- function(prompt, model, tools = NULL, effort = "medium") {
  body <- .response_body(prompt, model, tools, effort)
  token <- .oauth_get_token()
  req <- httr2::request("https://api.openai.com/v1/responses") |>
    httr2::req_headers(
      Authorization = paste("Bearer", token),
      Accept = "text/event-stream"
    ) |>
    httr2::req_body_json(body, auto_unbox = TRUE) |>
    httr2::req_timeout(180)
  con <- httr2::req_perform_connection(req)
  on.exit(close(con), add = TRUE)
  .read_response(function() httr2::resp_stream_sse(con), structured = !is.null(tools))
}

.read_response <- function(read_event, structured = FALSE) {
  output <- character()
  items <- list()
  indexes <- list()
  done_text <- character()
  completed <- FALSE
  usage <- NULL
  remember_item <- function(item, index = NULL) {
    if (!is.list(item)) return()
    key <- item$id %||% if (!is.null(index)) {
      indexes[[as.character(index)]] %||% paste0("index_", index)
    } else paste0("anonymous_", length(items) + 1L)
    items[[key]] <<- item
    if (!is.null(index)) indexes[[as.character(index)]] <<- key
  }
  repeat {
    event <- read_event()
    if (is.null(event)) break
    if (identical(event$data, "[DONE]") || !nzchar(event$data)) next
    msg <- tryCatch(jsonlite::fromJSON(event$data, simplifyVector = FALSE),
                    error = function(e) NULL)
    if (is.null(msg)) next
    typ <- msg$type %||% event$type
    if (identical(typ, "response.output_text.delta") && !is.null(msg$delta)) {
      output <- c(output, msg$delta)
    }
    if (typ %in% c("response.output_item.added", "response.output_item.done")) {
      remember_item(msg$item, msg$output_index)
    }
    if (typ %in% c("response.function_call_arguments.delta", "response.function_call_arguments.done")) {
      if (!is.null(msg[["item"]])) {
        remember_item(msg[["item"]], msg$output_index)
      } else {
        key <- msg$item_id %||% indexes[[as.character(msg$output_index)]]
        if (!is.null(key) && identical(items[[key]]$type, "function_call")) {
          item <- items[[key]]
          item$arguments <- if (identical(typ, "response.function_call_arguments.done")) {
            msg$arguments
          } else paste0(item$arguments %||% "", msg$delta %||% "")
          items[[key]] <- item
        }
      }
    }
    if (identical(typ, "response.output_text.done") && is.character(msg$text)) {
      key <- paste(msg$item_id %||% msg$output_index %||% "text", msg$content_index %||% 0L)
      done_text[[key]] <- msg$text
    }
    if (identical(typ, "response.failed") || identical(typ, "response.incomplete") ||
        identical(typ, "error")) {
      code <- msg$response$error$code %||% msg$error$code %||% typ
      stop(paste("OpenAI no complet\u00f3 la respuesta:", code), call. = FALSE)
    }
    if (identical(typ, "response.completed")) {
      usage <- msg$response$usage
      # Merge final items: an empty terminal array must not erase completed events.
      for (i in seq_along(msg$response$output)) {
        remember_item(msg$response$output[[i]], i - 1L)
      }
      completed <- TRUE
      break
    }
  }
  if (!completed) stop("El flujo termin\u00f3 sin el evento response.completed.", call. = FALSE)
  messages <- Filter(function(item) identical(item$type, "message"), items)
  final_text <- unlist(lapply(messages, function(item) {
    vapply(item$content, function(part) {
      if (identical(part$type, "output_text")) part$text %||% "" else if (
        identical(part$type, "refusal")) part$refusal %||% "" else ""
    }, character(1L))
  }), use.names = FALSE)
  text <- if (length(final_text) && any(nzchar(final_text))) paste0(final_text, collapse = "\n") else {
    paste0(if (length(done_text)) done_text else output, collapse = "")
  }
  calls <- unname(Filter(function(item) identical(item$type, "function_call"), items))
  if (structured) list(text = text, calls = calls, usage = usage) else {
    if (!is.null(usage)) attr(text, "usage") <- usage
    text
  }
}
