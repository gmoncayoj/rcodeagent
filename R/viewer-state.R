# This state belongs to one Job only. Never serialize it: it can hold an Auto grant.
.new_viewer_state <- function() {
  state <- new.env(parent = emptyenv())
  state$serial <- 0L
  state$owner <- NULL
  state$checkpoint <- NULL
  state$closed <- FALSE
  state
}

.claim_viewer_state <- function(state) {
  if (isTRUE(state$closed) || !is.null(state$owner)) return(NULL)
  state$serial <- state$serial + 1L
  state$owner <- state$serial
  restored <- state$checkpoint
  state$checkpoint <- NULL # A grant is transferred, never copied to two live pages.
  list(lease = state$owner, restored = restored)
}

.validate_viewer_target <- function(restored) {
  if (is.null(restored)) return(NULL)
  snapshot <- restored$snapshot
  valid <- FALSE
  if (.editor_has_target(snapshot) && !isTRUE(.native_ipc_state$failed) && !isTRUE(.native_ipc_state$busy)) {
    current <- tryCatch(.snapshot_editor(id = snapshot$id), error = function(e) NULL)
    valid <- .editor_has_target(current) && identical(current$id, snapshot$id) &&
      identical(current$path, snapshot$path) && identical(current$full, snapshot$full)
  }
  if (!valid && !is.null(snapshot)) {
    restored$snapshot <- NULL
    restored$auto <- FALSE
    restored$proposal <- ""
    restored$pending_snap <- NULL
    restored$pending_task <- ""
    restored$context_view <- NULL
    restored$follow_active <- FALSE
    restored$status <- "No se pudo confirmar el destino anterior. Auto desactivado: vuelve a capturar el contexto."
    restored$notice <- restored$status
  }
  if (!valid || !.editor_allows_r(restored$snapshot) || !identical(restored$mode, "auto") ||
      !isTRUE(restored$editor_access)) restored$auto <- FALSE
  restored$mode <- if (isTRUE(restored$auto)) "auto" else "normal"
  restored
}
