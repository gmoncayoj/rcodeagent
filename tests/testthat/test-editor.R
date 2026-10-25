test_that("streamed proposals change only the captured document after approval", {
  .local_jobs()
  editor <- new.env(parent = emptyenv())
  editor$contents <- "x <- 1"
  editor$writes <- 0L
  testthat::local_mocked_bindings(
    getSourceEditorContext = function(id = NULL) list(id = "test", path = "test.R", contents = editor$contents),
    callFun = function(fname, location, text, id) {
      stopifnot(fname == "insertText")
      stopifnot(id == "test")
      editor$contents <- text
      editor$writes <- editor$writes + 1L
    }, .package = "rstudioapi"
  )
  testthat::local_mocked_bindings(
    .snapshot_editor = function(id = NULL) list(id = "test", path = "test.R", full = editor$contents,
      text = editor$contents, range = NULL, scope = "documento"),
    rcodeagent_status = function() "Sesión de prueba",
    .models_for_account = function() c(Test = "test-model"),
    .responses_stream = function(prompt, model, tools, effort) {
      events <- list(
        list(type = "response.output_item.done", output_index = 0L,
          item = list(id = "fc_test", type = "function_call", name = "propose_editor_edit",
            arguments = '{"explanation":"Cambio aprobado","code":"x <- 2"}')),
        list(type = "response.completed", response = list(output = list())))
      i <- 0L
      rcodeagent:::.read_response(function() {
        i <<- i + 1L
        if (i > length(events)) return(NULL)
        list(data = jsonlite::toJSON(events[[i]], auto_unbox = TRUE))
      }, TRUE)
    }, .package = "rcodeagent"
  )
  shiny::testServer(rcodeagent:::.rcodeagent_server, {
    session$setInputs(mode = "normal", model = "test-model")
    session$setInputs(auto_requested = TRUE)
    session$setInputs(submit_request = list(text = "Cambia la sintaxis"))
    expect_equal(output$mode_label, "Auto")
    expect_equal(output$can_edit, "false")
    expect_equal(editor$writes, 1L)
    session$setInputs(apply = 1)
    expect_equal(editor$writes, 1L)
    session$setInputs(confirm_apply = 1)
    expect_equal(editor$contents, "x <- 2")
    expect_equal(editor$writes, 1L)
    editor$contents <- "x <- 99" # A pinned snapshot must not overwrite a manual change.
    session$setInputs(submit_request = list(text = "Otro cambio"))
    session$setInputs(apply = 2)
    session$setInputs(confirm_apply = 2)
    expect_equal(editor$contents, "x <- 99")
    expect_equal(editor$writes, 1L)
  })
})

test_that("legacy manual approval controls cannot enable Normal writes", {
  editor <- .local_unsaved_editor()
  shiny::testServer(rcodeagent:::.rcodeagent_server, {
    session$setInputs(model = "test-model", mode = "normal", capture_document = 1)
    session$setInputs(submit_request = list(text = "Primera propuesta"))
    session$setInputs(apply = 1, confirm_apply = 1)
    session$setInputs(submit_request = list(text = "Segunda propuesta"))
    session$setInputs(apply = 2, confirm_apply = 2)
    expect_length(editor$writes, 0L)
    expect_false(auto_mode())
  })
})


test_that("completion conflicts revoke an existing Auto grant", {
  editor <- .local_unsaved_editor()
  shiny::testServer(rcodeagent:::.rcodeagent_server, {
    session$setInputs(model = "test-model", mode = "normal")
    session$setInputs(auto_requested = TRUE)
    editor$docs[["unsaved-a"]]$path <- "renamed.R"
    session$setInputs(submit_request = list(text = "Preparar cambio"))
    expect_length(editor$writes, 0L)
    expect_false(auto_mode())
  })
})


test_that("a selection edit uses its captured range without replacing the document", {
  .local_jobs()
  target <- NULL
  testthat::local_mocked_bindings(
    getSourceEditorContext = function(id = NULL) list(id = "selection", contents = c("x <- 1", "y <- 3")),
    callFun = function(fname, location, text, id) { stopifnot(fname == "insertText"); target <<- list(location, text, id) },
    .package = "rstudioapi"
  )
  range <- list(start = c(1L, 1L), end = c(1L, 7L))
  snapshot <- list(id = "selection", full = "x <- 1\ny <- 3", range = range)
  rcodeagent:::.safe_editor_apply(snapshot, "x <- 2")
  expect_equal(target, list(range, "x <- 2", "selection"))
})
