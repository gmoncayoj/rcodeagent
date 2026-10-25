test_that("another-account authorization omits the previous registration and hints", {
  old <- list(client_id = "oaiapp_old", subject = "old-subject", email = "old@example.invalid")
  credential <- NULL
  opened <- NULL
  listeners <- list()
  stopped <- list()
  testthat::local_mocked_bindings(
    .oauth_with_lock = function(code) force(code),
    .oauth_credential = function() credential,
    .oauth_registration = function() old,
    .oauth_host_id = function() "synthetic-host",
    .package = "rcodeagent")
  testthat::local_mocked_bindings(browseURL = function(url, ...) { opened <<- url; invisible(TRUE) },
    .package = "utils")
  testthat::local_mocked_bindings(
    randomPort = function(...) 18555L,
    startServer = function(host, port, app, ...) {
      expect_identical(host, "127.0.0.1")
      expect_identical(port, 1455L)
      expect_true(is.function(app$call))
      listener <- new.env(parent = emptyenv())
      listeners[[length(listeners) + 1L]] <<- listener
      listener
    },
    stopServer = function(server, ...) { stopped[[length(stopped) + 1L]] <<- server },
    .package = "httpuv")
  attempt <- .oauth_start(new_account = TRUE)
  on.exit(.oauth_stop(attempt), add = TRUE)
  query <- httr2::url_parse(opened)$query
  expect_identical(query$client_id, "dynamic_agent_client")
  expect_identical(query$agent_name_hint, "rcodeagent")
  expect_identical(query$ext_agent_host_id, "synthetic-host")
  expect_null(query$login_hint)
  expect_null(query$id_token_hint)
  expect_null(attempt$old)
  .oauth_stop(attempt)
  attempt <- .oauth_start()
  expect_identical(httr2::url_parse(opened)$query$client_id, old$client_id)
  expect_identical(attempt$old, old)
  .oauth_stop(attempt)
  credential <- c(old, list(access_token = "synthetic"))
  expect_error(.oauth_start(new_account = TRUE), "Desconecta")
  expect_length(listeners, 2L)
  expect_identical(stopped, listeners)
})

test_that("the disconnected UI offers a separate another-account action", {
  withr::local_options(rcodeagent.preferences_file = tempfile())
  calls <- logical()
  testthat::local_mocked_bindings(
    .snapshot_editor = function() NULL,
    rcodeagent_status = function() "test",
    .models_for_account = function() stop("Not connected"),
    .oauth_start = function(new_account = FALSE) {
      calls <<- c(calls, new_account)
      attempt <- new.env(parent = emptyenv())
      attempt$created_at <- Sys.time()
      attempt
    },
    .oauth_stop = function(...) invisible(NULL),
    .package = "rcodeagent")
  shiny::testServer(rcodeagent:::.rcodeagent_server, {
    session$flushReact()
    session$setInputs(connect_other = 1)
    expect_identical(calls, TRUE)
    is_connected(TRUE)
    session$setInputs(connect_other = 2)
    expect_length(calls, 1L)
  })
})
