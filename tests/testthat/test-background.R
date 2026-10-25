test_that("launcher returns a native job without importing the user's Environment", {
  state <- new.env(parent = emptyenv())
  state$calls <- 0L
  testthat::local_mocked_bindings(
    isAvailable = function(...) TRUE,
    jobRunScript = function(path, name, encoding, workingDir, importEnv, exportEnv) {
      state$calls <- state$calls + 1L
      state$script <- readLines(path, warn = FALSE)
      state$config <- readRDS(file.path(dirname(path), "config.rds"))
      expect_false(importEnv)
      expect_identical(exportEnv, "")
      expect_identical(workingDir, getwd())
      expect_identical(encoding, "UTF-8")
      "fixture-job"
    },
    jobGetState = function(job) "running",
    .package = "rstudioapi")
  runtime <- rcodeagent:::.background_runtime
  runtime$job <- NULL
  on.exit({ rcodeagent:::.clear_background_runtime(); runtime$job <- NULL }, add = TRUE)
  expect_identical(rcodeagent::rcodeagent(), "fixture-job")
  expect_equal(state$calls, 1L)
  expect_setequal(names(state$config), c("libraries", "package_path", "state_file"))
  expect_true(any(grepl(".run_background_app", state$script, fixed = TRUE)))
  expect_message(rcodeagent::rcodeagent(), "iniciando")
  expect_equal(state$calls, 1L)
})

test_that("reopening a live job validates its Viewer URL and does not start another job", {
  runtime <- rcodeagent:::.background_runtime
  runtime$job <- "fixture-job"
  runtime$directory <- tempfile("rcodeagent-test-")
  dir.create(runtime$directory)
  on.exit(rcodeagent:::.clear_background_runtime(), add = TRUE)
  viewed <- NULL
  testthat::local_mocked_bindings(isAvailable = function(...) TRUE,
    jobGetState = function(job) "running",
    viewer = function(url, height) { viewed <<- url },
    jobRunScript = function(...) stop("Must not launch"), .package = "rstudioapi")
  file <- file.path(runtime$directory, "state.json")
  jsonlite::write_json(list(url = "https://untrusted.example/", status = "running"), file, auto_unbox = TRUE)
  expect_message(rcodeagent::rcodeagent(), "iniciando")
  expect_null(viewed)
  private_url <- paste0("http://127.0.0.1:18555/#rcodeagent=", strrep("a", 64))
  jsonlite::write_json(list(url = private_url, status = "suspended"), file, auto_unbox = TRUE)
  expect_identical(rcodeagent::rcodeagent(), "fixture-job")
  expect_identical(viewed, private_url)
})

test_that("terminated jobs can restart and a failed launch leaves no active runtime", {
  runtime <- rcodeagent:::.background_runtime
  runtime$job <- "old-job"
  runtime$directory <- NULL
  on.exit(rcodeagent:::.clear_background_runtime(), add = TRUE)
  testthat::local_mocked_bindings(isAvailable = function(...) TRUE,
    jobGetState = function(job) "succeeded",
    jobRunScript = function(...) stop("fixture launch failure"), .package = "rstudioapi")
  expect_error(rcodeagent::rcodeagent(), "fixture launch failure")
  expect_null(runtime$job)
  expect_null(runtime$directory)
})

test_that("an unknown native job state never starts a duplicate process", {
  runtime <- rcodeagent:::.background_runtime
  runtime$job <- "uncertain-job"
  runtime$directory <- NULL
  on.exit(rcodeagent:::.clear_background_runtime(), add = TRUE)
  testthat::local_mocked_bindings(isAvailable = function(...) TRUE,
    jobGetState = function(job) list(unexpected = TRUE),
    jobRunScript = function(...) stop("Must not launch"), .package = "rstudioapi")
  expect_error(rcodeagent::rcodeagent(), "estado de trabajo desconocido")
  expect_identical(runtime$job, "uncertain-job")
})

test_that("editor capture permits native child IPC and retains the captured ID", {
  child_ok <- FALSE
  selection <- structure(list(range = rstudioapi::document_range(c(1, 1, 1, 1)), text = ""))
  testthat::local_mocked_bindings(
    isAvailable = function(version_needed = NULL, child_ok = FALSE) child_ok,
    getSourceEditorContext = function(id = NULL) structure(list(id = "selected", path = "synthetic.R",
      contents = "x <- 1", selection = list(selection)), class = "document_context"),
    primary_selection = function(x) selection, .package = "rstudioapi")
  expect_identical(rcodeagent:::.snapshot_editor()$id, "selected")
})

test_that("child app listens only on loopback and records its lifecycle", {
  testthat::local_mocked_bindings(randomPort = function(...) 18555L, .package = "httpuv")
  captured <- NULL
  cancelled <- FALSE
  state_file <- tempfile(fileext = ".json")
  on.exit(unlink(state_file), add = TRUE)
  testthat::local_mocked_bindings(
    .rcodeagent_view = function() shiny::div(),
    .rcodeagent_server = function(input, output, session, ...) NULL,
    .package = "rcodeagent")
  testthat::local_mocked_bindings(
    isAvailable = function(version_needed = NULL, child_ok = FALSE) child_ok,
    viewer = function(url, height) { captured <<- list(url = url, height = height) }, .package = "rstudioapi")
  testthat::local_mocked_bindings(later = function(...) function() { cancelled <<- TRUE }, .package = "later")
  testthat::local_mocked_bindings(runApp = function(appDir, host, port, launch.browser) {
    expect_identical(host, "127.0.0.1")
    expect_identical(port, 18555L)
    launch.browser(paste0("http://127.0.0.1:", port))
    expect_identical(jsonlite::read_json(state_file)$status, "running")
  }, .package = "shiny")
  rcodeagent:::.run_background_app(state_file)
  expect_match(captured$url, "^http://127[.]0[.]0[.]1:")
  expect_equal(captured$height, 650)
  expect_identical(jsonlite::read_json(state_file)$status, "stopped")
  expect_true(cancelled)
})

test_that("Viewer replacement suspends the Job and only its current idle deadline stops it", {
  testthat::local_mocked_bindings(randomPort = function(...) 18555L, .package = "httpuv")
  delayed <- list()
  scheduled_delays <- numeric()
  stops <- 0L
  state_file <- tempfile(fileext = ".json")
  on.exit(unlink(state_file), add = TRUE)
  testthat::local_mocked_bindings(.viewer_client_allowed = function(...) TRUE,
    .rcodeagent_view = function() shiny::div(),
    .rcodeagent_server = function(...) NULL, .package = "rcodeagent")
  testthat::local_mocked_bindings(isAvailable = function(...) TRUE, .package = "rstudioapi")
  startup_check <- NULL
  testthat::local_mocked_bindings(later = function(func, delay) {
    scheduled_delays <<- c(scheduled_delays, delay)
    if (delay == 60) startup_check <<- func else delayed[[length(delayed) + 1L]] <<- func
  }, .package = "later")
  testthat::local_mocked_bindings(stopApp = function(...) { stops <<- stops + 1L },
    runApp = function(appDir, ...) {
      server <- appDir$serverFuncSource()
      ended <- list()
      session <- list(onSessionEnded = function(callback) { ended[[length(ended) + 1L]] <<- callback })
      server(NULL, NULL, session)
      startup_check()
      expect_equal(stops, 0L)
      ended[[1L]]()
      expect_equal(scheduled_delays, c(60, 2, 1800))
      delayed[[1L]]() # The old 2-second shutdown must now enter suspension.
      expect_equal(stops, 0L)
      expect_identical(jsonlite::read_json(state_file)$status, "suspended")
      server(NULL, NULL, session)
      delayed[[2L]]() # A prior idle deadline cannot stop a recovered session.
      delayed[[1L]]()
      expect_equal(stops, 0L)
      ended[[2L]]()
      delayed[[2L]]()
      expect_equal(stops, 0L)
      delayed[[4L]]()
      expect_equal(stops, 1L)
    }, .package = "shiny")
  rcodeagent:::.run_background_app(state_file)
  delayed[[4L]]() # A callback remaining after shutdown cannot stop another app.
  expect_equal(stops, 1L)
})

test_that("a Viewer which never connects cannot leave the job running indefinitely", {
  testthat::local_mocked_bindings(randomPort = function(...) 18555L, .package = "httpuv")
  startup_check <- NULL
  stops <- 0L
  file <- tempfile(fileext = ".json")
  on.exit(unlink(file), add = TRUE)
  testthat::local_mocked_bindings(.rcodeagent_view = function() shiny::div(), .package = "rcodeagent")
  testthat::local_mocked_bindings(isAvailable = function(...) TRUE, .package = "rstudioapi")
  testthat::local_mocked_bindings(later = function(func, delay) { startup_check <<- func }, .package = "later")
  testthat::local_mocked_bindings(stopApp = function(...) { stops <<- stops + 1L },
    runApp = function(...) { startup_check(); expect_equal(stops, 1L) }, .package = "shiny")
  rcodeagent:::.run_background_app(file)
  startup_check()
  expect_equal(stops, 1L)
})
