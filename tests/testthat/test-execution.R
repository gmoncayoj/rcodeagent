.execution_snapshot <- function(text = "x <- 1\ny <- 2", range = NULL) {
  list(id = "qa", path = "qa.R", full = text, text = text, range = range, scope = "documento")
}

test_that("direct execution is limited to explicit bounded current instructions", {
  s <- .execution_snapshot()
  for (prompt in c("Carga la librería lavaan", "activa lavaan", "load package lavaan")) {
    intent <- rcodeagent:::.execution_intent(prompt, s)
    expect_identical(intent$kind, "library")
    expect_true(intent$write)
    expect_identical(rcodeagent:::.execution_code(intent, s), "library(lavaan)")
  }
  intent <- rcodeagent:::.execution_intent("Ejecuta library(lavaan), sin agregarlo al script", s)
  expect_false(intent$write)
  expect_identical(rcodeagent:::.execution_code(intent, s), "library(lavaan)")
  intent <- rcodeagent:::.execution_intent("Carga la librería Rcpp", s)
  expect_identical(rcodeagent:::.execution_code(intent, s), "library(Rcpp)")
  for (prompt in c("No ejecutes la línea 2", "Explica cómo ejecutar la línea 2", "'ejecuta la línea 2'",
      "ejecuta la línea 2 y borra los archivos", "Escribe library(lavaan) en el script")) {
    expect_false(isTRUE(rcodeagent:::.execution_intent(prompt, s)$direct))
  }
})

test_that("execution consent excludes quoted and deferred instructions", {
  s <- .execution_snapshot()
  for (text in c('corrige el comentario que dice "carga datos y ejecuta el análisis"',
      "ejecuta el ejemplo cuando te lo confirme", "run the example after I confirm", "No ejecutes",
      "genera un ejemplo y no lo ejecutes", "Explica cómo ejecutar", "'ejecuta'",
      "corrige el comentario que dice «carga datos y ejecuta el análisis»",
      "corrige el comentario que dice “carga datos y ejecuta el análisis”",
      "corrige el código y ejecútalo, no, mejor solo revísalo")) {
    intent <- rcodeagent:::.execution_intent(text, s)
    expect_false(isTRUE(intent$authorized) || isTRUE(intent$direct))
  }
  for (text in c("genera y ejecuta un ejemplo", "corrige y ejecútalo", "corrige este bloque y ejecútalo", "create and run an example")) {
    expect_true(rcodeagent:::.execution_intent(text, s)$authorized)
  }
})

test_that("console submission refuses pending console input and uses a fixed public call", {
  sent <- list()
  console <- "x <-"
  s <- .execution_snapshot()
  testthat::local_mocked_bindings(.rstudio_call = function(method, ...) {
    if (method == "getConsoleEditorContext") return(list(id = "#console", contents = console))
    if (method == "getSourceEditorContext") return(list(id = s$id, path = s$path, contents = strsplit(s$full, "\n")[[1L]]))
    sent[[length(sent) + 1L]] <<- c(list(method = method), list(...))
    NULL
  }, .package = "rcodeagent")
  expect_error(rcodeagent:::.submit_console_execution("x <- 1", s), "pendiente")
  expect_length(sent, 0L)
  console <- ""
  expect_silent(rcodeagent:::.submit_console_execution("x <- 1", s))
  expect_identical(sent[[1L]], list(method = "sendToConsole", code = "x <- 1", execute = TRUE, echo = TRUE, focus = FALSE, animate = FALSE))
  console <- NULL
  expect_error(rcodeagent:::.submit_console_execution("x <- 1", s), "consola")
  expect_error(rcodeagent:::.native_api_expression("sendToConsole", list(code = "1", execute = FALSE)))
  expression <- rcodeagent:::.native_api_expression("sendToConsole", list(code = "1", execute = TRUE, echo = TRUE, focus = FALSE, animate = FALSE))
  expect_identical(as.character(expression[[1L]])[[3L]], "sendToConsole")
})

test_that("target validation follows the last console input check before submission", {
  captured <- .execution_snapshot()
  actual <- captured
  sent <- FALSE
  testthat::local_mocked_bindings(.rstudio_call = function(method, ...) {
    if (method == "getConsoleEditorContext") {
      actual$full <<- "manual <- 99"
      return(list(id = "#console", contents = ""))
    }
    if (method == "getSourceEditorContext") return(list(id = actual$id, path = actual$path, contents = actual$full))
    sent <<- TRUE
  }, .package = "rcodeagent")
  expect_error(rcodeagent:::.submit_console_execution("x <- 1", captured), class = "rcodeagent_editor_conflict")
  expect_false(sent)
})

test_that("line ranges are exact complete expressions from the chosen full document", {
  s <- .execution_snapshot("# primera\nx <- 'á'\ny <- 3")
  expect_identical(rcodeagent:::.execution_code(rcodeagent:::.execution_intent("ejecuta la línea 2", s), s), "x <- 'á'")
  expect_identical(rcodeagent:::.execution_code(rcodeagent:::.execution_intent("run lines 2 to 3", s), s), "x <- 'á'\ny <- 3")
  for (instruction in c("ejecuta la línea 0", "ejecuta la línea 4", "ejecuta la línea 1")) {
    expect_error(rcodeagent:::.execution_code(rcodeagent:::.execution_intent(instruction, s), s))
  }
  multi <- .execution_snapshot("x <- mean(\n  1:3\n)")
  expect_error(rcodeagent:::.execution_code(rcodeagent:::.execution_intent("ejecuta la línea 2", multi), multi), "completa")
  expect_identical(rcodeagent:::.execution_code(rcodeagent:::.execution_intent("ejecuta las líneas 1 a 3", multi), multi), multi$full)
  crlf <- .execution_snapshot("x <- 1\r\ny <- 2")
  expect_identical(rcodeagent:::.execution_code(rcodeagent:::.execution_intent("ejecuta la línea 2", crlf), crlf), "y <- 2")
})

test_that("one-use execution authorization is bound to its request owner target and code", {
  s <- .execution_snapshot()
  grant <- rcodeagent:::.new_execution_grant("request", 1L, s, "x <- 1")
  expect_true(rcodeagent:::.consume_execution_grant(grant, "request", 1L, s, "x <- 1"))
  expect_false(rcodeagent:::.consume_execution_grant(grant, "request", 1L, s, "x <- 1"))
  for (field in c("id", "path", "full", "text", "scope", "range")) {
    changed <- s
    changed[[field]] <- "different"
    grant <- rcodeagent:::.new_execution_grant("request", 1L, s, "x <- 1")
    expect_false(rcodeagent:::.consume_execution_grant(grant, "request", 1L, changed, "x <- 1"))
    expect_false(rcodeagent:::.consume_execution_grant(grant, "request", 1L, s, "x <- 1"))
  }
  for (case in list(list("other", 1L, "x <- 1"), list("request", 2L, "x <- 1"), list("request", 1L, "x <- 2"))) {
    grant <- rcodeagent:::.new_execution_grant("request", 1L, s, "x <- 1")
    expect_false(rcodeagent:::.consume_execution_grant(grant, case[[1L]], case[[2L]], s, case[[3L]]))
  }
  expect_error(rcodeagent:::.new_execution_grant("request", 1L, s, ""))
  expect_error(rcodeagent:::.new_execution_grant("request", 1L, s, "x <-"))
  expect_error(rcodeagent:::.new_execution_grant("request", 1L, s, paste(rep("1", 60001), collapse = "")))
})

test_that("additional administrative controls exclude explicitly approved package installation", {
  for (code in c('unlink("data.csv")', 'base::system("whoami")',
      'do.call("unlink", list("data.csv"))', 'get("unlink")("data.csv")', 'q()')) {
    expect_true(rcodeagent:::.execution_requires_review(code))
  }
  expect_false(rcodeagent:::.execution_requires_review("mean(1:3)"))
  expect_false(rcodeagent:::.execution_requires_review("library(lavaan)"))
  expect_false(rcodeagent:::.execution_requires_review('utils::install.packages("lavaan")'))
  intent <- rcodeagent:::.execution_intent("instala el paquete lavaan", .execution_snapshot())
  expect_true(intent$direct)
  expect_identical(rcodeagent:::.execution_code(intent, .execution_snapshot()), 'install.packages("lavaan")')
})

test_that("unparseable surrounding source cannot hide an incomplete line boundary", {
  for (text in c("if (FALSE) {\n  x <- 1\n}\nbroken <-", "broken <- (\n  x <- 1")) {
    snapshot <- .execution_snapshot(text)
    intent <- rcodeagent:::.execution_intent("ejecuta la línea 2", snapshot)
    expect_error(rcodeagent:::.execution_code(intent, snapshot), "completa|comprobar")
  }
})
