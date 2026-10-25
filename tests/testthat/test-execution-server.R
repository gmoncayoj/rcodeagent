test_that("unverified native console submission cannot edit or execute", {
  editor <- .local_unsaved_editor()
  testthat::local_mocked_bindings(.console_execution_ready = function() FALSE, .package = "rcodeagent")
  shiny::testServer(rcodeagent:::.rcodeagent_server, {
    session$setInputs(mode = "normal", model = "test-model")
    session$setInputs(mode = "auto")
    session$setInputs(submit_request = list(text = "carga lavaan", id = "load"))
    expect_length(editor$writes, 0L)
    expect_identical(pending_execution()$code, "library(lavaan)")
    expect_match(execution_status(), "validación nativa")
    expect_false(rcodeagent:::.console_execution_ready())
    session$setInputs(mode = "normal")
    expect_null(pending_execution())
  })
})

test_that("explicit line requests submit once without editing the source", {
  editor <- .local_unsaved_editor()
  editor$docs[["unsaved-a"]]$text <- "x <- 1\ny <- 2"
  sent <- character()
  testthat::local_mocked_bindings(.console_input_empty = function() TRUE, .console_execution_ready = function() TRUE,
    .submit_console_execution = function(code, snapshot) { sent <<- c(sent, code) }, .package = "rcodeagent")
  shiny::testServer(rcodeagent:::.rcodeagent_server, {
    session$setInputs(mode = "normal", model = "test-model")
    session$setInputs(mode = "auto")
    session$setInputs(submit_request = list(text = "ejecuta la línea 2", id = "run-2"))
    expect_identical(sent, "y <- 2")
    session$setInputs(submit_request = list(text = "ejecuta la línea 2", id = "run-2"))
    expect_length(sent, 1L)
    expect_length(editor$writes, 0L)
    expect_match(execution_status(), "Enviado")
    expect_null(pending_execution())
    session$setInputs(confirm_execution = "old-or-forged")
    expect_length(sent, 1L)
  })
})

test_that("administrative execution retains exact one-use confirmation", {
  editor <- .local_unsaved_editor()
  editor$docs[["unsaved-a"]]$text <- 'unlink("synthetic-file-that-does-not-exist")'
  sent <- character()
  testthat::local_mocked_bindings(.console_input_empty = function() TRUE, .submit_console_execution = function(code, snapshot) { sent <<- c(sent, code) }, .package = "rcodeagent")
  shiny::testServer(rcodeagent:::.rcodeagent_server, {
    session$setInputs(mode = "normal", model = "test-model", auto_requested = TRUE)
    session$setInputs(submit_request = list(text = "ejecuta la línea 1", id = "admin"))
    expect_length(sent, 0L)
    candidate <- pending_execution()
    expect_identical(candidate$code, editor$docs[["unsaved-a"]]$text)
    session$setInputs(confirm_execution = "forged")
    expect_length(sent, 0L)
    session$setInputs(confirm_execution = candidate$nonce)
    expect_length(sent, 1L)
    session$setInputs(confirm_execution = candidate$nonce)
    expect_length(sent, 1L)
  })
})

test_that("explicit new code execution in Auto is submitted once without a preview", {
  editor <- .local_unsaved_editor()
  sent <- character()
  testthat::local_mocked_bindings(.console_input_empty = function() TRUE, .console_execution_ready = function() TRUE,
    .submit_console_execution = function(code, snapshot) { sent <<- c(sent, code) },
    .assistant_reply = function(...) list(action = "execute", message = "Propuesta", code = "x <- 1"), .package = "rcodeagent")
  shiny::testServer(rcodeagent:::.rcodeagent_server, {
    session$setInputs(mode = "normal", model = "test-model")
    session$setInputs(mode = "auto")
    session$setInputs(submit_request = list(text = "genera y ejecuta un ejemplo", id = "generate"))
    expect_identical(sent, "x <- 1")
    expect_null(pending_execution())
    expect_identical(output$has_proposal, "false")
    session$setInputs(confirm_execution = "forged")
    expect_length(sent, 1L)
    session$setInputs(submit_request = list(text = "genera y ejecuta un ejemplo", id = "generate"))
    expect_length(sent, 1L)
  })
})

test_that("a model execution proposal cannot grant permission without current intent", {
  .local_unsaved_editor()
  sent <- character()
  testthat::local_mocked_bindings(.console_input_empty = function() TRUE,
    .submit_console_execution = function(code, snapshot) { sent <<- c(sent, code) },
    .assistant_reply = function(...) list(action = "execute", message = "Unsolicited", code = "x <- 1"), .package = "rcodeagent")
  shiny::testServer(rcodeagent:::.rcodeagent_server, {
    session$setInputs(mode = "normal", model = "test-model", auto_requested = TRUE)
    session$setInputs(submit_request = list(text = "Explica cómo ejecutar este código", id = "explain"))
    expect_length(sent, 0L)
    expect_null(pending_execution())
    session$setInputs(confirm_execution = "forged")
    expect_length(sent, 0L)
  })
})

test_that("bare execute runs the captured selection without asking the model", {
  editor <- .local_unsaved_editor()
  editor$docs[["unsaved-a"]]$text <- "n <- 200\nx <- 1"
  sent <- character()
  testthat::local_mocked_bindings(.console_input_empty = function() TRUE,
    .submit_console_execution = function(code, snapshot) { sent <<- c(sent, code) }, .package = "rcodeagent")
  shiny::testServer(rcodeagent:::.rcodeagent_server, {
    session$setInputs(mode = "normal", model = "test-model", auto_requested = TRUE)
    s <- snap(); s$text <- "n <- 200"; s$full <- "n <- 200\nx <- 1"
    s$range <- list(start = c(1L, 1L), end = c(1L, 9L)); s$scope <- "selección"; snap(s)
    session$setInputs(submit_request = list(text = "ejecuta", id = "selection"))
    expect_identical(sent, "n <- 200")
    expect_null(pending_execution())
  })
})

test_that("explicit package installation submits without editing or confirmation", {
  editor <- .local_unsaved_editor()
  sent <- character()
  testthat::local_mocked_bindings(.console_input_empty = function() TRUE,
    .submit_console_execution = function(code, snapshot) { sent <<- c(sent, code) }, .package = "rcodeagent")
  shiny::testServer(rcodeagent:::.rcodeagent_server, {
    session$setInputs(mode = "normal", model = "test-model", auto_requested = TRUE)
    session$setInputs(submit_request = list(text = "instala el paquete lavaan", id = "install"))
    expect_identical(sent, 'install.packages("lavaan")')
    expect_length(editor$writes, 0L)
    expect_null(pending_execution())
  })
})

test_that("post-write interference blocks library submission and edit-then-run previews", {
  check <- function(instruction) {
    editor <- .local_unsaved_editor()
    original_write <- rcodeagent:::.write_editor_text
    sent <- 0L
    testthat::local_mocked_bindings(.console_input_empty = function() TRUE,
      .submit_console_execution = function(...) { sent <<- sent + 1L },
      .write_editor_text = function(text, id, range = NULL) {
        original_write(text, id, range)
        editor$docs[[id]]$text <- "manual <- 99"
      }, .package = "rcodeagent")
    shiny::testServer(rcodeagent:::.rcodeagent_server, {
      session$setInputs(mode = "normal", model = "test-model")
      session$setInputs(mode = "auto")
      session$setInputs(submit_request = list(text = instruction))
      expect_equal(sent, 0L)
      expect_null(pending_execution())
      expect_false(auto_mode())
      expect_match(status(), "edición se envió")
      expect_identical(editor$docs[["unsaved-a"]]$text, "manual <- 99")
    })
  }
  for (instruction in c("carga lavaan", "corrige el código y ejecútalo")) check(instruction)
})

test_that("loading a quoted package call does not duplicate it and status uses UI language", {
  editor <- .local_unsaved_editor()
  editor$docs[["unsaved-a"]]$text <- 'library("lavaan")'
  sent <- character()
  testthat::local_mocked_bindings(.console_input_empty = function() TRUE,
    .submit_console_execution = function(code, snapshot) { sent <<- c(sent, code) }, .package = "rcodeagent")
  shiny::testServer(rcodeagent:::.rcodeagent_server, {
    ui_language("en")
    session$setInputs(mode = "normal", model = "test-model", auto_requested = TRUE)
    session$setInputs(submit_request = list(text = "carga lavaan"))
    expect_length(editor$writes, 0L)
    expect_identical(sent, "library(lavaan)")
    expect_match(history()[[2L]]$text, "Submitted to the console", fixed = TRUE)
  })
})

