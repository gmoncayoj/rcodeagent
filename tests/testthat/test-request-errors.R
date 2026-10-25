test_that("worker errors expose the root message without terminal escape sequences", {
  job <- .start_request("synthetic", "synthetic", FALSE, "ask", "medium",
    worker_reply = function(...) stop("\033[31mSynthetic validation failure.\033[0m", call. = FALSE))
  withr::defer(.cancel_request(job))
  job$wait(timeout = 20000)
  err <- tryCatch(job$get_result(), error = identity)
  expect_s3_class(err, "callr_error")
  expect_identical(.request_error_message(err), "Synthetic validation failure.")
})

test_that("direct errors keep their message and remove only terminal formatting", {
  expect_identical(.request_error_message(simpleError("\033[33mCheck the target.\033[39m")), "Check the target.")
})
