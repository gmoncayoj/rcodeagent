.local_context_editor <- function(envir = parent.frame()) {
  .local_jobs(envir)
  editor <- new.env(parent = emptyenv())
  editor$snapshot <- list(id = "target", path = "target.R", full = "qa_value <- 1", text = "qa_value <- 1",
    range = NULL, scope = "documento")
  editor$writes <- 0L
  editor$fail <- FALSE
  testthat::local_mocked_bindings(
    .snapshot_editor = function(id = NULL) {
      if (editor$fail) stop("synthetic capture failure")
      editor$snapshot
    },
    .select_editor_target = function() editor$snapshot,
    rcodeagent_status = function() "Prueba local",
    .models_for_account = function() c(Test = "test-model"),
    .assistant_reply = function(...) list(action = "modify", message = "Propuesta sintética", code = "qa_value <- 2"),
    .safe_editor_apply = function(snapshot, code) {
      editor$writes <- editor$writes + 1L
      editor$snapshot <- rcodeagent:::.expected_editor_edit(snapshot, code)
    },
    .package = "rcodeagent", .env = envir)
  editor
}

test_that("recapturing the identical document preserves its Auto grant and applies the next request", {
  editor <- .local_context_editor()
  shiny::testServer(rcodeagent:::.rcodeagent_server, {
    session$setInputs(mode = "normal", model = "test-model", auto_requested = TRUE)
    expect_true(auto_mode())
    session$setInputs(capture_document = 1)
    expect_true(auto_mode())
    expect_match(status(), "Auto sigue activado")
    session$setInputs(refresh = 1)
    expect_true(auto_mode())
    session$setInputs(choose_target = 1)
    expect_true(auto_mode())
    session$setInputs(submit_request = list(text = "Cambia el valor"))
    expect_equal(editor$writes, 1L)
    expect_true(history()[[2L]]$edit_applied)
  })
})

test_that("explicit recapture rebinds changed targets without switching off Auto", {
  editor <- .local_context_editor()
  shiny::testServer(rcodeagent:::.rcodeagent_server, {
    session$setInputs(mode = "normal", model = "test-model", auto_requested = TRUE)
    editor$snapshot$id <- "another-target"
    session$setInputs(refresh = 1)
    expect_true(auto_mode())
    expect_match(status(), "Auto sigue activado")
    session$setInputs(auto_requested = TRUE)
    editor$snapshot$full <- "qa_value <- 99"
    editor$snapshot$text <- editor$snapshot$full
    session$setInputs(refresh = 2)
    expect_true(auto_mode())
    session$setInputs(auto_requested = TRUE)
    editor$snapshot$range <- list(start = c(1L, 1L), end = c(1L, 9L))
    editor$snapshot$text <- "qa_value"
    editor$snapshot$scope <- "selección"
    session$setInputs(refresh = 3)
    expect_true(auto_mode())
    expect_identical(snap(), editor$snapshot)
  })
})

test_that("explicit selection and document changes preserve Auto with a fresh generation", {
  editor <- .local_context_editor()
  editor$snapshot$range <- list(start = c(1L, 1L), end = c(1L, 9L))
  editor$snapshot$text <- "qa_value"
  editor$snapshot$scope <- "selección"
  shiny::testServer(rcodeagent:::.rcodeagent_server, {
    session$setInputs(mode = "normal", model = "test-model", auto_requested = TRUE)
    session$setInputs(refresh = 1)
    expect_true(auto_mode())
    expect_identical(snap()$range, editor$snapshot$range)
    generation <- auto_generation()
    session$setInputs(capture_document = 1)
    expect_true(auto_mode())
    expect_gt(auto_generation(), generation)
    expect_null(snap()$range)
    expect_equal(snap()$text, snap()$full)
    session$setInputs(project_context = 1)
    expect_true(auto_mode())
    session$setInputs(refresh = 2)
    expect_true(auto_mode())
    expect_identical(snap()$range, editor$snapshot$range)
  })
})

test_that("a failed recapture revokes Auto instead of retaining an unverified grant", {
  editor <- .local_context_editor()
  shiny::testServer(rcodeagent:::.rcodeagent_server, {
    session$setInputs(mode = "normal", model = "test-model", auto_requested = TRUE)
    editor$fail <- TRUE
    session$setInputs(refresh = 1)
    expect_false(auto_mode())
  })
})

test_that("capturing context preserves Plan and Ask permissions", {
  editor <- .local_context_editor()
  shiny::testServer(rcodeagent:::.rcodeagent_server, {
    updates <- list()
    session$sendInputMessage <- function(id, message) {
      if (id == "mode") updates[[length(updates) + 1L]] <<- message$value
    }
    session$setInputs(mode = "normal", capture_document = 1)
    session$setInputs(mode = "normal", refresh = 1)
    expect_length(updates, 0L)
    expect_false(auto_mode())
  })
})

test_that("context controls report persistent selection without changing the authorized target", {
  editor <- .local_context_editor()
  shiny::testServer(rcodeagent:::.rcodeagent_server, {
    state <- NULL
    send_message <- session$sendCustomMessage
    session$sendCustomMessage <- function(type, message) {
      if (identical(type, "rg-session-state")) state <<- message
      send_message(type, message)
    }
    session$setInputs(mode = "normal", model = "test-model", capture_document = 1)
    expect_equal(state$context_view, "document")
    session$setInputs(auto_requested = TRUE)
    authorized <- snap()
    session$setInputs(project_context = 1)
    expect_equal(state$context_view, "project")
    expect_identical(snap(), authorized)
    expect_true(auto_mode())
    session$setInputs(request = "La escritura no cambia la selección de contexto")
    expect_equal(state$context_view, "project")
    session$setInputs(refresh = 1)
    expect_equal(state$context_view, "selection")
    expect_true(auto_mode())
  })
})
