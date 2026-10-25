# Real app/lifecycle/workers, synthetic provider and editor; no OAuth/network calls.
pkgload::load_all(".", quiet = TRUE)
directory <- Sys.getenv("RCODEAGENT_RECOVERY_QA_DIR")
stopifnot(nzchar(directory), dir.exists(directory))
options(rcodeagent.history_dir = file.path(directory, "history"),
  rcodeagent.preferences_file = file.path(directory, "preferences.json"))
snapshot <- list(id = "qa-recovery", path = "", full = "qa_value <- 1", text = "qa_value <- 1",
  range = NULL, scope = "documento")
writes <- 0L
executions <- character()
record <- function() jsonlite::write_json(list(writes = writes, value = snapshot$full, executions = as.list(executions)),
  file.path(directory, "editor.json"), auto_unbox = TRUE)
record()
real_start <- rcodeagent:::.start_request
table_port <- httpuv::randomPort()
table_server <- httpuv::startServer("127.0.0.1", table_port, list(call = function(req) {
  if (identical(req$PATH_INFO, "/change")) {
    snapshot$full <<- "qa_value <- 999"
    snapshot$text <<- snapshot$full
    record()
  }
  list(status = 200L, headers = list("Content-Type" = "text/html; charset=utf-8"),
    body = '<!doctype html><html lang="es"><head><title>Resultado sintético</title></head><body><h1>Tabla sintética en Viewer</h1><table><tr><th>Variable</th><th>M</th></tr><tr><td>Prueba</td><td>2.00</td></tr></table></body></html>')
}))
jsonlite::write_json(list(url = paste0("http://127.0.0.1:", table_port)),
  file.path(directory, "table.json"), auto_unbox = TRUE)
tryCatch(testthat::with_mocked_bindings(
  rcodeagent:::.run_background_app(file.path(directory, "state.json")),
  .rstudio_call = function(method, ...) {
    if (identical(method, "isAvailable")) return(TRUE)
    if (identical(method, "getConsoleEditorContext")) return(list(id = "#console", contents = ""))
    if (identical(method, "getSourceEditorContext")) return(list(id = snapshot$id, path = snapshot$path, contents = snapshot$full))
    if (identical(method, "sendToConsole")) {
      executions <<- c(executions, list(...)$code)
      record()
      return(invisible(NULL))
    }
    stopifnot(identical(method, "viewer"))
    jsonlite::write_json(list(url = list(...)$url), file.path(directory, "launch.json"), auto_unbox = TRUE)
    invisible(NULL)
  },
  .snapshot_editor = function(id = NULL) {
    if (!is.null(id)) stopifnot(identical(id, "qa-recovery"))
    snapshot
  },
  rcodeagent_status = function() "Prueba sintética, sin OpenAI",
  .models_for_account = function() c("Modelo A" = "qa-recovery-a", "Modelo B" = "qa-recovery-b"),
  .oauth_start = function() stop("Prueba sin acceso a OpenAI"),
  .safe_editor_apply = function(captured, code) {
    stopifnot(identical(captured$id, snapshot$id), identical(captured$full, snapshot$full))
    writes <<- writes + 1L
    snapshot$full <<- code
    snapshot$text <<- code
    record()
  },
  .start_request = function(prompt, model, can_edit, mode, effort) real_start(prompt, model, can_edit, mode, effort,
    worker_reply = function(prompt, model, can_edit, mode, effort) {
      if (can_edit && identical(mode, "auto") &&
          (grepl("Solicitud:\nBorra toda la línea 1 del script abierto", prompt, fixed = TRUE) ||
           grepl("Solicitud:\nVacía el documento", prompt, fixed = TRUE))) {
        return(testthat::with_mocked_bindings(
          rcodeagent:::.assistant_reply(prompt, model, can_edit, mode, effort),
          .responses_stream = function(...) list(text = "", calls = list(list(name = "propose_editor_edit",
            arguments = '{"explanation":"Eliminar todo el contexto solicitado.","code":""}'))),
          .package = "rcodeagent"))
      }
      if (grepl("Solicitud:\nRespuesta lenta", prompt, fixed = TRUE)) Sys.sleep(25)
      if (can_edit && identical(mode, "auto") && grepl("Solicitud:\nEjecuta una operación administrativa sintética", prompt, fixed = TRUE)) {
        return(list(action = "execute", message = "Operación sintética para revisar", code = 'unlink("rcodeagent-synthetic-never-touched")'))
      }
      if (can_edit && identical(mode, "auto") && grepl("Solicitud:\nGenera y ejecuta un ejemplo", prompt, fixed = TRUE)) {
        return(list(action = "execute", message = "Ejemplo para revisar", code = "qa_run <- 7"))
      }
      value <- if (grepl("qa_value <- 3", prompt, fixed = TRUE)) 4L else if (grepl("qa_value <- 2", prompt, fixed = TRUE)) 3L else 2L
      if (can_edit && identical(mode, "auto")) return(list(action = "modify",
        message = paste("Código sintético preparado", value), code = paste("qa_value <-", value)))
      list(action = "chat", message = "Respuesta sintética sin edición.", code = "")
    }), .package = "rcodeagent"), finally = httpuv::stopServer(table_server))
