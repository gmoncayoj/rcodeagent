test_that("OAuth callback decodes parameters without exposing them in the page", {
  pending <- new.env(parent = emptyenv())
  pending$state <- "test state+value"
  pending$callback <- NULL
  request <- list(PATH_INFO = "/auth/callback", REQUEST_METHOD = "GET",
                  QUERY_STRING = "state=test%20state%2Bvalue&code=fake%2Bcode&client_id=oaiapp_test")
  result <- rcodeagent:::.oauth_callback(request, pending)
  expect_equal(result$status, 200L)
  expect_identical(pending$callback$code, "fake+code")
  expect_identical(pending$callback$client_id, "oaiapp_test")
  expect_false(grepl("fake", result$body, fixed = TRUE))
  expect_identical(result$headers[["Cache-Control"]], "no-store")
})

test_that("OAuth callback rejects invalid state and ambiguous parameters", {
  pending <- new.env(parent = emptyenv())
  pending$state <- "expected"
  pending$callback <- NULL
  for (query in c("code=fake", "state=other&code=fake",
                  "state=expected&state=other&code=fake")) {
    result <- rcodeagent:::.oauth_callback(list(
      PATH_INFO = "/auth/callback", REQUEST_METHOD = "GET", QUERY_STRING = query
    ), pending)
    expect_equal(result$status, 400L)
    expect_null(pending$callback)
  }
})

test_that("OAuth callback limits routes and preserves provider denial", {
  pending <- new.env(parent = emptyenv())
  pending$state <- "expected"
  pending$callback <- NULL
  request <- list(PATH_INFO = "/auth/callback", REQUEST_METHOD = "POST",
                  QUERY_STRING = "state=expected&error=access_denied")
  expect_equal(rcodeagent:::.oauth_callback(request, pending)$status, 404L)
  expect_null(pending$callback)
  request$REQUEST_METHOD <- "GET"
  request$PATH_INFO <- "/unrelated"
  expect_equal(rcodeagent:::.oauth_callback(request, pending)$status, 404L)
  request$PATH_INFO <- "/auth/callback"
  expect_equal(rcodeagent:::.oauth_callback(request, pending)$status, 200L)
  expect_identical(pending$callback$error, "access_denied")
})
