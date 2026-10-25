test_that("cancelled OAuth shows a translated five-second notice", {
  withr::local_options(rcodeagent.preferences_file = tempfile())
  pending <- new.env(parent = emptyenv())
  pending$created_at <- Sys.time()
  pending$state <- "synthetic-state"
  pending$callback <- list(state = pending$state, error = "access_denied")
  notices <- list()
  testthat::local_mocked_bindings(
    .snapshot_editor = function() NULL,
    rcodeagent_status = function() "test",
    .models_for_account = function() stop("Not connected"),
    .oauth_start = function() pending,
    .oauth_stop = function(...) invisible(NULL),
    .oauth_with_lock = function(code) force(code),
    .package = "rcodeagent")
  testthat::local_mocked_bindings(showNotification = function(ui, ..., duration = 5) {
    notices[[length(notices) + 1L]] <<- list(text = as.character(ui), duration = duration)
    "test-notice"
  }, .package = "shiny")
  expect_error(rcodeagent:::.oauth_finish(pending), class = "rcodeagent_auth_cancelled")
  shiny::testServer(rcodeagent:::.rcodeagent_server, {
    session$flushReact()
    session$setInputs(connect = 1)
    expect_null(oauth())
    expect_false(is_connected())
    expect_length(notices, 1L)
    expect_identical(notices[[1L]]$duration, 5)
    expect_identical(notices[[1L]]$text, "Sign-in cancelled or denied.")
    pending$callback <- list(state = pending$state, error = "server_error")
    session$setInputs(connect = 2)
    expect_length(notices, 2L)
    expect_null(notices[[2L]]$duration)
    pending$callback <- list(state = "wrong-state", error = "access_denied")
    session$setInputs(connect = 3)
    expect_length(notices, 3L)
    expect_null(notices[[3L]]$duration)
  })
})
