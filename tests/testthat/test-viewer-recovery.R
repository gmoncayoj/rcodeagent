.local_viewer_fixture <- function(envir = parent.frame()) {
  .local_jobs(envir)
  editor <- new.env(parent = emptyenv())
  editor$snapshot <- list(id = "chosen", path = "", full = "qa_value <- 1", text = "qa_value <- 1",
    range = NULL, scope = "documento")
  editor$requested <- character()
  editor$writes <- 0L
  editor$fail <- FALSE
  testthat::local_mocked_bindings(
    .snapshot_editor = function(id = NULL) {
      editor$requested <- c(editor$requested, id %||% "active")
      if (editor$fail) stop("synthetic capture failure")
      editor$snapshot
    },
    rcodeagent_status = function() "Prueba local",
    .models_for_account = function() c(Test = "test-model", Other = "other-model"),
    .assistant_reply = function(...) list(action = "modify", message = "Última respuesta", code = "qa_value <- 2"),
    .safe_editor_apply = function(snapshot, code) {
      expect_identical(snapshot$id, "chosen")
      expect_identical(snapshot$full, editor$snapshot$full)
      editor$writes <- editor$writes + 1L
      editor$snapshot$full <- code
      editor$snapshot$text <- code
    }, .package = "rcodeagent", .env = envir)
  cache <- new.env(parent = emptyenv())
  cache$serial <- 0L
  cache$closed <- FALSE
  cache$owner <- NULL
  cache$checkpoint <- NULL
  list(editor = editor, cache = cache)
}

.viewer_mock_session <- function(cache) {
  session <- shiny::MockShinySession$new()
  session$userData$viewer_state <- cache
  session
}

test_that("Viewer return restores the last conversation and Auto grant in the same Job", {
  fixture <- .local_viewer_fixture()
  first <- .viewer_mock_session(fixture$cache)
  chat_id <- NULL
  shiny::testServer(rcodeagent:::.rcodeagent_server, session = first, {
    session$setInputs(model = "other-model", effort = "xhigh", mode = "normal", auto_requested = TRUE)
    files(list(list(name = "reference.R", text = "reference <- 1")))
    session$setInputs(submit_request = list(text = "Primera petición"))
    expect_true(auto_mode())
    chat_id <<- conversation()$id
    session$setInputs(request = "Borrador sincronizado")
  })
  second <- .viewer_mock_session(fixture$cache)
  shiny::testServer(rcodeagent:::.rcodeagent_server, session = second, {
    expect_identical(conversation()$id, chat_id)
    expect_length(history(), 2L)
    expect_equal(history()[[2L]]$text, "Última respuesta")
    expect_equal(files()[[1L]]$name, "reference.R")
    expect_identical(snap()$id, "chosen")
    expect_true(auto_mode())
    expect_equal(restored$model, "other-model")
    expect_equal(restored$effort, "xhigh")
    expect_equal(restored$draft, "Borrador sincronizado")
    session$setInputs(mode = "normal", model = "other-model", effort = "xhigh")
    expect_true(auto_mode()) # Initial UI defaults must not revoke the recovered grant.
    session$setInputs(viewer_restored = as.character(lease))
    session$setInputs(submit_request = list(text = "Segunda petición"))
    expect_true(auto_mode())
    expect_length(history(), 4L)
    expect_true(history()[[4L]]$edit_applied)
  })
  expect_equal(fixture$editor$writes, 2L)
  expect_true("chosen" %in% fixture$editor$requested)
  saved <- rcodeagent:::.load_conversation(chat_id)
  expect_false(any(c("auto", "snapshot", "grant") %in% names(saved)))
})

test_that("recovering Auto selects its menu option so Editor can revoke the grant", {
  fixture <- .local_viewer_fixture()
  shiny::testServer(rcodeagent:::.rcodeagent_server, session = .viewer_mock_session(fixture$cache), {
    session$setInputs(model = "test-model", mode = "auto")
    session$setInputs(auto_requested = TRUE)
  })
  selected <- NULL
  testthat::local_mocked_bindings(updateRadioButtons = function(session, inputId, ..., selected) {
    if (inputId == "mode") selected <<- selected
  }, .package = "shiny")
  shiny::testServer(rcodeagent:::.rcodeagent_server, session = .viewer_mock_session(fixture$cache), {
    session$flushReact()
    expect_identical(selected, "auto")
    session$setInputs(mode = "auto", model = "test-model")
    session$setInputs(viewer_restored = as.character(lease))
    expect_true(auto_mode())
    session$setInputs(mode = "normal")
    expect_false(auto_mode())
    session$setInputs(submit_request = list(text = "Revisión requerida"))
    expect_equal(pending_task(), "")
  })
  expect_equal(fixture$editor$writes, 0L)
})

test_that("Auto OFF and captured selection stay pinned when Viewer is recovered", {
  fixture <- .local_viewer_fixture()
  selection <- fixture$editor$snapshot
  selection$text <- "qa_value"
  selection$range <- list(start = c(1L, 1L), end = c(1L, 9L))
  selection$scope <- "selección"
  shiny::testServer(rcodeagent:::.rcodeagent_server, session = .viewer_mock_session(fixture$cache), {
    session$setInputs(mode = "normal", model = "test-model", effort = "high")
    snap(selection)
    expect_false(auto_mode())
  })
  # Cursor/selection changes alone must not replace the captured range.
  shiny::testServer(rcodeagent:::.rcodeagent_server, session = .viewer_mock_session(fixture$cache), {
    expect_false(auto_mode())
    expect_identical(snap(), selection)
    expect_equal(mode(), "normal")
    session$setInputs(mode = "normal", model = "test-model", viewer_restored = as.character(lease))
    expect_equal(mode(), "normal")
  })
  expect_equal(fixture$editor$writes, 0L)
})

test_that("changed or unavailable targets revoke recovery grants and stale proposals", {
  for (fault in c("content", "id", "path", "failure")) {
    fixture <- .local_viewer_fixture()
    shiny::testServer(rcodeagent:::.rcodeagent_server, session = .viewer_mock_session(fixture$cache), {
      session$setInputs(mode = "normal", model = "test-model", auto_requested = TRUE)
      expect_true(auto_mode())
    })
    switch(fault, content = { fixture$editor$snapshot$full <- "changed <- 99" },
      id = { fixture$editor$snapshot$id <- "other" },
      path = { fixture$editor$snapshot$path <- "saved-as.R" },
      failure = { fixture$editor$fail <- TRUE })
    shiny::testServer(rcodeagent:::.rcodeagent_server, session = .viewer_mock_session(fixture$cache), {
      expect_false(auto_mode())
      expect_null(snap())
      expect_identical(proposal(), "")
      expect_match(status(), "Auto desactivado")
    })
    expect_equal(fixture$editor$writes, 0L)
  }
})

test_that("disconnect cancels pending work without replay and preserves its instruction", {
  fixture <- .local_viewer_fixture()
  killed <- 0L
  testthat::local_mocked_bindings(.start_request = function(...) list(is_alive = function() TRUE,
    kill = function() { killed <<- killed + 1L }, get_result = function() stop("Never replay")), .package = "rcodeagent")
  shiny::testServer(rcodeagent:::.rcodeagent_server, session = .viewer_mock_session(fixture$cache), {
    session$setInputs(mode = "normal", model = "test-model", auto_requested = TRUE)
    session$setInputs(submit_request = list(text = "Petición en curso"), request = "")
  })
  expect_equal(killed, 1L)
  shiny::testServer(rcodeagent:::.rcodeagent_server, session = .viewer_mock_session(fixture$cache), {
    expect_null(active_job())
    expect_length(history(), 0L)
    expect_equal(restored$draft, "Petición en curso")
    expect_true(auto_mode())
  })
  expect_equal(fixture$editor$writes, 0L)
})

test_that("explicit Close clears the in-memory recovery state", {
  fixture <- .local_viewer_fixture()
  stops <- 0L
  testthat::local_mocked_bindings(stopApp = function(...) { stops <<- stops + 1L }, .package = "shiny")
  shiny::testServer(rcodeagent:::.rcodeagent_server, session = .viewer_mock_session(fixture$cache), {
    session$setInputs(mode = "normal", model = "test-model", auto_requested = TRUE)
    session$setInputs(done = 1)
  })
  expect_equal(stops, 1L)
  expect_true(fixture$cache$closed)
  expect_null(fixture$cache$checkpoint)
})

test_that("an unacknowledged recovery cannot write or lose the saved draft on another detach", {
  fixture <- .local_viewer_fixture()
  shiny::testServer(rcodeagent:::.rcodeagent_server, session = .viewer_mock_session(fixture$cache), {
    session$setInputs(model = "test-model", mode = "normal", auto_requested = TRUE, request = "Keep this draft")
  })
  shiny::testServer(rcodeagent:::.rcodeagent_server, session = .viewer_mock_session(fixture$cache), {
    session$setInputs(model = "test-model", mode = "normal", request = "")
    session$setInputs(submit_request = list(text = "Must not dispatch"), confirm_apply = 1)
    expect_null(active_job())
    expect_length(history(), 0L)
  })
  shiny::testServer(rcodeagent:::.rcodeagent_server, session = .viewer_mock_session(fixture$cache), {
    expect_equal(restored$draft, "Keep this draft")
    expect_true(auto_mode())
  })
  expect_equal(fixture$editor$writes, 0L)
})

test_that("a second live page cannot copy a recovery grant", {
  fixture <- .local_viewer_fixture()
  fixture$cache$owner <- 7L
  existing <- list(auto = TRUE)
  fixture$cache$checkpoint <- existing
  session <- .viewer_mock_session(fixture$cache)
  shiny::testServer(rcodeagent:::.rcodeagent_server, session = session, {
    expect_true(session$isClosed())
  })
  expect_identical(fixture$cache$owner, 7L)
  expect_identical(fixture$cache$checkpoint, existing)
  expect_equal(fixture$editor$writes, 0L)
})

test_that("Viewer return never replays an explicitly submitted execution", {
  fixture <- .local_viewer_fixture()
  sent <- 0L
  testthat::local_mocked_bindings(.assistant_reply = function(...) list(action = "execute", message = "Ejemplo", code = "x <- 1"),
    .console_input_empty = function() TRUE, .validate_execution_target = function(...) TRUE,
    .submit_console_execution = function(...) { sent <<- sent + 1L }, .package = "rcodeagent")
  shiny::testServer(.rcodeagent_server, session = .viewer_mock_session(fixture$cache), {
    session$setInputs(mode = "normal", model = "test-model", auto_requested = TRUE)
    session$setInputs(submit_request = list(text = "Genera y ejecuta un ejemplo"))
    expect_equal(sent, 1L)
    expect_null(pending_execution())
  })
  expect_false("pending_execution" %in% names(fixture$cache$checkpoint))
  shiny::testServer(.rcodeagent_server, session = .viewer_mock_session(fixture$cache), {
    session$setInputs(mode = "auto", model = "test-model", viewer_restored = as.character(lease))
    expect_true(auto_mode())
    expect_null(pending_execution())
    session$setInputs(confirm_execution = "obsolete-confirmation")
    expect_null(pending_execution())
    expect_equal(sent, 1L)
    expect_equal(fixture$editor$writes, 0L)
  })
})


test_that("Normal conversation survives recovery and a new chat revokes Auto", {
  fixture <- .local_viewer_fixture()
  testthat::local_mocked_bindings(.assistant_reply = function(...) list(action = "chat", message = "Código en chat", code = ""), .package = "rcodeagent")
  shiny::testServer(rcodeagent:::.rcodeagent_server, session = .viewer_mock_session(fixture$cache), {
    session$setInputs(mode = "normal", model = "test-model")
    session$setInputs(submit_request = list(text = "Consulta sin Auto"))
    expect_length(history(), 2L)
    expect_equal(output$can_edit, "false")
  })
  shiny::testServer(rcodeagent:::.rcodeagent_server, session = .viewer_mock_session(fixture$cache), {
    session$setInputs(mode = "normal", model = "test-model", viewer_restored = as.character(lease))
    expect_false(auto_mode())
    expect_length(history(), 2L)
    session$setInputs(auto_requested = TRUE)
    expect_true(auto_mode())
    session$setInputs(new_chat = 1)
    expect_false(auto_mode())
    expect_length(history(), 0L)
  })
  shiny::testServer(rcodeagent:::.rcodeagent_server, session = .viewer_mock_session(fixture$cache), {
    expect_false(auto_mode())
    expect_length(history(), 0L)
  })
})

