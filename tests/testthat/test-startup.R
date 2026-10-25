test_that("opening a saved session loads account models before the first message", {
  .local_jobs()
  auth_attempts <- 0L
  testthat::local_mocked_bindings(
    .snapshot_editor = function() NULL,
    rcodeagent_status = function() "Sesión OAuth local: cuenta de prueba",
    .models_for_account = function() c("Sol de prueba" = "test-sol", "Luna de prueba" = "test-luna"),
    .oauth_start = function() { auth_attempts <<- auth_attempts + 1L; stop("Unexpected login") },
    .package = "rcodeagent"
  )
  shiny::testServer(rcodeagent:::.rcodeagent_server, {
    session$flushReact()
    session$flushReact() # Render changes made by the initial onFlushed callback.
    expect_equal(unname(catalog()), c("test-sol", "test-luna"))
    expect_equal(output$connection_label, "Conectado")
    session$setInputs(connect = 1)
    expect_equal(auth_attempts, 0L)
  })
})

test_that("a catalog failure is recoverable and preserves the chosen account model", {
  .local_jobs()
  attempt <- 0L
  testthat::local_mocked_bindings(
    .snapshot_editor = function() NULL,
    rcodeagent_status = function() "Sesión OAuth local: cuenta de prueba",
    .models_for_account = function() {
      attempt <<- attempt + 1L
      if (attempt == 1L) stop("Error de red ficticio")
      c("Sol de prueba" = "test-sol", "Luna de prueba" = "test-luna")
    }, .package = "rcodeagent"
  )
  shiny::testServer(rcodeagent:::.rcodeagent_server, {
    session$flushReact()
    expect_length(catalog(), 0L)
    expect_equal(output$connection_label, "Iniciar sesión con ChatGPT")
    expect_match(status(), "Sesión OAuth local", fixed = TRUE)
    session$setInputs(model = "test-luna", check = 1)
    expect_equal(unname(catalog()), c("test-sol", "test-luna"))
    expect_match(status(), "Conectado", fixed = TRUE)
    expect_equal(output$connection_label, "Conectado")
  })
})
