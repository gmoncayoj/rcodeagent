test_that("completed SSE tool calls become reviewable proposals", {
  events <- list(
    list(data = '{"type":"response.output_text.delta","delta":"Propuesta"}'),
    list(data = ""),
    list(data = '{"type":"response.completed"}')
  )
  # Generate the nested event with a real serializer to avoid escaping ambiguity.
  events[[2L]]$data <- jsonlite::toJSON(list(type = "response.output_item.done",
    item = list(type = "function_call", name = "propose_editor_edit",
      arguments = '{"explanation":"Cambio","code":"x <- 2"}')), auto_unbox = TRUE)
  index <- 0L
  result <- rcodeagent:::.read_response(function() {
    index <<- index + 1L
    if (index > length(events)) NULL else events[[index]]
  }, structured = TRUE)
  expect_equal(result$text, "Propuesta")
  expect_equal(rcodeagent:::.interpret_response(result)$code, "x <- 2")
})

test_that("SSE failure or premature end cannot authorize a proposal", {
  expect_error(rcodeagent:::.read_response(function() NULL, TRUE), "response.completed")
  expect_error(rcodeagent:::.read_response(function() {
    list(data = '{"type":"response.failed","response":{"error":{"code":"denied"}}}')
  }, TRUE), "denied")
})

test_that("a final empty output does not erase a completed tool proposal", {
  call <- list(id = "fc_test", type = "function_call", name = "propose_editor_edit",
    arguments = '{"explanation":"Cambio","code":"x <- 2"}')
  events <- list(list(type = "response.output_item.done", output_index = 0L, item = call),
    list(type = "response.completed", response = list(output = list())))
  i <- 0L
  result <- rcodeagent:::.read_response(function() {
    i <<- i + 1L
    if (i > length(events)) return(NULL)
    list(data = jsonlite::toJSON(events[[i]], auto_unbox = TRUE))
  }, TRUE)
  expect_equal(rcodeagent:::.interpret_response(result)$action, "modify")
  expect_equal(rcodeagent:::.interpret_response(result)$code, "x <- 2")
})

test_that("final text and finalized function arguments are recovered without deltas", {
  message <- list(type = "message", content = list(list(type = "output_text", text = "Respuesta final")))
  result <- rcodeagent:::.read_response(function() list(data = jsonlite::toJSON(
    list(type = "response.completed", response = list(output = list(message))), auto_unbox = TRUE)))
  expect_equal(result, "Respuesta final")
  events <- list(
    list(type = "response.output_item.added", output_index = 0L,
      item = list(id = "fc_test", type = "function_call", name = "propose_editor_edit", arguments = "")),
    list(type = "response.function_call_arguments.done", output_index = 0L, item_id = "fc_test",
      arguments = '{"explanation":"Cambio","code":"x <- 2"}'),
    list(type = "response.completed"))
  i <- 0L
  result <- rcodeagent:::.read_response(function() {
    i <<- i + 1L
    if (i > length(events)) return(NULL)
    list(data = jsonlite::toJSON(events[[i]], auto_unbox = TRUE))
  }, TRUE)
  expect_equal(rcodeagent:::.interpret_response(result)$code, "x <- 2")
})

test_that("tool events and final output refer to one proposal, not duplicates", {
  call <- list(id = "fc_test", type = "function_call", name = "propose_editor_edit",
    arguments = '{"explanation":"Cambio","code":"x <- 2"}')
  events <- list(list(type = "response.output_item.done", output_index = 0L, item = call),
    list(type = "response.completed", response = list(output = list(call))))
  i <- 0L
  result <- rcodeagent:::.read_response(function() {
    i <<- i + 1L
    if (i > length(events)) return(NULL)
    list(data = jsonlite::toJSON(events[[i]], auto_unbox = TRUE))
  }, TRUE)
  expect_length(result$calls, 1L)
  expect_equal(rcodeagent:::.interpret_response(result)$action, "modify")
})
