test_that("a failed request cannot reuse a previous code proposal", {
  .local_jobs()
  snapshot <- list(id = "test", path = "test.R", full = "x <- 1",
                   text = "x <- 1", range = NULL, scope = "documento")
  testthat::local_mocked_bindings(
    .snapshot_editor = function() snapshot,
    rcodeagent_status = function() "Sesión de prueba",
    .models_for_account = function() c(Test = "test-model"),
    .assistant_reply = function(prompt, model, can_edit, mode = "normal", effort = "medium") {
      if (grepl("fallar", prompt, fixed = TRUE)) stop("Fallo de prueba")
      list(action = "modify", message = "Cambio propuesto", code = "x <- 2")
    }, .package = "rcodeagent"
  )
  shiny::testServer(rcodeagent:::.rcodeagent_server, {
    session$setInputs(model = "test-model", submit_request = list(text = "cambiar"))
    expect_equal(output$can_edit, "false")
    expect_equal(output$result, "")
    session$setInputs(submit_request = list(text = "fallar"))
    expect_equal(output$has_response, "false")
    expect_equal(output$can_edit, "false")
    expect_equal(output$can_generate, "false")
    expect_null(pending_snap())
  })
})

test_that("ordinary conversation works without an editor and does not enable edits", {
  .local_jobs()
  testthat::local_mocked_bindings(
    .snapshot_editor = function() NULL,
    rcodeagent_status = function() "Sesión de prueba",
    .models_for_account = function() c(Test = "test-model"),
    .assistant_reply = function(prompt, model, can_edit, mode = "normal", effort = "medium") {
      if (can_edit) stop("Editor unexpectedly available")
      list(action = "chat", message = "Respuesta de consulta", code = "")
    }, .package = "rcodeagent"
  )
  shiny::testServer(rcodeagent:::.rcodeagent_server, {
    session$setInputs(model = "", submit_request = list(text = "Pregunta general"))
    expect_equal(response(), "Respuesta de consulta")
    expect_equal(output$can_edit, "false")
    expect_equal(output$can_generate, "false")
    session$setInputs(submit_request = 42)
    expect_equal(response(), "Respuesta de consulta")
  })
})

test_that("changing to read-only mode invalidates a pending edit", {
  .local_jobs()
  snapshot <- list(id = "test", path = "test.R", full = "x <- 1",
                   text = "x <- 1", range = NULL, scope = "documento")
  testthat::local_mocked_bindings(
    .snapshot_editor = function() snapshot,
    rcodeagent_status = function() "Sesión de prueba",
    .models_for_account = function() c(Test = "test-model"),
    .assistant_reply = function(prompt, model, can_edit, mode, effort) {
      list(action = "modify", message = "Cambio propuesto", code = "x <- 2")
    }, .package = "rcodeagent"
  )
  shiny::testServer(rcodeagent:::.rcodeagent_server, {
    session$setInputs(mode = "normal", model = "test-model")
    session$setInputs(submit_request = list(text = "Modifica"))
    expect_equal(output$can_edit, "false")
    session$setInputs(mode = "normal")
    expect_equal(output$can_edit, "false")
    expect_null(pending_snap())
    session$setInputs(submit_request = list(text = "Modifica"))
    expect_equal(output$can_edit, "false")
    expect_equal(proposal(), "")
  })
})
