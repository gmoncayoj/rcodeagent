test_that("patches preserve untouched lines and bind to the exact captured content", {
  before <- "x <- 1\ny <- 2\nz <- 3\n"
  after <- "x <- 4\ny <- 2\nz <- 5\n"
  patch <- .make_edit_patch(before, after)
  expect_identical(.apply_edit_patch(before, patch), after)
  expect_error(.apply_edit_patch(sub("y <- 2", "y <- 99", before), patch), "cambió|coincide")
  lines <- .edit_diff_lines(patch)
  expect_true(any(lines$type == "delete" & lines$text == "x <- 1"))
  expect_true(any(lines$type == "add" & lines$text == "z <- 5"))
  expect_true(any(lines$type == "context" & lines$text == "y <- 2"))
})

test_that("patches handle empty buffers, Unicode and final newlines", {
  pairs <- list(c("", "x <- 1\n"), c("x <- 1\n", ""), c("α <- 1\n", "α <- 2"),
    c("x <- 1\n\n", "x <- 1\n"), c("x <- 1", "x <- 1"))
  for (pair in pairs) expect_identical(.apply_edit_patch(pair[[1]], .make_edit_patch(pair[[1]], pair[[2]])), pair[[2]])
  before <- paste(rep("", 2000), collapse = "\n")
  after <- paste(rep("x", 2000), collapse = "\n")
  expect_identical(.apply_edit_patch(before, .make_edit_patch(before, after)), after)
})

test_that("the final editor comparison occurs after patch preparation", {
  current <- "x <- 1"; writes <- 0L
  testthat::local_mocked_bindings(.rstudio_call = function(method, ...) {
    if (method == "getSourceEditorContext") return(list(id = "target", path = "target.R", contents = current))
    writes <<- writes + 1L
  }, .package = "rcodeagent")
  make <- .make_edit_patch
  testthat::local_mocked_bindings(.make_edit_patch = function(before, after) {
    patch <- make(before, after)
    current <<- "manual <- 99"
    patch
  }, .package = "rcodeagent")
  snapshot <- list(id = "target", path = "target.R", text = "x <- 1", full = "x <- 1", range = NULL)
  expect_error(.safe_editor_apply(snapshot, "x <- 2"), class = "rcodeagent_editor_conflict")
  expect_identical(current, "manual <- 99")
  expect_equal(writes, 0L)
})

test_that("a changed path blocks even an unchanged pinned document", {
  writes <- 0L
  testthat::local_mocked_bindings(
    .rstudio_call = function(...) list(id = "target", path = "renamed.R", contents = "x <- 1"),
    .write_editor_text = function(...) { writes <<- writes + 1L }, .package = "rcodeagent")
  snapshot <- list(id = "target", path = "original.R", full = "x <- 1", text = "x <- 1", range = NULL)
  expect_error(.safe_editor_apply(snapshot, "x <- 2"), "ruta|cambió")
  expect_identical(writes, 0L)
})
