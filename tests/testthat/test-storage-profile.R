.local_profile <- function(envir = parent.frame()) {
  root <- withr::local_tempdir(.local_envir = envir)
  testthat::local_mocked_bindings(R_user_dir = function(package, which = c("data", "config", "cache")) {
    file.path(root, package, which[[1L]])
  }, .package = "tools", .env = envir)
  testthat::local_mocked_bindings(.storage_state = new.env(parent = emptyenv()),
    .package = "rcodeagent", .env = envir)
  root
}

test_that("a new installation uses the new profile and keyring service", {
  root <- .local_profile()
  expect_identical(.storage_app_name(), "rcodeagent")
  expect_identical(.oauth_service(), "rcodeagent-ChatGPT-OAuth")
  expect_equal(.storage_dir("data"), file.path(root, "rcodeagent", "data"))
})

test_that("an existing profile is reused without copying private files", {
  root <- .local_profile()
  old <- paste0("RStudio", "GPT")
  config <- file.path(root, old, "config")
  data <- file.path(root, old, "data")
  dir.create(config, recursive = TRUE)
  dir.create(file.path(data, "conversations"), recursive = TRUE)
  writeLines("synthetic-host", file.path(config, "host-id.txt"))
  writeLines('{"language":"en"}', file.path(config, "preferences.json"))
  writeBin(as.raw(1:30), file.path(data, "oauth-credentials.bin"))
  expect_identical(.storage_app_name(), old)
  expect_equal(.oauth_config_path(), file.path(config, "host-id.txt"))
  expect_identical(.oauth_host_id(), "synthetic-host")
  expect_equal(.oauth_secret_file(), file.path(data, "oauth-credentials.bin"))
  expect_equal(.oauth_service(), paste0(old, "-ChatGPT-OAuth"))
  service <- NULL
  testthat::local_mocked_bindings(key_get = function(service, username) {
    stopifnot(username == "local-key")
    service_used <<- service
    sodium::bin2hex(as.raw(seq_len(32L)))
  }, .package = "keyring")
  service_used <- NULL
  expect_identical(.oauth_encryption_key(), as.raw(seq_len(32L)))
  expect_identical(service_used, paste0(old, "-ChatGPT-OAuth"))
  expect_equal(.read_preferences()$language, "en")
  expect_equal(.conversation_dir(), normalizePath(file.path(data, "conversations"), winslash = "/"))
  expect_false(dir.exists(file.path(root, "rcodeagent")))
})

test_that("an existing new profile wins and the choice is stable for the Job", {
  root <- .local_profile()
  old <- paste0("RStudio", "GPT")
  dir.create(file.path(root, old, "data"), recursive = TRUE)
  dir.create(file.path(root, "rcodeagent", "config"), recursive = TRUE)
  expect_equal(.storage_app_name(), "rcodeagent")
  expect_equal(.oauth_service(), "rcodeagent-ChatGPT-OAuth")
  # Removing the new directory later must not silently switch credential stores.
  unlink(file.path(root, "rcodeagent"), recursive = TRUE)
  expect_equal(.storage_app_name(), "rcodeagent")
})

test_that("model workers retain the profile chosen by the live Job", {
  root <- .local_profile()
  expect_equal(.storage_app_name(), "rcodeagent")
  # Another process creates a previous profile after this Job chose the new one.
  dir.create(file.path(root, paste0("RStudio", "GPT"), "data"), recursive = TRUE)
  job <- .start_request(root, "synthetic", FALSE, "ask", "medium",
    worker_reply = function(prompt, ...) {
      testthat::with_mocked_bindings(
        get(".storage_app_name", asNamespace("rcodeagent"))(),
        R_user_dir = function(package, which = c("data", "config", "cache")) {
          file.path(prompt, package, which[[1L]])
        }, .package = "tools")
    })
  withr::defer(.cancel_request(job))
  deadline <- Sys.time() + 20
  while (job$is_alive() && Sys.time() < deadline) Sys.sleep(0.05)
  expect_false(job$is_alive())
  expect_identical(job$get_result(), "rcodeagent")
})
