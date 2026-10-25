test_that("the selected reasoning effort enters the Responses payload", {
  .local_jobs()
  for (value in c("low", "medium", "high", "xhigh")) {
    body <- rcodeagent:::.response_body("Consulta", "test-model", effort = value)
    expect_equal(body$reasoning$effort, value)
    expect_false(body$store)
    expect_true(body$stream)
  }
  for (value in list("ultra", "max", "unknown", NA_character_, c("low", "high"))) {
    expect_error(rcodeagent:::.response_body("Consulta", "test-model", effort = value))
  }
})

test_that("the server forwards input effort and rejects an unauthorized level", {
  .local_jobs()
  received <- character()
  testthat::local_mocked_bindings(
    .snapshot_editor = function() NULL,
    rcodeagent_status = function() "Sesión de prueba",
    .models_for_account = function() c(Test = "test-model"),
    .assistant_reply = function(prompt, model, can_edit, mode, effort) {
      received <<- c(received, effort)
      list(action = "chat", message = "Respuesta", code = "")
    }, .package = "rcodeagent"
  )
  shiny::testServer(rcodeagent:::.rcodeagent_server, {
    session$setInputs(effort = "low", model = "test-model", submit_request = list(text = "Consulta"))
    expect_equal(received, "low")
    session$setInputs(effort = "ultra", submit_request = list(text = "Otra consulta"))
    expect_equal(received, "low")
    expect_equal(output$has_response, "false")
  })
})

test_that("every permission mode forwards the selected effort", {
  .local_jobs()
  testthat::local_mocked_bindings(
    .responses_stream = function(prompt, model, tools = NULL, effort = "medium") {
      if (!identical(effort, "xhigh")) stop("Effort was not forwarded")
      if (is.null(tools)) "Respuesta" else list(text = "Respuesta", calls = list())
    }, .package = "rcodeagent"
  )
  for (mode in c("normal", "auto")) {
    expect_equal(rcodeagent:::.assistant_reply("Consulta", "test-model", mode = mode,
      effort = "xhigh")$message, "Respuesta")
  }
})
