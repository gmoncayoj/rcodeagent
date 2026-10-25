test_that("expected edited content uses the captured selection and UTF-16 columns", {
  full <- list(id = "qa", path = "", full = "x <- 1", text = "x <- 1", range = NULL, scope = "documento")
  expect_identical(rcodeagent:::.expected_editor_edit(full, "")$full, "")
  selected <- list(id = "qa", path = "", full = "# a😀bXYZc", text = "XYZ",
    range = rstudioapi::document_range(c(1, 7, 1, 10)), scope = "selección")
  expected <- rcodeagent:::.expected_editor_edit(selected, "Q")
  expect_identical(expected$full, "# a😀bQc")
  expect_identical(expected$text, "Q")
  expect_equal(unname(unlist(expected$range$start)), c(1, 7))
  expect_equal(unname(unlist(expected$range$end)), c(1, 8))
  selected$text <- "different"
  expect_error(rcodeagent:::.expected_editor_edit(selected, "Q"), "rango|captur")
})

test_that("multiline expected edits preserve all text outside the captured range", {
  s <- list(id = "qa", path = "qa.R", full = "keep <- 0\nx <- 1\nlast <- 2", text = "x <- 1\n",
    range = rstudioapi::document_range(c(2, 1, 3, 1)), scope = "selección")
  expected <- rcodeagent:::.expected_editor_edit(s, "x <- 3\ny <- 4\n")
  expect_identical(expected$full, "keep <- 0\nx <- 3\ny <- 4\nlast <- 2")
  expect_equal(unname(unlist(expected$range$start)), c(2, 1))
  expect_equal(unname(unlist(expected$range$end)), c(4, 1))
  expect_identical(rcodeagent:::.expected_editor_edit(s, "")$full, "keep <- 0\nlast <- 2")
})
