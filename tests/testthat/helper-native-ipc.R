# Actual child process, synthetic native-channel files, no RStudio or real credentials.
.native_ipc_fixture <- function(mode = "delayed", write = FALSE) {
  root <- tempfile("native-ipc-")
  dir.create(root)
  request <- file.path(root, "request.rds")
  response <- file.path(root, "response.rds")
  package_path <- getNamespaceInfo(asNamespace("rcodeagent"), "path")
  child <- callr::r_bg(function(package_path, libraries, request, response, write, mode) {
    .libPaths(libraries)
    if (file.exists(file.path(package_path, "R", "addin.R"))) pkgload::load_all(package_path, quiet = TRUE) else {
      loadNamespace("rcodeagent", lib.loc = dirname(package_path))
    }
    Sys.setenv(RSTUDIOAPI_IPC_REQUESTS_FILE = request, RSTUDIOAPI_IPC_RESPONSE_FILE = response,
      RSTUDIOAPI_IPC_SHARED_SECRET = "synthetic-test-only")
    options(rstudioapi.remote.timeout = if (mode %in% c("timeout", "malformed")) .25 else 3)
    lapply(1:2, function(i) tryCatch({
      value <- if (write) rcodeagent:::.rstudio_call("insertText", location = list(start = c(1, 1), end = c(Inf, 1)),
        text = "qa_value <- 2", id = "synthetic-target") else {
        rcodeagent:::.rstudio_call("getSourceEditorContext", id = paste0("synthetic-", i))
      }
      list(ok = TRUE, value = value)
    }, error = function(e) list(ok = FALSE, message = conditionMessage(e), transport = inherits(e, "rcodeagent_ipc_error"))))
  }, args = list(package_path, .libPaths(), request, response, write, mode), supervise = TRUE,
    system_profile = FALSE, user_profile = FALSE, stdout = "|", stderr = "|")
  on.exit({ if (child$is_alive()) child$kill_tree(); unlink(c(request, response)); unlink(root) }, add = TRUE)
  handled <- 0L
  seen <- FALSE
  deadline <- Sys.time() + 12
  while (child$is_alive() && Sys.time() < deadline) {
    if (file.exists(request) && !(mode == "timeout" && seen)) {
      # The polling check can race a client's cleanup; retry a failed read quietly.
      data <- tryCatch(withCallingHandlers(readRDS(request), warning = function(w) invokeRestart("muffleWarning")),
        error = function(e) NULL)
      if (!is.null(data)) {
        seen <- TRUE
        handled <- handled + 1L
        stopifnot(identical(data$secret, "synthetic-test-only"))
        if (mode != "timeout") {
          value <- if (mode == "api_error" && handled == 1L) simpleError("synthetic API error") else {
            if (write || mode == "null") NULL else list(id = data$call$id[[2L]])
          }
          # Official ordering: success response is written before the request acknowledgement.
          early_ack <- mode == "early_ack" || (mode == "api_error" && handled == 1L)
          if (early_ack) unlink(request)
          if (mode == "malformed") writeLines("synthetic corrupt response", response) else {
            con <- gzfile(response, "wb")
            saveRDS(value, con)
            Sys.sleep(.08) # Force a response-file visibility window.
            close(con)
          }
          if (!early_ack) {
            Sys.sleep(.04) # Force the response-before-request-cleanup window.
            unlink(request)
          }
        }
      }
    }
    Sys.sleep(.005)
  }
  child$wait(timeout = 1000)
  if (child$is_alive()) stop("Synthetic native IPC child timed out")
  list(results = child$get_result(), handled = handled)
}
