.start_request <- function(prompt, model, can_edit, mode, effort, worker_reply = NULL) {
  package_path <- getNamespaceInfo(asNamespace("rcodeagent"), "path")
  callr::r_bg(function(package_path, libraries, prompt, model, can_edit, mode, effort, worker_reply, storage_profile) {
    Sys.unsetenv(c("RSTUDIOAPI_IPC_REQUESTS_FILE", "RSTUDIOAPI_IPC_RESPONSE_FILE",
      "RSTUDIOAPI_IPC_SHARED_SECRET", "RSTUDIO_WORKBENCH_JOB"))
    .libPaths(libraries)
    if (file.exists(file.path(package_path, "R", "addin.R"))) {
      pkgload::load_all(package_path, quiet = TRUE) # Source checkout during development only.
    } else loadNamespace("rcodeagent", lib.loc = dirname(package_path))
    if (!is.character(storage_profile) || length(storage_profile) != 1L || is.na(storage_profile) ||
        !(storage_profile %in% c("rcodeagent", paste0("RStudio", "GPT")))) {
      stop("Perfil de almacenamiento no v\u00e1lido.")
    }
    # Pass only the profile identity, never credentials or a native IPC channel.
    storage <- get(".storage_state", envir = asNamespace("rcodeagent"))
    storage$app <- storage_profile
    reply <- if (is.null(worker_reply)) get(".assistant_reply", envir = asNamespace("rcodeagent")) else worker_reply
    reply(prompt, model, can_edit, mode, effort)
  }, args = list(package_path, .libPaths(), prompt, model, can_edit, mode, effort, worker_reply, .storage_app_name()),
    supervise = TRUE, stdout = "|", stderr = "|", system_profile = FALSE, user_profile = FALSE)
}

.request_error_message <- function(error) {
  # callr adds a terminal-formatted wrapper around the actual worker condition.
  if (inherits(error, "callr_error") && inherits(error$parent, "condition")) error <- error$parent
  gsub("\033\\[[0-?]*[ -/]*[@-~]", "", conditionMessage(error), perl = TRUE)
}

.cancel_request <- function(job) {
  if (!is.null(job) && job$is_alive()) {
    if (is.function(job$kill_tree)) job$kill_tree() else job$kill()
  }
  invisible(TRUE)
}
