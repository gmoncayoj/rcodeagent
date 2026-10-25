test_that("assistant Markdown renders prose, lists and code with safe HTML", {
  rendered <- as.character(rcodeagent:::.render_markdown("**Resumen**\n\n- Uno\n- Dos\n\n`mean(x)`\n\n```r\nx <- 1\n```"))
  expect_match(rendered, "<strong>Resumen</strong>", fixed = TRUE)
  expect_match(rendered, "<ul>", fixed = TRUE)
  expect_match(rendered, "<code>mean(x)</code>", fixed = TRUE)
  expect_match(rendered, "<pre>", fixed = TRUE)
  unsafe <- as.character(rcodeagent:::.render_markdown(
    '<script>alert(1)</script>\n\n<img src="https://invalid.example/pixel" onerror="alert(1)">\n\n[link](javascript:alert%281%29)\n\n![image](https://invalid.example/pixel)'))
  expect_false(grepl("<script|<img|onerror|href=\"javascript", unsafe, ignore.case = TRUE))
})

test_that("read-only modes cannot expose proposal tools", {
  testthat::local_mocked_bindings(
    .responses_stream = function(prompt, model, tools = NULL, effort = "medium") {
      if (!is.null(tools)) stop("Proposal tools exposed")
      "Plan sin modificaciones"
    }, .package = "rcodeagent"
  )
  for (mode in c("normal")) {
    result <- rcodeagent:::.assistant_reply("Prompt", "test-model", mode = mode)
    expect_equal(result$action, "chat")
    expect_equal(result$code, "")
  }
  expect_error(rcodeagent:::.assistant_reply("Prompt", "test-model", mode = "ask"))
})
