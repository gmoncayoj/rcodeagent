test_that("Viewer admission binds host, origin and the private initial fragment", {
  origin <- "http://127.0.0.1:18555"
  key <- strrep("a", 64)
  request <- list(HTTP_HOST = "127.0.0.1:18555", HTTP_ORIGIN = origin)
  expect_true(.viewer_client_allowed(request, paste0("#rcodeagent=", key), origin, key))
  for (bad_origin in c("https://untrusted.example", "null", "http://localhost:18555", paste0(origin, "/"), "")) {
    bad <- request; bad$HTTP_ORIGIN <- bad_origin
    expect_false(.viewer_client_allowed(bad, paste0("#rcodeagent=", key), origin, key))
  }
  expect_false(.viewer_client_allowed(request, "", origin, key))
  expect_false(.viewer_client_allowed(request, paste0("#rcodeagent=", strrep("b", 64)), origin, key))
  request$HTTP_HOST <- "untrusted.example"
  expect_false(.viewer_client_allowed(request, paste0("#rcodeagent=", key), origin, key))
})

test_that("a rejected client cannot start lifecycle or claim the recovery state", {
  testthat::local_mocked_bindings(randomPort = function(...) 18555L, .package = "httpuv")
  startup <- NULL; stopped <- 0L; closed <- 0L; initialized <- 0L
  state <- tempfile(fileext = ".json")
  withr::defer(unlink(state))
  testthat::local_mocked_bindings(.rstudio_call = function(...) TRUE,
    .rcodeagent_server = function(...) { initialized <<- initialized + 1L }, .package = "rcodeagent")
  testthat::local_mocked_bindings(later = function(func, delay) { startup <<- func }, .package = "later")
  testthat::local_mocked_bindings(stopApp = function(...) { stopped <<- stopped + 1L },
    runApp = function(appDir, ...) {
      server <- appDir$serverFuncSource()
      server(NULL, NULL, list(request = list(HTTP_HOST = "untrusted.example", HTTP_ORIGIN = "https://untrusted.example"),
        clientData = list(url_hash_initial = ""), close = function() { closed <<- closed + 1L }))
      expect_equal(closed, 1L)
      expect_equal(initialized, 0L)
      startup()
      expect_equal(stopped, 1L)
    }, .package = "shiny")
  .run_background_app(state)
})

test_that("Viewer URLs permit only a loopback root and a fixed capability fragment", {
  good <- paste0("http://127.0.0.1:18555/#rcodeagent=", strrep("a", 64))
  expect_true(.viewer_url_allowed(good, require_capability = TRUE))
  expect_false(.viewer_url_allowed("http://127.0.0.1:18555/", require_capability = TRUE))
  for (bad in c(sub("127.0.0.1", "untrusted.example", good, fixed = TRUE),
    sub(":18555", ":99999", good, fixed = TRUE), paste0(good, "extra"),
    sub("/#", "/other#", good, fixed = TRUE))) expect_false(.viewer_url_allowed(bad))
})
