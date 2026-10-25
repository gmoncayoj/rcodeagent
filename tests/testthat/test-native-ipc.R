test_that("native client waits for completion and does not consume partial/stale replies", {
  reply <- .native_ipc_fixture()
  expect_equal(reply$handled, 2L)
  expect_true(all(vapply(reply$results, function(x) isTRUE(x$ok), logical(1L))))
  expect_identical(reply$results[[1L]]$value$id, "synthetic-1")
  expect_identical(reply$results[[2L]]$value$id, "synthetic-2")
})

test_that("an early acknowledgement retries only reading the same response", {
  reply <- .native_ipc_fixture("early_ack")
  expect_equal(reply$handled, 2L)
  expect_identical(reply$results[[2L]]$value$id, "synthetic-2")
})

test_that("NULL and remote API errors do not corrupt the native channel", {
  reply <- .native_ipc_fixture("null")
  expect_null(reply$results[[1L]]$value)
  expect_true(reply$results[[2L]]$ok)
  reply <- .native_ipc_fixture("api_error")
  expect_false(reply$results[[1L]]$ok)
  expect_false(reply$results[[1L]]$transport)
  expect_match(reply$results[[1L]]$message, "synthetic API error")
  expect_true(reply$results[[2L]]$ok)
})

test_that("ambiguous writes are never resent and an unusable channel fails closed", {
  reply <- .native_ipc_fixture("timeout", write = TRUE)
  expect_equal(reply$handled, 1L)
  expect_true(reply$results[[1L]]$transport)
  expect_match(reply$results[[1L]]$message, "confirmar")
  expect_true(reply$results[[2L]]$transport)
})

test_that("the native client admits only fixed functions and data arguments", {
  expect_error(rcodeagent:::.native_api_request(quote(stop("never")), list()), "permitida")
  expect_error(rcodeagent:::.rstudio_call("source", file = "untrusted.R"), "permitida")
  expect_error(rcodeagent:::.rstudio_call("insertText", text = quote(stop("must not execute")), id = "target"), "datos")
  expect_error(rcodeagent:::.rstudio_call("insertText", text = new.env(), id = "target"), "datos")
  expect_error(rcodeagent:::.rstudio_call("getSourceEditorContext", unexpected = "target"), "argumentos")
  expect_error(rcodeagent:::.rstudio_call("documentNew", text = "stop('never')", execute = TRUE), "ejecutar")
  expect_error(rcodeagent:::.rstudio_call("viewer", url = "https://untrusted.example/"), "local")
})

test_that("a corrupt response is not accepted or followed by another request", {
  reply <- .native_ipc_fixture("malformed")
  expect_equal(reply$handled, 1L)
  expect_true(reply$results[[1L]]$transport)
  expect_true(reply$results[[2L]]$transport)
})

test_that("successful writes also wait for acknowledgement without being resent", {
  reply <- .native_ipc_fixture(write = TRUE)
  expect_equal(reply$handled, 2L)
  expect_true(all(vapply(reply$results, function(x) isTRUE(x$ok), logical(1L))))
})

test_that("interruption after publishing makes the channel unusable", {
  root <- withr::local_tempdir()
  request <- file.path(root, "request.rds")
  response <- file.path(root, "response.rds")
  withr::local_envvar(c(RSTUDIOAPI_IPC_REQUESTS_FILE = request, RSTUDIOAPI_IPC_RESPONSE_FILE = response,
    RSTUDIOAPI_IPC_SHARED_SECRET = "synthetic-test-only"))
  fn <- rcodeagent:::.native_api_request
  sandbox <- new.env(parent = environment(fn))
  environment(fn) <- sandbox
  sandbox$.native_ipc_state <- new.env(parent = emptyenv())
  sandbox$Sys.sleep <- function(...) stop(structure(list(message = "synthetic interrupt", call = NULL),
    class = c("interrupt", "condition")))
  interrupted <- tryCatch({ fn("getSourceEditorContext", list(id = "synthetic")); FALSE }, interrupt = function(e) TRUE)
  expect_true(interrupted)
  expect_true(sandbox$.native_ipc_state$failed)
  expect_false(sandbox$.native_ipc_state$busy)
  expect_error(fn("getSourceEditorContext", list(id = "synthetic")), class = "rcodeagent_ipc_error")
})
