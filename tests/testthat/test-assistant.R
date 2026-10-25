test_that("assistant proposals are validated and never inferred from prose", {
  answer <- rcodeagent:::.interpret_response(list(text = "Explico la función.", calls = list()))
  expect_equal(answer$action, "chat")
  expect_equal(answer$code, "")
  proposal <- list(type = "function_call", name = "propose_editor_edit",
                   arguments = '{"explanation":"Ignorar NA","code":"x <- mean(1:3)"}')
  answer <- rcodeagent:::.interpret_response(list(text = "", calls = list(proposal)))
  expect_equal(answer$action, "modify")
  expect_equal(answer$code, "x <- mean(1:3)")
  expect_equal(answer$message, "Ignorar NA")
  proposal$name <- "propose_new_script"
  expect_equal(rcodeagent:::.interpret_response(list(text = "", calls = list(proposal)))$action, "generate")
  proposal$name <- "execute_R"
  expect_error(rcodeagent:::.interpret_response(list(text = "", calls = list(proposal))))
})

test_that("malformed and ambiguous proposals fail closed", {
  call <- list(name = "propose_editor_edit", arguments = "not json")
  expect_error(rcodeagent:::.interpret_response(list(text = "", calls = list(call))))
  call$arguments <- '{"explanation":"Cambio","code":"x <-"}'
  expect_error(rcodeagent:::.interpret_response(list(text = "", calls = list(call))))
  call$arguments <- '{"explanation":"Cambio","code":null}'
  expect_error(rcodeagent:::.interpret_response(list(text = "", calls = list(call))))
  expect_error(rcodeagent:::.interpret_response(list(text = "", calls = list(call, call))))
  call$arguments <- '{"explanation":"Cambio","code":"x <- 2","path":"secret.R"}'
  expect_error(rcodeagent:::.interpret_response(list(text = "", calls = list(call))))
})

test_that("automatic prompt includes document identity and no arbitrary file access", {
  snapshot <- list(path = "C:/project/analysis.R", scope = "documento", text = "x <- 1")
  prompt <- rcodeagent:::.construct_prompt("auto", "Explica esto", snapshot, mode = "auto")
  expect_match(prompt, "analysis.R", fixed = TRUE)
  expect_match(prompt, "x <- 1", fixed = TRUE)
  expect_match(prompt, "conserva", fixed = TRUE)
  expect_error(rcodeagent:::.construct_prompt("auto", "  ", snapshot))
  prompt <- rcodeagent:::.construct_prompt("auto", "Aclara esto", snapshot,
    list(list(role = "Asistente", text = "Propuesta", code = "y <- mean(1:3)")))
  expect_match(prompt, "y <- mean(1:3)", fixed = TRUE)
})
