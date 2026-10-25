test_that("models use safe slugs", {
  expect_equal(rcodeagent:::.validate_model(""), "")
  expect_equal(rcodeagent:::.validate_model("gpt-6"), "gpt-6")
  expect_error(rcodeagent:::.validate_model("gpt; echo bad"))
})

test_that("code fences are stripped only at the boundaries", {
  expect_equal(rcodeagent:::.unwrap_code("```r\nx <- 3\n```"), "x <- 3")
  expect_equal(rcodeagent:::.unwrap_code("x <- 3"), "x <- 3")
})

test_that("build prompt never exposes a secret key", {
  snap <- list(scope = "selección", text = "mean(1:5)")
  prompt <- rcodeagent:::.construct_prompt("explain", "¿Qué hace?", snap)
  expect_match(prompt, "mean\\(1:5\\)")
})
