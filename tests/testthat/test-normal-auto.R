test_that("Normal is conversational and never offers side-effect tools", {
  seen <- NULL
  testthat::local_mocked_bindings(.responses_stream = function(prompt, model, tools = NULL, effort) {
    seen <<- tools
    "```r\nx <- 2\n```"
  }, .package = "rcodeagent")
  answer <- rcodeagent:::.assistant_reply("Revisa el código", "test", TRUE, "normal")
  expect_null(seen)
  expect_identical(answer$action, "chat")
  expect_match(answer$message, "x <- 2", fixed = TRUE)
  expect_identical(rcodeagent:::.permission_mode("auto"), "auto")
  expect_error(rcodeagent:::.permission_mode("ask"))
  expect_error(rcodeagent:::.permission_mode("plan"))
})

test_that("the server rejects Normal writes and legacy apply buttons", {
  editor <- .local_unsaved_editor()
  shiny::testServer(rcodeagent:::.rcodeagent_server, {
    session$setInputs(mode = "normal", model = "test-model", editor_access = TRUE)
    session$setInputs(submit_request = list(text = "Implementa el código"))
    expect_false(editor$can_edit)
    expect_length(editor$writes, 0L)
    expect_identical(output$can_edit, "false")
    session$setInputs(apply = 1, confirm_apply = 1, newdoc = 1)
    expect_length(editor$writes, 0L)
    expect_identical(output$mode_label, "Normal")
  })
})

test_that("Auto edits a chosen buffer without executing ordinary edits", {
  editor <- .local_unsaved_editor()
  shiny::testServer(rcodeagent:::.rcodeagent_server, {
    session$setInputs(mode = "normal", model = "test-model")
    session$setInputs(mode = "auto")
    expect_true(auto_mode())
    expect_identical(mode(), "auto")
    session$setInputs(submit_request = list(text = "Escribe qa_value <- 2"))
    expect_length(editor$writes, 1L)
    expect_identical(editor$docs[["unsaved-a"]]$text, "qa_value <- 2")
    session$setInputs(mode = "normal")
    expect_false(auto_mode())
  })
})

test_that("re-enabling Auto cannot revive a revoked in-flight grant", {
  check <- function(action) {
    editor <- .local_unsaved_editor()
    state <- new.env(parent = emptyenv()); state$alive <- TRUE
    testthat::local_mocked_bindings(.start_request = function(...) list(
      is_alive = function() state$alive, kill = function() { state$alive <- FALSE },
      get_result = function() list(action = action, message = "Resultado anterior", code = "qa_value <- 2")), .package = "rcodeagent")
    shiny::testServer(rcodeagent:::.rcodeagent_server, {
      session$setInputs(mode = "normal", model = "test-model")
      session$setInputs(mode = "auto")
      session$setInputs(submit_request = list(text = "Modifica y ejecuta", id = paste0("old-", action)))
      session$setInputs(mode = "normal")
      session$setInputs(mode = "auto")
      state$alive <- FALSE
      finish_job()
      expect_length(editor$writes, 0L)
      expect_null(pending_execution())
    })
  }
  for (action in c("modify", "execute")) check(action)
})
