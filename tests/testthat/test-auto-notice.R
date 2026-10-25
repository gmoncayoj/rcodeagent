test_that("Auto activation shows one five-second notice despite menu synchronization", {
  withr::local_options(rcodeagent.preferences_file = tempfile())
  .local_unsaved_editor()
  notices <- list()
  testthat::local_mocked_bindings(showNotification = function(ui, ..., duration = 5, id = NULL) {
    if (identical(id, "rcodeagent-auto-notice")) {
      notices[[length(notices) + 1L]] <<- list(duration = duration, id = id)
    }
    "test-notice"
  }, .package = "shiny")
  shiny::testServer(rcodeagent:::.rcodeagent_server, {
    session$setInputs(mode = "normal", model = "test-model")
    session$setInputs(auto_requested = TRUE)
    session$setInputs(mode = "auto") # Client reflects updateRadioButtons after the shield click.
    expect_true(auto_mode())
    expect_length(notices, 1L)
    expect_equal(notices[[1L]]$duration, 5)
    expect_identical(notices[[1L]]$id, "rcodeagent-auto-notice")
    session$setInputs(mode = "normal")
    session$setInputs(mode = "auto")
    expect_length(notices, 2L)
    expect_identical(notices[[2L]], notices[[1L]]) # Replace an existing notice; never stack another ID.
  })
})
