args <- commandArgs(trailingOnly = TRUE)
root <- normalizePath(".", winslash = "/")
version <- read.dcf(file.path(root, "DESCRIPTION"), fields = "Version")[[1L]]
stopifnot(grepl("^[0-9]+(\\.[0-9]+)+$", version))
library <- file.path(root, ".local", "library")
dir.create(library, recursive = TRUE, showWarnings = FALSE)
utils::install.packages(file.path(root, "dist", paste0("rcodeagent_", version, ".tar.gz")),
  repos = NULL, type = "source", lib = library)
.libPaths(c(library, .libPaths()))
library(rcodeagent)
stopifnot(as.character(utils::packageVersion("rcodeagent")) == version)
stopifnot(utils::packageDescription("rcodeagent")$License == "GPL (>= 3)")
stopifnot(file.exists(system.file("rstudio", "addins.dcf", package = "rcodeagent")))
stopifnot(file.exists(system.file("www", "conversation.js", package = "rcodeagent")))
view <- as.character(rcodeagent:::.rcodeagent_view())
stopifnot(grepl("rcodeagent", view, fixed = TRUE))
job <- rcodeagent:::.start_request("Synthetic verification", "synthetic", FALSE, "normal", "medium",
  worker_reply = function(...) list(action = "chat", message = "synthetic ok", code = ""))
on.exit(job$kill(), add = TRUE)
deadline <- Sys.time() + 20
while (job$is_alive() && Sys.time() < deadline) Sys.sleep(0.05)
stopifnot(identical(job$get_result()$message, "synthetic ok"))
cat(paste0("Installed ", version, ", registration, assets, UI and real local worker verified. No OAuth requests.\n"))
