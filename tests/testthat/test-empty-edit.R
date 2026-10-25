.local_empty_edit <- function(envir = parent.frame()) {
  reply <- .assistant_reply
  editor <- .local_unsaved_editor(envir)
  editor$docs[["unsaved-a"]]$text <- "qa_value <- 1"
  testthat::local_mocked_bindings(.assistant_reply = reply,
    .responses_stream = function(..., tools = NULL) if (is.null(tools)) "Código solo en el chat" else list(text = "", calls = list(list(name = "propose_editor_edit",
      arguments = '{"explanation":"Eliminar todo el contexto solicitado.","code":""}'))),
    .package = "rcodeagent", .env = envir)
  editor
}

test_that("an explicit edit proposal can replace its captured context with empty text", {
  call <- list(name = "propose_editor_edit", arguments = '{"explanation":"Eliminar la línea.","code":""}')
  expect_identical(.interpret_response(list(calls = list(call))),
    list(action = "modify", message = "Eliminar la línea.", code = ""))
  call$name <- "propose_new_script"
  expect_error(.interpret_response(list(calls = list(call))), "formato")
  call$name <- "propose_editor_edit"
  for (bad in c('null', '[]', '[""]', '42')) {
    call$arguments <- paste0('{"explanation":"Eliminar la línea.","code":', bad, '}')
    expect_error(.interpret_response(list(calls = list(call))), "formato")
  }
})

test_that("Auto can delete the last line without changing another editor", {
  editor <- .local_empty_edit()
  shiny::testServer(.rcodeagent_server, {
    session$setInputs(mode = "normal", model = "test-model", capture_document = 1)
    session$setInputs(auto_requested = TRUE)
    session$setInputs(submit_request = list(text = "Borra toda la línea 1 del script abierto"))
    expect_length(editor$writes, 1L)
    expect_identical(editor$docs[["unsaved-a"]]$text, "")
    expect_identical(editor$docs[["saved-b"]]$text, "previous <- 99")
    expect_true(history()[[2L]]$edit_applied)
    expect_true(auto_mode())
  })
})

test_that("Normal cannot delete a document through old manual edit controls", {
  editor <- .local_empty_edit()
  shiny::testServer(.rcodeagent_server, {
    session$setInputs(mode = "normal", model = "test-model", capture_document = 1)
    session$setInputs(submit_request = list(text = "Vacía el documento"))
    expect_equal(output$has_proposal, "false")
    expect_equal(output$can_edit, "false")
    session$setInputs(apply = 1, confirm_apply = 1)
    expect_length(editor$writes, 0L)
    expect_identical(editor$docs[["unsaved-a"]]$text, "qa_value <- 1")
  })
})


test_that("empty replacement still requires a shared target", {
  .local_empty_edit()
  expect_error(.assistant_reply("Eliminar", "test-model", can_edit = FALSE, mode = "auto"), "documento compartido")
})

test_that("an empty reviewed edit cannot overwrite a manual change", {
  editor <- .local_empty_edit()
  shiny::testServer(.rcodeagent_server, {
    session$setInputs(mode = "normal", model = "test-model", capture_document = 1)
    session$setInputs(submit_request = list(text = "Vacía el documento"))
    session$setInputs(apply = 1)
    editor$docs[["unsaved-a"]]$text <- "manual <- 99"
    session$setInputs(confirm_apply = 1)
    expect_length(editor$writes, 0L)
    expect_identical(editor$docs[["unsaved-a"]]$text, "manual <- 99")
  })
})

test_that("deleting a selection sends empty text only to the captured range", {
  written <- NULL
  full <- "qa_value <- 1\nkeep <- 2"
  range <- list(start = c(1L, 1L), end = c(2L, 1L))
  testthat::local_mocked_bindings(.rstudio_call = function(method, ...) {
    if (method == "getSourceEditorContext") return(list(id = "selected", path = "", contents = strsplit(full, "\n")[[1]]))
    written <<- c(list(method = method), list(...))
  }, .package = "rcodeagent")
  .safe_editor_apply(list(id = "selected", path = "", text = "qa_value <- 1\n", full = full, range = range), "")
  expect_identical(written, list(method = "insertText", location = range, text = "", id = "selected"))
})
