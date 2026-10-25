.local_unsaved_editor <- function(envir = parent.frame()) {
  .local_jobs(envir)
  editor <- new.env(parent = emptyenv())
  editor$current <- "unsaved-a"
  editor$docs <- list("unsaved-a" = list(path = "", text = ""),
    "saved-b" = list(path = "previous.R", text = "previous <- 99"))
  editor$writes <- list()
  editor$can_edit <- NULL
  editor$prompt <- NULL
  testthat::local_mocked_bindings(
    isAvailable = function(...) TRUE,
    getSourceEditorContext = function(id = NULL) {
      if (is.null(id)) id <- editor$current
      doc <- editor$docs[[id]]
      structure(list(id = id, path = doc$path, contents = doc$text,
        selection = structure(list(list(text = "", range = rstudioapi::document_range(c(1, 1, 1, 1)))),
          class = "document_selection")), class = "document_context")
    },
    callFun = function(fname, location, text, id) {
      stopifnot(identical(fname, "insertText"), identical(id, "unsaved-a"))
      editor$writes[[length(editor$writes) + 1L]] <- list(id = id, text = text, location = location)
      editor$docs[[id]]$text <- text
    }, .package = "rstudioapi", .env = envir)
  testthat::local_mocked_bindings(rcodeagent_status = function() "Prueba local",
    .models_for_account = function() c(Test = "test-model"),
    .assistant_reply = function(prompt, model, can_edit, mode, effort) {
      editor$can_edit <- can_edit
      editor$prompt <- prompt
      list(action = if (can_edit) "modify" else "chat", message = "Propuesta sintética", code = if (can_edit) "qa_value <- 2" else "")
    }, .package = "rcodeagent", .env = envir)
  editor
}

