# Parent-session launcher state. Never store credentials, prompts or Auto grants here.
.background_runtime <- new.env(parent = emptyenv())

.clear_background_runtime <- function() {
  directory <- .background_runtime$directory
  if (!is.null(directory)) {
    # Only these launcher-owned files; never recursively remove a computed path.
    unlink(file.path(directory, c("launch.R", "config.rds", "state.json")))
    unlink(directory, recursive = FALSE)
  }
  .background_runtime$job <- NULL
  .background_runtime$directory <- NULL
  invisible(NULL)
}

.background_url <- function(directory) {
  if (is.null(directory) || !file.exists(file.path(directory, "state.json"))) return(NULL)
  state <- tryCatch(jsonlite::read_json(file.path(directory, "state.json")), error = function(e) NULL)
  url <- state$url
  if (is.character(state$status) && length(state$status) == 1L &&
      state$status %in% c("running", "suspended") && is.character(url) && length(url) == 1L &&
      .viewer_url_allowed(url, require_capability = TRUE)) url else NULL
}

.launch_background <- function() {
  job <- .background_runtime$job
  if (!is.null(job)) {
    state <- tryCatch(rstudioapi::jobGetState(job), error = function(e) {
      stop("No se pudo comprobar el proceso de rcodeagent. Revisa Background Jobs antes de reabrirlo.", call. = FALSE)
    })
    if (!is.null(state) && !(is.character(state) && length(state) == 1L && !is.na(state) &&
        state %in% c("idle", "running", "succeeded", "cancelled", "failed"))) {
      stop("RStudio devolvi\u00f3 un estado de trabajo desconocido. Revisa Background Jobs.", call. = FALSE)
    }
    if (is.character(state) && length(state) == 1L && state %in% c("idle", "running")) {
      url <- .background_url(.background_runtime$directory)
      if (is.null(url)) message("rcodeagent ya se est\u00e1 iniciando. Revisa Background Jobs si no aparece.") else {
        rstudioapi::viewer(url, height = 650)
      }
      return(invisible(job))
    }
    .clear_background_runtime()
  }
  directory <- tempfile("rcodeagent-job-")
  if (!dir.create(directory, mode = "0700")) stop("No se pudo preparar el proceso de rcodeagent.")
  .background_runtime$directory <- directory
  launched <- FALSE
  on.exit(if (!launched) .clear_background_runtime(), add = TRUE)
  config <- list(libraries = .libPaths(), package_path = getNamespaceInfo(asNamespace("rcodeagent"), "path"),
    state_file = file.path(directory, "state.json"))
  config_file <- file.path(directory, "config.rds")
  saveRDS(config, config_file)
  # dput quotes paths as R literals; never interpolate them as executable source.
  script <- c("local({", paste0("  config <- readRDS(", paste(utils::capture.output(dput(config_file)), collapse = ""), ")"),
    "  .libPaths(config$libraries)",
    "  if (file.exists(file.path(config$package_path, 'R', 'addin.R'))) {",
    "    pkgload::load_all(config$package_path, quiet = TRUE)",
    "  } else loadNamespace('rcodeagent', lib.loc = dirname(config$package_path))",
    "  get('.run_background_app', envir = asNamespace('rcodeagent'))(config$state_file)", "})")
  script_file <- file.path(directory, "launch.R")
  writeLines(script, script_file, useBytes = TRUE)
  job <- rstudioapi::jobRunScript(script_file, name = "rcodeagent", encoding = "UTF-8",
    workingDir = getwd(), importEnv = FALSE, exportEnv = "")
  if (!is.character(job) || length(job) != 1L || is.na(job) || !nzchar(job)) {
    stop("RStudio no devolvi\u00f3 un identificador de Background Job v\u00e1lido.", call. = FALSE)
  }
  .background_runtime$job <- job
  launched <- TRUE
  invisible(job)
}

.run_background_app <- function(state_file) {
  if (!.rstudio_call("isAvailable", child_ok = TRUE)) stop("El proceso no tiene comunicaci\u00f3n con RStudio.", call. = FALSE)
  # The initial Shiny input message includes the private fragment. Never trace it.
  old_options <- options(shiny.trace = FALSE, shiny.testmode = FALSE)
  on.exit(options(old_options), add = TRUE)
  port <- httpuv::randomPort()
  origin <- paste0("http://127.0.0.1:", port)
  capability <- paste(sprintf("%02x", as.integer(openssl::rand_bytes(32L))), collapse = "")
  sessions <- 0L
  connected_once <- FALSE
  timers <- list()
  alive <- TRUE
  finished <- FALSE
  recovery <- .new_viewer_state()
  generation <- 0L
  app_url <- NULL
  write_state <- function(status, url = NULL) jsonlite::write_json(
    list(status = status, url = url), state_file, auto_unbox = TRUE)
  on.exit({
    alive <- FALSE
    for (cancel in timers) if (is.function(cancel)) try(cancel(), silent = TRUE)
    try(write_state(if (finished) "stopped" else "failed"), silent = TRUE)
  }, add = TRUE)
  write_state("starting")
  timers[[length(timers) + 1L]] <- later::later(function() {
    if (alive && !connected_once) shiny::stopApp()
  }, delay = 60)
  server <- function(input, output, session) {
    # Shiny receives initial clientData before invoking this public server callback.
    fragment <- shiny::isolate(session$clientData$url_hash_initial)
    if (!.viewer_client_allowed(session$request, fragment, origin, capability)) {
      session$close()
      return(invisible(NULL))
    }
    connected_once <<- TRUE
    sessions <<- sessions + 1L
    generation <<- generation + 1L
    if (!is.null(app_url)) write_state("running", app_url)
    session$onSessionEnded(function() {
      sessions <<- sessions - 1L
      generation <<- generation + 1L
      ended_generation <- generation
      # Replacing Viewer is a suspension, not an explicit Close.
      timers[[length(timers) + 1L]] <<- later::later(function() {
        if (alive && sessions == 0L && identical(generation, ended_generation)) write_state("suspended", app_url)
      }, delay = 2)
      timers[[length(timers) + 1L]] <<- later::later(function() {
        if (alive && sessions == 0L && identical(generation, ended_generation)) {
          recovery$checkpoint <- NULL
          recovery$closed <- TRUE
          shiny::stopApp()
        }
      }, delay = 1800)
    })
    .rcodeagent_server(input, output, session, viewer_state = recovery)
  }
  ui <- function(request) {
    if (!.viewer_request_allowed(request, origin)) return(shiny::httpResponse(403L, "text/plain", "Forbidden"))
    .rcodeagent_view()
  }
  app <- shiny::shinyApp(ui, server)
  shiny::runApp(app, host = "127.0.0.1", port = port, launch.browser = function(url) {
    app_url <<- paste0(origin, "/#rcodeagent=", capability)
    write_state("running", app_url)
    .rstudio_call("viewer", url = app_url, height = 650)
  })
  finished <- TRUE
  invisible(NULL)
}
