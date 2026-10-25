test_that("administrative calls in function defaults require review", {
  cases <- c(
    'f <- function(x = unlink("synthetic-never-run")) x; f()',
    'f <- function(x = base::system("synthetic-never-run")) x; f()',
    'f <- function(x = base:::system("synthetic-never-run")) x; f()',
    'f <- \\(x = unlink("synthetic-never-run")) x; f()',
    'f <- function(x = identity(unlink("synthetic-never-run"))) x; f()',
    'f <- function(x = function(y = file.remove("synthetic-never-run")) y) x; f()',
    'f <- function(x, y = unlink("synthetic-never-run"), ...) y; f(1)',
    'f <- function(x = { value <- 1; unlink("synthetic-never-run") }) x; f()'
  )
  for (code in cases) expect_true(rcodeagent:::.execution_requires_review(code), info = code)
})

test_that("sensitive installation arguments still require administrative review", {
  expect_true(rcodeagent:::.execution_requires_review(
    'utils::install.packages(repos = { system("synthetic-never-run"); "https://example.invalid" })'))
})

test_that("ordinary function defaults and package installation keep their permissions", {
  cases <- c(
    'f <- function(x, y = 1, ...) x + y; f(2)',
    'f <- function(x = function(y = 2) y) x; f()',
    'f <- function(x = utils::install.packages("synthetic-not-installed")) x; f()',
    'f <- function(x, ...) x; f(1)',
    'f <- function() 1; f()',
    'f <- function(x = NULL) x; f()'
  )
  for (code in cases) expect_false(rcodeagent:::.execution_requires_review(code), info = code)
})

test_that("function default administrative proposals wait for the exact one-use nonce", {
  .local_unsaved_editor()
  code <- 'f <- function(x = unlink("synthetic-never-run")) x; f()'
  sent <- character()
  testthat::local_mocked_bindings(
    .console_input_empty = function() TRUE,
    .submit_console_execution = function(code, snapshot) { sent <<- c(sent, code) },
    .assistant_reply = function(...) list(action = "execute", message = "Synthetic proposal", code = code),
    .package = "rcodeagent")
  shiny::testServer(rcodeagent:::.rcodeagent_server, {
    session$setInputs(mode = "normal", model = "test-model", auto_requested = TRUE)
    session$setInputs(submit_request = list(text = "generate and run an example", id = "default-admin"))
    expect_length(sent, 0L)
    candidate <- pending_execution()
    expect_identical(candidate$code, code)
    session$setInputs(confirm_execution = "forged")
    expect_length(sent, 0L)
    session$setInputs(confirm_execution = candidate$nonce)
    expect_identical(sent, code)
    expect_null(pending_execution())
    session$setInputs(confirm_execution = candidate$nonce)
    expect_length(sent, 1L)
  })
})

test_that("direct default-argument execution rejects a nonce revoked by a mode change", {
  editor <- .local_unsaved_editor()
  code <- 'f <- function(x = file.remove("synthetic-never-run")) x; f()'
  editor$docs[["unsaved-a"]]$text <- code
  sent <- character()
  testthat::local_mocked_bindings(
    .console_input_empty = function() TRUE,
    .submit_console_execution = function(code, snapshot) { sent <<- c(sent, code) },
    .package = "rcodeagent")
  shiny::testServer(rcodeagent:::.rcodeagent_server, {
    session$setInputs(mode = "normal", model = "test-model", auto_requested = TRUE)
    session$setInputs(submit_request = list(text = "run", id = "direct-old"))
    expect_length(sent, 0L)
    old_nonce <- pending_execution()$nonce
    session$setInputs(mode = "normal")
    expect_null(pending_execution())
    session$setInputs(mode = "auto")
    session$setInputs(submit_request = list(text = "run", id = "direct-new"))
    candidate <- pending_execution()
    expect_identical(candidate$code, code)
    session$setInputs(confirm_execution = old_nonce)
    expect_length(sent, 0L)
    session$setInputs(confirm_execution = candidate$nonce)
    expect_identical(sent, code)
    session$setInputs(confirm_execution = candidate$nonce)
    expect_length(sent, 1L)
  })
})
