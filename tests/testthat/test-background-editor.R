test_that("background writes bypass main-session-only version wrappers", {
  written <- list()
  testthat::local_mocked_bindings(
    getSourceEditorContext = function(id = NULL) list(id = "target", contents = "qa_value <- 1"),
    getVersion = function() stop("RStudio not running"),
    callFun = function(fname, ...) { written[[length(written) + 1L]] <<- c(list(fname = fname), list(...)) },
    .package = "rstudioapi")
  snapshot <- list(id = "target", full = "qa_value <- 1", range = NULL)
  expect_silent(rcodeagent:::.safe_editor_apply(snapshot, "qa_value <- 2"))
  expect_identical(written[[1L]]$fname, "insertText")
  expect_identical(written[[1L]]$id, "target")
  expect_identical(written[[1L]]$text, "qa_value <- 2")
  expect_equal(written[[1L]]$location$start, rstudioapi::document_position(1, 1))
  expect_equal(written[[1L]]$location$end, rstudioapi::document_position(Inf, 1))
  snapshot$range <- rstudioapi::document_range(c(1, 4, 1, 8))
  expect_silent(rcodeagent:::.safe_editor_apply(snapshot, "2"))
  expect_identical(written[[2L]]$location, snapshot$range)
})
