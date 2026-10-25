test_that("Normal keeps an empty unsaved document unchanged until Auto activation", {
  editor <- .local_unsaved_editor()
  rcodeagent:::.save_preferences("es")
  shiny::testServer(rcodeagent:::.rcodeagent_server, {
    session$setInputs(model = "test-model", mode = "normal")
    expect_match(output$target_label, "Documento sin guardar", fixed = TRUE)
    expect_match(output$target_label, "unsaved-a", fixed = TRUE)
    session$setInputs(submit_request = list(text = "Escribe el código"))
    expect_false(editor$can_edit)
    expect_length(editor$writes, 0L)
    session$setInputs(apply = 1, confirm_apply = 1)
    expect_length(editor$writes, 0L)
    session$setInputs(auto_requested = TRUE)
    editor$current <- "saved-b"
    session$setInputs(submit_request = list(text = "Escribe el código"))
    expect_identical(editor$writes[[1L]]$id, "unsaved-a")
    expect_identical(editor$docs[["saved-b"]]$text, "previous <- 99")
  })
})


test_that("Auto requires explicit activation but supports an empty unsaved source buffer", {
  editor <- .local_unsaved_editor()
  shiny::testServer(rcodeagent:::.rcodeagent_server, {
    session$setInputs(model = "test-model", mode = "normal", capture_document = 1)
    expect_false(auto_mode())
    session$setInputs(auto_requested = TRUE)
    expect_true(auto_mode())
    session$setInputs(submit_request = list(text = "Inserta código R aquí"))
    expect_true(editor$can_edit)
    expect_length(editor$writes, 1L)
    expect_identical(editor$writes[[1L]]$id, "unsaved-a")
    expect_true(history()[[2L]]$edit_applied)
    expect_identical(editor$docs[["saved-b"]]$text, "previous <- 99")
  })
})

test_that("an empty unsaved document still blocks conflicting contents", {
  editor <- .local_unsaved_editor()
  captured <- rcodeagent:::.snapshot_editor()
  editor$docs[["unsaved-a"]]$text <- "manual <- 1"
  expect_error(rcodeagent:::.safe_editor_apply(captured, "qa_value <- 2"), "cambió")
  expect_length(editor$writes, 0L)
})

test_that("the current empty buffer identity overrides old document references in history", {
  snapshot <- list(id = "unsaved-a", path = "", full = "", text = "", range = NULL, scope = "documento")
  prompt <- rcodeagent:::.construct_prompt("auto", "Pega el código aquí", snapshot,
    list(list(role = "Asistente", text = "El documento anterior era previous.R", code = "x <- 1")))
  expect_match(prompt, "ID del editor: unsaved-a", fixed = TRUE)
  expect_match(prompt, "Documento sin guardar", fixed = TRUE)
  expect_match(prompt, "vacío", fixed = TRUE)
  expect_false(grepl("sin nombre o sin documento", prompt, fixed = TRUE))
})

test_that("the console can never be used as an unnamed editing target", {
  testthat::local_mocked_bindings(isAvailable = function(...) TRUE,
    getSourceEditorContext = function(...) list(id = "#console", path = "", contents = ""), .package = "rstudioapi")
  expect_error(rcodeagent:::.snapshot_editor(), "documento")
})

test_that("Archivo activo follows a new unsaved tab at dispatch and revokes the old grant", {
  editor <- .local_unsaved_editor()
  editor$current <- "saved-b"
  shiny::testServer(rcodeagent:::.rcodeagent_server, {
    session$setInputs(model = "test-model", mode = "normal", capture_document = 1)
    session$setInputs(auto_requested = TRUE)
    expect_true(auto_mode())
    editor$current <- "unsaved-a"
    session$setInputs(submit_request = list(text = "Escribe aquí"))
    expect_identical(snap()$id, "unsaved-a")
    expect_match(editor$prompt, "ID del editor: unsaved-a", fixed = TRUE)
    expect_false(auto_mode())
    expect_length(editor$writes, 0L)
    expect_equal(output$can_edit, "false")
    session$setInputs(apply = 1)
    session$setInputs(confirm_apply = 1)
    expect_identical(editor$docs[["unsaved-a"]]$text, "")
    session$setInputs(auto_requested = TRUE)
    session$setInputs(submit_request = list(text = "Ahora escribe aquí"))
    expect_identical(editor$docs[["unsaved-a"]]$text, "qa_value <- 2")
    expect_identical(editor$docs[["saved-b"]]$text, "previous <- 99")
  })
})

test_that("a file-picker target stays pinned when the active tab changes", {
  editor <- .local_unsaved_editor()
  testthat::local_mocked_bindings(.select_editor_target = function() rcodeagent:::.snapshot_editor(id = "unsaved-a"),
    .package = "rcodeagent")
  shiny::testServer(rcodeagent:::.rcodeagent_server, {
    session$setInputs(model = "test-model", mode = "normal", choose_target = 1)
    session$setInputs(auto_requested = TRUE)
    editor$current <- "saved-b"
    session$setInputs(submit_request = list(text = "Escribe en el destino elegido"))
    expect_true(auto_mode())
    expect_identical(editor$writes[[1L]]$id, "unsaved-a")
    expect_identical(editor$docs[["saved-b"]]$text, "previous <- 99")
  })
})

test_that("a failed active-file refresh never dispatches stale context", {
  editor <- .local_unsaved_editor()
  shiny::testServer(rcodeagent:::.rcodeagent_server, {
    session$setInputs(model = "test-model", mode = "normal", capture_document = 1)
    session$setInputs(auto_requested = TRUE)
    editor$current <- "#console"
    session$setInputs(submit_request = list(text = "Escribe aquí"))
    expect_false(auto_mode())
    expect_null(snap())
    expect_null(editor$prompt)
    expect_length(editor$writes, 0L)
  })
})

test_that("eligibility distinguishes empty source buffers, missing editors and saved non-R files", {
  snapshot <- list(id = "source-1", path = "", full = "")
  expect_true(rcodeagent:::.editor_allows_r(snapshot))
  expect_false(rcodeagent:::.editor_allows_r(modifyList(snapshot, list(path = "query.sql"))))
  expect_false(rcodeagent:::.editor_allows_r(modifyList(snapshot, list(id = "#console"))))
  expect_false(rcodeagent:::.editor_allows_r(modifyList(snapshot, list(id = ""))))
  expect_match(rcodeagent:::.editor_label(snapshot, "en"), "Unsaved document", fixed = TRUE)
})
