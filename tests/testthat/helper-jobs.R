# Unit fixtures complete synchronously; cancellation uses a separate real-worker test.
.local_jobs <- function(envir = parent.frame()) {
  testthat::local_mocked_bindings(
  .start_request = function(prompt, model, can_edit, mode, effort) {
    result <- rcodeagent:::.assistant_reply(prompt, model, can_edit, mode, effort)
    list(is_alive = function() FALSE, get_result = function() result, kill = function() TRUE)
  }, .package = "rcodeagent", .env = envir
  )
  withr::local_options(rcodeagent.history_dir = tempfile("rcodeagent-history-"),
    rcodeagent.preferences_file = tempfile("rcodeagent-test-preferences-", fileext = ".json"),
    .local_envir = envir)
}
