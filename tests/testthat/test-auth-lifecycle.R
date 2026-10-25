.local_oauth_storage <- function(envir = parent.frame()) {
  root <- withr::local_tempdir(.local_envir = envir)
  key <- sodium::random(32L)
  testthat::local_mocked_bindings(
    .storage_dir = function(which) file.path(root, which),
    .oauth_encryption_key = function(create = FALSE) key,
    .package = "rcodeagent", .env = envir)
  root
}

.synthetic_credential <- function(expired = TRUE) list(
  client_id = "oaiapp_synthetic", subject = "synthetic-subject", email = "test@example.invalid",
  access_token = "TEST_ACCESS_OLD", refresh_token = "TEST_REFRESH_OLD",
  scopes = c("openid", "chatgpt.tokens.use.direct"),
  expires_at = as.numeric(Sys.time()) + if (expired) -5 else 1800)

.oauth_test_response <- function(body, status = 200L) httr2::response(status_code = status,
  headers = list("content-type" = "application/json"),
  body = charToRaw(jsonlite::toJSON(body, auto_unbox = TRUE)))

test_that("changing accounts retains separate token-free client registrations", {
  .local_oauth_storage()
  first <- .synthetic_credential()
  second <- first
  second$client_id <- "oaiapp_second"
  second$subject <- "second-subject"
  .oauth_save_registration(first)
  .oauth_save_registration(second)
  expect_identical(.oauth_registration()$client_id, second$client_id)
  for (record in list(first, second)) {
    saved <- jsonlite::fromJSON(.oauth_registration_path(record$client_id))
    expect_identical(saved$client_id, record$client_id)
    expect_identical(saved$subject, record$subject)
    expect_setequal(names(saved), c("client_id", "subject", "email"))
  }
  expect_error(.oauth_registration_path("../../invalid"), "OAuth")
  second$subject <- "unexpected-subject"
  expect_error(.oauth_save_registration(second), "sesión anterior")
})

test_that("refresh rotates once and revalidates the granted plan scope", {
  .local_oauth_storage()
  .oauth_save(.synthetic_credential())
  calls <- 0L
  httr2::with_mocked_responses(function(req) {
    calls <<- calls + 1L
    .oauth_test_response(list(access_token = "TEST_ACCESS_NEW", refresh_token = "TEST_REFRESH_NEW",
      expires_in = 3600, scope = "openid chatgpt.tokens.use.direct"))
  }, {
    expect_identical(.oauth_get_token(), "TEST_ACCESS_NEW")
    expect_identical(.oauth_get_token(), "TEST_ACCESS_NEW")
  })
  expect_identical(calls, 1L)
  expect_identical(.oauth_credential()$refresh_token, "TEST_REFRESH_NEW")
  .oauth_save(.synthetic_credential())
  httr2::with_mocked_responses(function(req) .oauth_test_response(list(
    access_token = "TEST_ACCESS_NEW", refresh_token = "TEST_REFRESH_NEW", expires_in = 3600,
    scope = "openid profile")), expect_error(.oauth_get_token(), "permiso"))
  expect_false("chatgpt.tokens.use.direct" %in% unlist(.oauth_credential()$scopes))
})

test_that("malformed refresh responses cannot replace a usable local record", {
  .local_oauth_storage()
  for (bad in list(
    list(access_token = "", refresh_token = "TEST_REFRESH_NEW", expires_in = 3600),
    list(access_token = "TEST_ACCESS_NEW", refresh_token = "", expires_in = 3600),
    list(access_token = c("one", "two"), refresh_token = "TEST_REFRESH_NEW", expires_in = 3600),
    list(access_token = "TEST_ACCESS_NEW", refresh_token = "TEST_REFRESH_NEW", expires_in = -1),
    "malformed-json-value", list(access_token = "TEST_ACCESS_NEW", refresh_token = "TEST_REFRESH_NEW", expires_in = Inf))) {
    .oauth_save(.synthetic_credential())
    httr2::with_mocked_responses(function(req) .oauth_test_response(bad),
      expect_error(.oauth_get_token(), "renovación|respuesta|token"))
    expect_identical(.oauth_credential()$refresh_token, "TEST_REFRESH_OLD")
  }
})

test_that("interrupted replacement recovers the previous encrypted record", {
  .local_oauth_storage()
  .oauth_save(.synthetic_credential(FALSE))
  file <- .oauth_secret_file()
  expect_true(file.rename(file, paste0(file, ".bak")))
  expect_identical(.oauth_with_lock(.oauth_credential())$access_token, "TEST_ACCESS_OLD")
  expect_true(file.exists(file))
  expect_false(file.exists(paste0(file, ".bak")))
})

test_that("two processes serialize refresh and reuse the rotated credential", {
  root <- .local_oauth_storage()
  .oauth_save(.synthetic_credential())
  key <- .oauth_encryption_key()
  package <- getNamespaceInfo(asNamespace("rcodeagent"), "path")
  worker <- function(root, key, package, number) {
    if (file.exists(file.path(package, "R", "addin.R"))) pkgload::load_all(package, quiet = TRUE) else {
      loadNamespace("rcodeagent", lib.loc = dirname(package))
    }
    testthat::with_mocked_bindings({
      file.create(file.path(root, paste0("ready-", number)))
      deadline <- Sys.time() + 15
      while (!file.exists(file.path(root, "go"))) {
        if (Sys.time() > deadline) stop("Synthetic barrier timed out")
        Sys.sleep(0.02)
      }
      identical(rcodeagent:::.oauth_get_token(), "TEST_ACCESS_NEW")
    }, .storage_dir = function(which) file.path(root, which),
    .oauth_encryption_key = function(create = FALSE) key,
    .oauth_refresh_request = function(cred) {
      cat("refresh\n", file = file.path(root, "requests"), append = TRUE)
      Sys.sleep(0.5)
      list(access_token = "TEST_ACCESS_NEW", refresh_token = "TEST_REFRESH_NEW", expires_in = 3600)
    }, .package = "rcodeagent")
  }
  workers <- lapply(1:2, function(i) callr::r_bg(worker, list(root, key, package, i),
    libpath = .libPaths(), supervise = TRUE))
  on.exit(lapply(workers, function(p) if (p$is_alive()) p$kill_tree()), add = TRUE)
  deadline <- Sys.time() + 20
  while (!all(file.exists(file.path(root, paste0("ready-", 1:2))))) {
    if (Sys.time() > deadline) stop("Synthetic workers failed to start")
    Sys.sleep(0.02)
  }
  file.create(file.path(root, "go"))
  for (p in workers) { p$wait(15000); expect_true(p$get_result()) }
  expect_identical(readLines(file.path(root, "requests")), "refresh")
  expect_identical(.oauth_credential()$refresh_token, "TEST_REFRESH_NEW")
})

test_that("unavailable remote revocation still removes the local credential", {
  .local_oauth_storage()
  .oauth_save(.synthetic_credential(FALSE))
  httr2::with_mocked_responses(function(req) .oauth_test_response(list(error = "offline"), 400L),
    result <- .oauth_disconnect())
  expect_false(result$remote_revoked)
  expect_true(result$local_removed)
  expect_null(.oauth_credential())
})

test_that("registration metadata write failure cannot prevent signout or terminal invalidation", {
  .local_oauth_storage()
  .oauth_save(.synthetic_credential())
  revoked <- FALSE
  testthat::local_mocked_bindings(.oauth_save_registration = function(...) stop("Synthetic disk failure"),
    .oauth_revoke = function(...) { revoked <<- TRUE; TRUE }, .package = "rcodeagent")
  result <- .oauth_disconnect()
  expect_true(revoked)
  expect_true(result$remote_revoked)
  expect_null(.oauth_credential())
})

test_that("a terminal refresh error survives failed auxiliary metadata persistence", {
  .local_oauth_storage()
  .oauth_save(.synthetic_credential())
  testthat::local_mocked_bindings(.oauth_save_registration = function(...) stop("Synthetic disk failure"),
    .package = "rcodeagent")
  httr2::with_mocked_responses(function(req) .oauth_test_response(list(error = "invalid_grant"), 400L),
    expect_error(.oauth_get_token(), class = "rcodeagent_auth_terminal"))
  expect_null(.oauth_credential())
})

test_that("terminal refresh errors invalidate tokens but preserve the registration", {
  .local_oauth_storage()
  for (code in c("invalid_grant", "refresh_token_reused", "refresh_token_invalidated")) {
    .oauth_save(.synthetic_credential())
    httr2::with_mocked_responses(function(req) .oauth_test_response(list(error = code), 400L),
      expect_error(.oauth_get_token(), class = "rcodeagent_auth_terminal"))
    expect_null(.oauth_credential())
    expect_identical(.oauth_registration()$client_id, "oaiapp_synthetic")
    expect_false(any(c("access_token", "refresh_token", "id_token") %in% names(.oauth_registration())))
  }
})

test_that("temporary provider failures preserve the encrypted session", {
  .local_oauth_storage()
  .oauth_save(.synthetic_credential())
  httr2::with_mocked_responses(function(req) .oauth_test_response(list(error = "server_error"), 503L),
    expect_error(.oauth_get_token()))
  expect_identical(.oauth_credential()$refresh_token, "TEST_REFRESH_OLD")
})

test_that("disconnect attempts discovered revocation before removing local tokens", {
  .local_oauth_storage()
  .oauth_save(.synthetic_credential(FALSE))
  routes <- character()
  httr2::with_mocked_responses(function(req) {
    routes <<- c(routes, req$url)
    if (grepl("openid-configuration$", req$url)) return(.oauth_test_response(list(
      revocation_endpoint = "https://auth.openai.com/api/accounts/oauth/revoke")))
    expect_false(req$options$followlocation)
    expect_true(file.exists(.oauth_secret_file()))
    httr2::response(status_code = 200L, body = raw())
  }, result <- .oauth_disconnect())
  expect_true(result$remote_revoked)
  expect_length(routes, 2L)
  expect_null(.oauth_credential())
  expect_identical(.oauth_registration()$client_id, "oaiapp_synthetic")
})

test_that("revocation rejects foreign endpoints and reports unconfirmed remote signout", {
  .local_oauth_storage()
  .oauth_save(.synthetic_credential(FALSE))
  calls <- 0L
  httr2::with_mocked_responses(function(req) {
    calls <<- calls + 1L
    .oauth_test_response(list(revocation_endpoint = "https://untrusted.example/revoke"))
  }, result <- .oauth_disconnect())
  expect_false(result$remote_revoked)
  expect_equal(calls, 1L)
  expect_null(.oauth_credential())
})

test_that("failed credential replacement restores the previous encrypted record", {
  .local_oauth_storage()
  .oauth_save(.synthetic_credential(FALSE))
  real_move <- file.rename
  testthat::local_mocked_bindings(.oauth_move_file = function(from, to) {
    if (identical(to, .oauth_secret_file()) && !endsWith(from, ".bak")) return(FALSE)
    real_move(from, to)
  }, .package = "rcodeagent")
  expect_error(.oauth_save(within(.synthetic_credential(FALSE), access_token <- "TEST_ACCESS_NEW")))
  expect_identical(.oauth_credential()$access_token, "TEST_ACCESS_OLD")
})
