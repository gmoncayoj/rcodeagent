# Keep one profile choice for this process. Never merge credentials or histories.
.storage_state <- new.env(parent = emptyenv())

.storage_app_name <- function() {
  if (is.null(.storage_state$app)) {
    current <- "rcodeagent"
    previous <- paste0("RStudio", "GPT")
    kinds <- c("config", "data")
    exists_for <- function(app) any(vapply(kinds, function(kind) {
      dir.exists(tools::R_user_dir(app, kind))
    }, logical(1L)))
    .storage_state$app <- if (!exists_for(current) && exists_for(previous)) previous else current
  }
  .storage_state$app
}

.storage_dir <- function(which) tools::R_user_dir(.storage_app_name(), which)
