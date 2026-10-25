test_that("Auto edits only after explicit activation and resets for a new or resumed chat", {
  .local_jobs()
  editor <- new.env(parent = emptyenv())
  editor$text <- "x <- 1"
  editor$writes <- 0L
  testthat::local_mocked_bindings(
    .snapshot_editor = function(id = NULL) list(id = "fixture", path = "destino.R", full = editor$text,
      text = editor$text, range = NULL, scope = "documento"),
    rcodeagent_status = function() "Sesión de prueba",
    .models_for_account = function() c(Test = "test-model"),
    .assistant_reply = function(...) list(action = "modify", message = "Cambio", code = "x <- 2",
      usage = list(input_tokens = 100, output_tokens = 20, total_tokens = 120)),
    .safe_editor_apply = function(snapshot, code) {
      if (!identical(editor$text, snapshot$full)) stop("Conflicto")
      editor$text <- code
      editor$writes <- editor$writes + 1L
    }, .package = "rcodeagent"
  )
  shiny::testServer(rcodeagent:::.rcodeagent_server, {
    ui_state <- NULL
    send_message <- session$sendCustomMessage
    session$sendCustomMessage <- function(type, message) {
      if (identical(type, "rg-session-state")) ui_state <<- message
      send_message(type, message)
    }
    session$setInputs(model = "test-model", mode = "normal", editor_access = TRUE)
    expect_false(auto_mode())
    expect_equal(ui_state$mode, "normal")
    session$setInputs(submit_request = list(text = "Proponer"))
    expect_equal(editor$writes, 0L)
    expect_equal(output$can_edit, "false")
    session$setInputs(auto_requested = TRUE)
    expect_true(auto_mode())
    expect_equal(ui_state$mode, "auto")
    session$setInputs(submit_request = list(text = "Aplicar ahora"))
    expect_equal(editor$writes, 1L)
    expect_equal(editor$text, "x <- 2")
    expect_equal(history()[[2L]]$text, "Cambio")
    expect_true(history()[[2L]]$edit_applied)
    expect_equal(output$can_edit, "false")
    expect_equal(token_usage()$total_tokens, 120)
    id <- conversation()$id
    session$setInputs(new_chat = 1)
    expect_false(auto_mode())
    expect_equal(ui_state$mode, "normal")
    expect_length(history(), 0L)
    session$setInputs(open_conversation = id)
    expect_false(auto_mode())
    expect_length(history(), 2L)
    expect_null(snap())
  })
})

test_that("cancelling invalidates a result and revocation prevents automatic writes", {
  .local_jobs()
  state <- new.env(parent = emptyenv())
  state$alive <- TRUE
  state$kills <- 0L
  state$writes <- 0L
  testthat::local_mocked_bindings(
    .snapshot_editor = function() list(id = "fixture", path = "destino.R", full = "x <- 1",
      text = "x <- 1", range = NULL, scope = "documento"),
    rcodeagent_status = function() "Sesión de prueba",
    .models_for_account = function() c(Test = "test-model"),
    .start_request = function(...) {
      state$alive <- TRUE
      list(is_alive = function() state$alive,
        kill = function() { state$alive <- FALSE; state$kills <- state$kills + 1L },
        get_result = function() list(action = "modify", message = "Cambio", code = "x <- 2"))
    },
    .safe_editor_apply = function(...) { state$writes <- state$writes + 1L }, .package = "rcodeagent"
  )
  shiny::testServer(rcodeagent:::.rcodeagent_server, {
    session$setInputs(model = "test-model", mode = "normal", auto_requested = TRUE)
    session$setInputs(submit_request = list(text = "Aplicar"))
    expect_false(is.null(active_job()))
    session$setInputs(cancel_request = "cancel")
    expect_equal(state$kills, 1L)
    finish_job()
    expect_equal(state$writes, 0L)
    expect_length(history(), 0L)
    session$setInputs(submit_request = list(text = "Otra petición"))
    session$setInputs(auto_requested = FALSE)
    state$alive <- FALSE
    finish_job()
    session$flushReact()
    expect_equal(state$writes, 0L)
    expect_equal(output$can_edit, "false")
  })
})

test_that("cancellation terminates a real background R process", {
  job <- callr::r_bg(function() { Sys.sleep(20); "late result" }, supervise = TRUE,
    system_profile = FALSE, user_profile = FALSE)
  on.exit(if (job$is_alive()) job$kill_tree(), add = TRUE)
  expect_true(job$is_alive())
  rcodeagent:::.cancel_request(job)
  job$wait(timeout = 2000)
  expect_false(job$is_alive())
})

test_that("an ambiguous Auto write revokes its grant", {
  editor <- .local_unsaved_editor()
  testthat::local_mocked_bindings(.safe_editor_apply = function(...) stop(structure(
    list(message = "synthetic transport error", call = NULL), class = c("rcodeagent_ipc_error", "error", "condition"))), .package = "rcodeagent")
  shiny::testServer(rcodeagent:::.rcodeagent_server, {
    session$setInputs(mode = "normal", model = "test-model")
    session$setInputs(auto_requested = TRUE)
    expect_true(auto_mode())
    session$setInputs(submit_request = list(text = "Escribe código"))
    expect_false(auto_mode())
    expect_length(editor$writes, 0L)
  })
})


test_that("model workers cannot inherit the native editor channel", {
  withr::local_envvar(c(RSTUDIOAPI_IPC_REQUESTS_FILE = "synthetic-request", RSTUDIOAPI_IPC_RESPONSE_FILE = "synthetic-response",
    RSTUDIOAPI_IPC_SHARED_SECRET = "synthetic-test-only", RSTUDIO_WORKBENCH_JOB = "synthetic-job"))
  worker <- rcodeagent:::.start_request("synthetic", "synthetic", FALSE, "normal", "medium",
    worker_reply = function(...) unname(Sys.getenv(c("RSTUDIOAPI_IPC_REQUESTS_FILE", "RSTUDIOAPI_IPC_RESPONSE_FILE",
      "RSTUDIOAPI_IPC_SHARED_SECRET", "RSTUDIO_WORKBENCH_JOB"), unset = "")))
  on.exit(if (worker$is_alive()) worker$kill_tree(), add = TRUE)
  worker$wait(timeout = 10000)
  expect_identical(worker$get_result(), rep("", 4L))
})
