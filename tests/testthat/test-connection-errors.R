test_that("connection HTTP failures identify their stage without exposing payloads", {
  testthat::local_mocked_bindings(.oauth_get_token = function() "SYNTHETIC_ACCESS_SECRET", .package = "rcodeagent")
  calls <- 0L
  httr2::with_mocked_responses(function(req) {
    calls <<- calls + 1L
    httr2::response(400L, headers = list("content-type" = "application/json", "x-request-id" = "req_synthetic"),
      body = charToRaw('{"error":{"code":"invalid_grant","message":"SYNTHETIC_ACCESS_SECRET","param":"SYNTHETIC_CODE_SECRET"},"refresh_token":"SYNTHETIC_REFRESH_SECRET"}'))
  }, {
    err <- tryCatch(.models_for_account(), error = identity)
    expect_s3_class(err, "rcodeagent_connection_http_error")
    text <- .connection_error_message(err, "en")
    expect_match(text, "Model catalog", fixed = TRUE)
    expect_match(text, "HTTP 400", fixed = TRUE)
    expect_match(text, "invalid_grant", fixed = TRUE)
    expect_match(text, "req_synthetic", fixed = TRUE)
    expect_false(any(grepl("SECRET", c(text, capture.output(str(err))), fixed = TRUE)))
    expect_identical(err$body_shape, "error_object")
    expect_match(.connection_error_message(err, "es"), "Catálogo de modelos", fixed = TRUE)
  })
  expect_identical(calls, 1L)
})

test_that("unknown or malformed provider payloads produce bounded safe diagnostics", {
  for (body in c('{"detail":"SYNTHETIC_SECRET"}', '{"error":"invalid_client"}',
                 '{"error":{"code":"SYNTHETIC_SECRET"}}', '<html>SYNTHETIC_SECRET</html>')) {
    httr2::with_mocked_responses(function(req) httr2::response(400L,
      headers = list("content-type" = "application/json", "x-request-id" = "SYNTHETIC_SECRET"), body = charToRaw(body)), {
      err <- tryCatch(.connection_request(httr2::request("https://auth.openai.com/api/accounts/oauth/token"), "oauth"), error = identity)
      expect_s3_class(err, "rcodeagent_connection_http_error")
      text <- .connection_error_message(err, "en")
      expect_match(text, "OAuth token exchange", fixed = TRUE)
      expect_false(any(grepl("SECRET", c(text, capture.output(str(err))), fixed = TRUE)))
      expect_lte(nchar(text), 350)
    })
  }
  expect_identical(.connection_error_message(simpleError("\033[1mHTTP 400\033[22m"), "en"), "HTTP 400")
})

test_that("token exchange rejection cannot save credentials or retry authorization codes", {
  saved <- 0L
  calls <- 0L
  pending <- new.env(parent = emptyenv())
  pending$created_at <- Sys.time()
  pending$state <- "synthetic-state"
  pending$callback <- list(state = pending$state, code = "SYNTHETIC_CODE_SECRET", client_id = "oaiapp_test")
  pending$client_id <- "dynamic_agent_client"
  pending$redirect_uri <- "http://127.0.0.1:1455/auth/callback"
  pending$verifier <- "SYNTHETIC_PKCE_SECRET"
  testthat::local_mocked_bindings(.oauth_with_lock = function(code) force(code),
    .oauth_save = function(...) { saved <<- saved + 1L }, .package = "rcodeagent")
  httr2::with_mocked_responses(function(req) {
    calls <<- calls + 1L
    httr2::response(400L, headers = list("content-type" = "application/json"),
      body = charToRaw('{"error":"invalid_grant","error_description":"SYNTHETIC_CODE_SECRET"}'))
  }, {
    err <- tryCatch(.oauth_finish(pending), error = identity)
    expect_s3_class(err, "rcodeagent_connection_http_error")
    expect_identical(err$stage, "oauth")
    expect_match(.connection_error_message(err, "en"), "invalid_grant", fixed = TRUE)
  })
  expect_identical(saved, 0L)
  expect_identical(calls, 1L)
})
