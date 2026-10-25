test_that("provider usage survives the streamed response and reply boundary", {
  usage <- list(input_tokens = 1000, output_tokens = 200, total_tokens = 1200)
  message <- list(type = "message", content = list(list(type = "output_text", text = "Respuesta")))
  result <- rcodeagent:::.read_response(function() list(data = jsonlite::toJSON(
    list(type = "response.completed", response = list(output = list(message), usage = usage)), auto_unbox = TRUE)), TRUE)
  expect_equal(result$usage, usage)
  testthat::local_mocked_bindings(.responses_stream = function(...) result, .package = "rcodeagent")
  expect_equal(rcodeagent:::.assistant_reply("Consulta", "test-model", mode = "auto")$usage, usage)
  expect_equal(rcodeagent:::.token_label(1200, 262000), "1,200/262,000")
  expect_match(rcodeagent:::.token_label(1200, 262000, TRUE), "≈", fixed = TRUE)
  expect_null(rcodeagent:::.normalize_usage(list(input_tokens = "fake", output_tokens = 20, total_tokens = 40)))
  expect_true(is.na(rcodeagent:::.model_context_limit("unknown")))
})

test_that("an explicitly chosen editor is targeted even when another tab is active", {
  written <- NULL
  testthat::local_mocked_bindings(
    getSourceEditorContext = function(id = NULL) {
      if (is.null(id)) list(id = "other", contents = "y <- 99") else {
        list(id = id, contents = "x <- 1")
      }
    },
    callFun = function(fname, location, text, id) { stopifnot(fname == "insertText"); written <<- list(text, id) },
    .package = "rstudioapi"
  )
  rcodeagent:::.safe_editor_apply(list(id = "chosen", full = "x <- 1", range = NULL), "x <- 2")
  expect_equal(written, list("x <- 2", "chosen"))
})

test_that("Auto keeps its chosen target after another tab becomes active", {
  .local_jobs()
  state <- new.env(parent = emptyenv())
  state$text <- "x <- 1"
  state$active <- "chosen"
  state$writes <- character()
  testthat::local_mocked_bindings(
    .snapshot_editor = function(id = NULL) {
      target <- id %||% state$active
      text <- if (target == "chosen") state$text else "y <- 99"
      list(id = target, path = paste0(target, ".R"), full = text, text = text,
        range = NULL, scope = "documento")
    },
    rcodeagent_status = function() "Prueba",
    .models_for_account = function() c(Test = "test-model"),
    .assistant_reply = function(...) list(action = "modify", message = "Cambio", code = "x <- 2"),
    .safe_editor_apply = function(snapshot, code) {
      state$writes <- c(state$writes, snapshot$id)
      state$text <- code
    }, .package = "rcodeagent"
  )
  shiny::testServer(rcodeagent:::.rcodeagent_server, {
    session$setInputs(model = "test-model", mode = "normal", auto_requested = TRUE)
    state$active <- "other"
    session$setInputs(submit_request = list(text = "Cambiar"))
    expect_equal(snap()$id, "chosen")
    session$setInputs(submit_request = list(text = "Cambiar otra vez"))
    expect_equal(state$writes, c("chosen", "chosen"))
    expect_true(auto_mode())
  })
})
