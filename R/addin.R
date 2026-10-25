#' Open the rcodeagent assistant
#'
#' A local RStudio addin with native browser-based ChatGPT OAuth.
#' The OAuth identity and refresh tokens are never exposed to the chat UI.
#' No Codex CLI or OpenAI Platform API key is used.
#'
#' @export
rcodeagent <- function() {
  if (!rstudioapi::isAvailable()) stop("Abre este complemento desde RStudio.", call. = FALSE)
  .launch_background()
}

.rcodeagent_server <- function(input, output, session, viewer_state = session$userData$viewer_state) {
    lease <- NULL
    restored <- NULL
    if (!is.null(viewer_state)) {
      claimed <- .claim_viewer_state(viewer_state)
      if (is.null(claimed)) {
        shiny::showNotification("rcodeagent ya est\u00e1 abierto. Vuelve a la vista existente.", type = "warning", session = session)
        session$close()
        return(invisible(NULL))
      }
      lease <- claimed$lease
      restored <- .validate_viewer_target(claimed$restored)
    }
    restore_ready <- shiny::reactiveVal(is.null(restored))
    ui_language <- shiny::reactiveVal(.read_preferences()$language)
    shiny::observeEvent(input$ui_language_choice, {
      tryCatch({
        .save_preferences(input$ui_language_choice)
        ui_language(input$ui_language_choice)
        session$sendCustomMessage("rg-language", list(language = ui_language()))
      }, error = function(e) shiny::showNotification(.tr_ui(conditionMessage(e), ui_language()), type = "error"))
    }, ignoreInit = TRUE)
    session$onFlushed(function() {
      selected <- shiny::isolate(ui_language())
      shiny::updateSelectInput(session, "ui_language", selected = selected)
      session$sendCustomMessage("rg-language", list(language = selected))
    }, once = TRUE)
    snap <- shiny::reactiveVal(if (is.null(restored)) tryCatch(.snapshot_editor(), error = function(e) NULL) else restored$snapshot)
    context_view <- shiny::reactiveVal(if (is.null(restored)) "selection" else restored$context_view)
    follow_active <- shiny::reactiveVal(isTRUE(restored$follow_active))
    history <- shiny::reactiveVal(restored$history %||% list())
    response <- shiny::reactiveVal(restored$response %||% "")
    proposal <- shiny::reactiveVal(restored$proposal %||% "")
    pending_snap <- shiny::reactiveVal(restored$pending_snap)
    pending_task <- shiny::reactiveVal(restored$pending_task %||% "")
    has_edit_proposal <- shiny::reactive(identical(pending_task(), "modify") && !is.null(pending_snap()))
    reviewed_edit <- shiny::reactiveVal(NULL)
    oauth <- shiny::reactiveVal(NULL)
    status <- shiny::reactiveVal(if (is.null(restored)) rcodeagent_status() else restored$status)
    catalog <- shiny::reactiveVal(restored$catalog %||% character())
    is_connected <- shiny::reactiveVal(isTRUE(restored$connected))
    request_error <- shiny::reactiveVal(NULL)
    pending_execution <- shiny::reactiveVal(NULL)
    execution_status <- shiny::reactiveVal("")
    seen_request_ids <- if (is.null(viewer_state)) character() else viewer_state$seen_request_ids %||% character()
    auto_mode <- shiny::reactiveVal(isTRUE(restored$auto))
    auto_generation <- shiny::reactiveVal(0L)
    mode <- shiny::reactive(if (!restore_ready()) restored$mode else {
      if (auto_mode()) "auto" else "normal"
    })
    files <- shiny::reactiveVal(restored$files %||% list())
    conversation <- shiny::reactiveVal(if (is.null(restored)) .new_conversation() else restored$conversation)
    active_job <- shiny::reactiveVal(NULL)
    token_usage <- shiny::reactiveVal(restored$usage %||% list(total_tokens = 0, last = NULL))
    account_name <- shiny::reactiveVal(restored$account_name %||% "")
    initial_status <- shiny::isolate(status())
    if (startsWith(initial_status, "Sesi\u00f3n OAuth local: ")) account_name(sub(" \u00b7.*$", "", sub("^Sesi\u00f3n OAuth local: ", "", initial_status)))

    notify_error <- function(e) {
      if (inherits(e, c("rcodeagent_ipc_error", "rcodeagent_editor_conflict"))) revoke_auto()
      if (isTRUE(e$edit_applied)) status(conditionMessage(e))
      shiny::showNotification(.tr_ui(.request_error_message(e), ui_language()), type = "error", duration = NULL)
    }
    clear_proposal <- function() {
      proposal(""); pending_snap(NULL); pending_task(""); reviewed_edit(NULL); pending_execution(NULL)
    }
    persist <- function() {
      chat <- conversation()
      chat$messages <- history()
      chat$attachments <- files()
      chat$model <- input$model %||% ""
      chat$effort <- input$effort %||% "medium"
      chat$usage <- token_usage()
      chat$updated <- format(Sys.time(), "%Y-%m-%d %H:%M:%S")
      if (length(chat$messages)) chat$title <- substr(chat$messages[[1L]]$text, 1L, 80L)
      .save_conversation(chat)
      conversation(chat)
    }
    stop_current <- function() {
      current <- active_job()
      active_job(NULL) # Invalidate first: late results cannot write or change the new chat.
      if (!is.null(current)) {
        .cancel_request(current$process)
        session$sendCustomMessage("rg-request-complete", list(success = FALSE, cancelled = TRUE,
          text = current$instruction, id = current$id))
        status("Consulta cancelada. No se aplicaron cambios.")
      }
      clear_proposal()
    }
    prepare_execution <- function(code, snapshot, request_id, instruction, record_user = TRUE) {
      .execution_text(code)
      if (!auto_mode() || !.editor_allows_r(snapshot)) stop("Elige un destino de c\u00f3digo R y activa Auto antes de ejecutar.")
      pending_execution(list(code = code, snapshot = snapshot, request_id = request_id, instruction = instruction, record_user = record_user,
        auto_generation = auto_generation(), nonce = paste(as.character(openssl::rand_bytes(16L)), collapse = "")))
      execution_status("Env\u00edo a la consola en curso.")
    }
    perform_execution <- function(write_library = FALSE, confirmed = FALSE) {
      candidate <- pending_execution()
      if (is.null(candidate) || !restore_ready() || session$isClosed()) return(invisible(FALSE))
      if (!auto_mode() || mode() != "auto" || !isTRUE(input$editor_access %||% TRUE) ||
          !identical(candidate$auto_generation, auto_generation()) ||
          !identical(candidate$snapshot, snap())) stop("El destino de Auto cambi\u00f3.")
      if (!.console_execution_ready()) {
        execution_status("Ejecuci\u00f3n pendiente de validaci\u00f3n nativa de RStudio. No se enviar\u00e1 c\u00f3digo a la consola.")
        status(execution_status())
        session$sendCustomMessage("rg-request-complete", list(success = FALSE, text = candidate$instruction, id = candidate$request_id))
        return(invisible(FALSE))
      }
      if (.execution_requires_review(candidate$code) && !confirmed) {
        execution_status("Revisa el c\u00f3digo y confirma esta ejecuci\u00f3n administrativa.")
        status(execution_status())
        session$sendCustomMessage("rg-request-complete", list(success = TRUE, text = candidate$instruction, id = candidate$request_id))
        return(invisible(FALSE))
      }
      pending_execution(NULL) # Never replay a click or an uncertain native operation.
      s <- candidate$snapshot
      .console_input_empty() # Refuse pending input before any optional library edit.
      .validate_execution_target(s)
      if (isTRUE(write_library)) {
        call <- parse(text = candidate$code, keep.source = FALSE)[[1L]]
        present <- .has_library_call(s$text, as.character(call[[2L]]))
        if (!present) {
          replacement <- paste(c(if (nzchar(s$text)) s$text, candidate$code), collapse = "\n")
          parse(text = replacement)
          s <- .apply_verified_editor(s, replacement)
          snap(s)
        }
      }
      .validate_execution_target(s)
      grant <- .new_execution_grant(candidate$request_id, lease, s, candidate$code)
      if (!auto_mode() || !.consume_execution_grant(grant, candidate$request_id, lease, snap(), candidate$code)) {
        stop("La autorizaci\u00f3n de ejecuci\u00f3n caduc\u00f3.")
      }
      execution_status("Env\u00edo a la consola en curso.")
      tryCatch(.submit_console_execution(candidate$code, s), error = function(e) {
        revoke_auto()
        execution_status("Env\u00edo no confirmado; revisa la consola. No se repetir\u00e1 autom\u00e1ticamente.")
        status(execution_status())
        stop(e)
      })
      execution_status("Enviado a la consola; RStudio puede dejarlo en cola. Revisa all\u00ed el resultado. Stop del chat no retira c\u00f3digo enviado.")
      status(execution_status())
      history(c(history(), if (isTRUE(candidate$record_user)) list(list(role = "Usuario", text = candidate$instruction, code = "")),
        list(list(role = "Asistente", text = .tr_ui(execution_status(), ui_language()), code = candidate$code))))
      tryCatch(persist(), error = notify_error)
      session$sendCustomMessage("rg-request-complete", list(success = TRUE, text = candidate$instruction, id = candidate$request_id))
      invisible(TRUE)
    }
    shiny::observeEvent(input$confirm_execution, {
      candidate <- pending_execution()
      if (is.null(candidate) || !.execution_requires_review(candidate$code) ||
          !identical(input$confirm_execution, candidate$nonce)) return()
      tryCatch(perform_execution(confirmed = TRUE), error = notify_error)
    })
    finish_job <- function() {
      if (session$isClosed() || !restore_ready()) return()
      current <- active_job()
      if (is.null(current) || current$process$is_alive()) return()
      active_job(NULL)
      success <- FALSE
      tryCatch({
        if (!identical(current$conversation_id, conversation()$id)) stop("La conversaci\u00f3n cambi\u00f3.")
        answer <- current$process$get_result()
        usage <- .normalize_usage(answer$usage)
        if (answer$action != "chat" && (!current$auto || !auto_mode() || mode() != "auto")) {
          stop("El modo Normal no autoriza modificar ni ejecutar c\u00f3digo en RStudio. Activa Auto o copia y ejecuta el c\u00f3digo manualmente.")
        }
        if (answer$action != "chat" && !identical(current$auto_generation, auto_generation())) {
          stop("La autorizaci\u00f3n de Auto cambi\u00f3 durante la consulta. Repite la solicitud con el permiso actual.")
        }
        explicit_execution <- isTRUE(current$execution_intent$authorized) || isTRUE(current$execution_intent$direct)
        if (identical(answer$action, "execute") && !explicit_execution) {
          stop("No hay una petici\u00f3n expl\u00edcita de ejecuci\u00f3n en este mensaje. No se envi\u00f3 c\u00f3digo a la consola.")
        }
        if (identical(answer$action, "modify") && (!.editor_has_target(current$snapshot) || !isTRUE(input$editor_access %||% TRUE))) {
          stop("No hay un destino de edici\u00f3n autorizado.")
        }
        execute_answer <- explicit_execution && nzchar(answer$code) &&
          answer$action %in% c("execute", "modify", "generate")
        applied <- FALSE
        if (identical(answer$action, "modify") && current$auto && auto_mode() && mode() == "auto") {
          if (!.editor_allows_r(current$snapshot) || !identical(current$snapshot, snap())) stop("El destino de Auto cambi\u00f3.")
          parse(text = answer$code)
          snap(.apply_verified_editor(current$snapshot, answer$code))
          applied <- TRUE
        }
        if (!applied && !execute_answer) {
          if (identical(answer$action, "modify")) pending_snap(current$snapshot)
          pending_task(answer$action)
          proposal(answer$code)
        }
        if (execute_answer && (!auto_mode() || (!applied && !identical(current$snapshot, snap())))) {
          stop("El destino de Auto cambi\u00f3.")
        }
        response(answer$message)
        history(c(history(), list(list(role = "Usuario", text = current$instruction, code = ""),
          list(role = "Asistente", text = answer$message, code = answer$code, edit_applied = applied))))
        if (!is.null(usage)) {
          token_usage(list(total_tokens = token_usage()$total_tokens + usage$total_tokens, last = usage, last_model = current$model))
        }
        status(if (applied) "Auto: cambios aplicados en el editor; guarda el archivo." else "Respuesta recibida. Revisa las propuestas antes de aplicarlas.")
        tryCatch(persist(), error = notify_error)
        if (execute_answer) {
          prepare_execution(answer$code, snap(), current$id, current$instruction, record_user = FALSE)
          perform_execution()
        }
        success <- TRUE
      }, error = function(e) {
        status(if (isTRUE(e$edit_applied)) conditionMessage(e) else "La solicitud no pudo completarse.")
        notify_error(e)
      }, finally = {
        session$sendCustomMessage("rg-request-complete", list(success = success, text = current$instruction, id = current$id))
      })
    }
    shiny::observe({
      shiny::invalidateLater(100, session)
      if (!is.null(active_job())) finish_job()
    })

    refresh_models <- function() {
      models <- .models_for_account()
      catalog(models)
      is_connected(TRUE)
      selected <- shiny::isolate(input$model %||% "")
      if (!(selected %in% unname(models))) selected <- unname(models[[1L]])
      shiny::updateSelectInput(session, "model", choices = models,
                               selected = selected)
      invisible(models)
    }

    load_models <- function(notify = TRUE) {
      tryCatch({
        refresh_models()
        status("Conectado \u00b7 Elige un modelo y env\u00eda tu consulta.")
      }, error = function(e) {
        is_connected(FALSE)
        catalog(character())
        shiny::updateSelectInput(session, "model", choices = c("Modelos no disponibles" = ""))
        status(paste0(rcodeagent_status(), " \u00b7 Modelos no cargados. Usa Iniciar sesi\u00f3n o Actualizar modelos."))
        if (notify) shiny::showNotification(.connection_error_message(e, ui_language()), type = "error", duration = NULL)
      })
    }
    session$onFlushed(function() shiny::isolate({
      if (is.null(restored)) load_models(notify = FALSE) else {
        shiny::updateSelectInput(session, "model", choices = catalog(), selected = restored$model)
        shiny::updateSelectInput(session, "effort", selected = restored$effort)
        shiny::updateRadioButtons(session, "mode", selected = if (auto_mode()) "auto" else restored$mode)
        session$sendCustomMessage("rg-viewer-restore", list(lease = as.character(lease), draft = restored$draft,
          editor_access = restored$editor_access, file_access = restored$file_access))
        if (!is.null(restored$notice)) shiny::showNotification(.tr_ui(restored$notice, ui_language()), type = "warning")
      }
    }), once = TRUE)
    shiny::observeEvent(input$viewer_restored, {
      if (!is.null(restored) && identical(input$viewer_restored, as.character(lease))) restore_ready(TRUE)
    }, ignoreInit = FALSE)

    output$status <- shiny::renderText(status())
    output$connection_label <- shiny::renderText(if (is_connected()) "Conectado" else "Iniciar sesi\u00f3n con ChatGPT")
    shiny::outputOptions(output, "connection_label", suspendWhenHidden = FALSE)
    output$mode_label <- shiny::renderText(if (auto_mode()) "Auto" else "Normal")
    output$account_name <- shiny::renderText(if (is_connected()) account_name() else "")
    shiny::outputOptions(output, "account_name", suspendWhenHidden = FALSE)
    output$model_label <- shiny::renderText({
      choice <- input$model %||% ""
      label <- names(catalog())[match(choice, unname(catalog()))]
      if (length(label) && !is.na(label)) label else "Modelo"
    })
    output$effort_label <- shiny::renderText(switch(input$effort %||% "medium",
      low = "Bajo", medium = "Medio", high = "Alto", xhigh = "Muy alto", "Medio"))
    output$target_label <- shiny::renderText({
      s <- snap()
      if (!.editor_has_target(s)) "Destino: elige un script para editar" else paste0("Destino: ", .editor_label(s, ui_language()), if (auto_mode()) " \u00b7 Auto ON" else "")
    })
    output$attachments <- shiny::renderUI(lapply(seq_along(files()), function(i) shiny::span(class = "rg-file-chip",
      shiny::icon("file-code"), files()[[i]]$name,
      shiny::tags$button(type = "button", `data-remove-file` = i, `aria-label` = paste("Quitar", files()[[i]]$name), shiny::icon("xmark")))))
    output$context_tokens <- shiny::renderText({
      last <- token_usage()$last
      draft <- input$request %||% ""
      estimated <- nzchar(draft) || is.null(last) || !is.null(active_job()) ||
        !identical(token_usage()$last_model, input$model)
      context <- snap() %||% list(path = "", text = "", scope = "sin documento")
      prompt <- tryCatch(.construct_prompt("auto", if (nzchar(draft)) draft else "Nueva consulta", context, history(), mode()),
        error = function(e) paste(context$text, draft))
      if (isTRUE(input$file_access %||% TRUE)) prompt <- paste0(prompt, .attachment_prompt(files()))
      if (mode() == "auto") prompt <- paste(prompt, jsonlite::toJSON(.assistant_tools(.editor_has_target(snap())), auto_unbox = TRUE))
      used <- if (estimated) .estimate_tokens(prompt) else {
        (last$input_tokens %||% 0) + (last$output_tokens %||% 0)
      }
      .token_label(used, .model_context_limit(input$model %||% "", catalog()), estimated)
    })
    output$session_tokens <- shiny::renderText(paste("Consumo de sesi\u00f3n:", format(token_usage()$total_tokens, big.mark = ",", scientific = FALSE)))
    shiny::observe(session$sendCustomMessage("rg-session-state", list(auto = auto_mode(),
      mode = if (auto_mode()) "auto" else mode(), context_view = context_view(),
      connected = is_connected(), export_ready = length(history()) > 0L)))
    output$has_response <- shiny::renderText(tolower(as.character(nzchar(response()))))
    output$has_proposal <- shiny::renderText(tolower(as.character(has_edit_proposal() || nzchar(proposal()) || !is.null(pending_execution()))))
    output$can_edit <- shiny::renderText("false")
    output$can_generate <- shiny::renderText("false")
    output$execution_review <- shiny::renderUI({
      candidate <- pending_execution()
      if (is.null(candidate) || !auto_mode() || !.execution_requires_review(candidate$code)) return(NULL)
      shiny::div(class = "rg-execution-review",
        shiny::p(.tr_ui("Revisa el c\u00f3digo antes de autorizar esta ejecuci\u00f3n en la sesi\u00f3n principal de RStudio.", ui_language())),
        shiny::tags$pre(candidate$code),
        shiny::p(.tr_ui("Los resultados aparecer\u00e1n en los paneles de RStudio. Ejecutar puede modificar objetos y archivos con los permisos de tu sesi\u00f3n R.", ui_language())),
        shiny::tags$button(type = "button", class = "btn btn-default", `data-execute-id` = candidate$nonce,
          .tr_ui("Ejecutar este c\u00f3digo", ui_language())))
    })
    for (name in c("has_response", "has_proposal", "can_edit", "can_generate")) {
      shiny::outputOptions(output, name, suspendWhenHidden = FALSE)
    }
    output$scope <- shiny::renderText({
      s <- snap()
      if (is.null(s)) return("Abre un script de R y pulsa 'Actualizar selecci\u00f3n'.")
      paste0("Contexto: ", s$scope, " \u00b7 ", nchar(s$text), " caracteres",
             paste0(" \u00b7 ", .editor_label(s, ui_language())))
    })
    output$result <- shiny::renderText({
      proposal()
    })
    output$chat <- shiny::renderUI({
      items <- history()
      if (!length(items)) return(.welcome_view())
      shiny::tagList(lapply(items, function(item) {
        shiny::div(class = paste("rg-msg", if (identical(item$role, "Usuario")) "rg-user" else "rg-ai"),
                   shiny::div(class = "rg-role", item$role),
                   if (identical(item$role, "Usuario")) shiny::div(class = "rg-text", item$text) else {
                     shiny::div(class = "rg-markdown", .render_markdown(item$text))
                   },
                   if (nzchar(item$code %||% "")) shiny::tags$pre(item$code),
                   if (isTRUE(item$edit_applied)) shiny::div(class = "rg-app-note",
                     "Auto: cambio aplicado al destino elegido. Guarda el archivo para conservarlo."))
      }))
    })

    for (format in c("html", "json", "md", "pdf")) local({
      extension <- format
      output[[paste0("export_", extension)]] <- shiny::downloadHandler(
        filename = function() paste0("rcodeagent-", format(Sys.Date(), "%Y%m%d"), ".", extension),
        contentType = c(html = "text/html; charset=utf-8", json = "application/json", md = "text/markdown; charset=utf-8", pdf = "application/pdf")[[extension]],
        content = function(path) {
          chat <- conversation()
          chat$messages <- history()
          chat$attachments <- files()
          chat$model <- input$model %||% ""
          chat$effort <- input$effort %||% "medium"
          chat$usage <- token_usage()
          if (!length(chat$messages)) {
            shiny::showNotification(.tr_ui("No hay mensajes para exportar todav\u00eda.", ui_language()), type = "warning")
            stop(.tr_ui("No hay mensajes para exportar todav\u00eda.", ui_language()))
          }
          .export_conversation(chat, path, extension, ui_language())
        })
    })
    shiny::observeEvent(input$about, {
      shiny::showModal(shiny::modalDialog(title = "Acerca de rcodeagent",
        shiny::p("Un espacio de colaboraci\u00f3n entre el usuario y la inteligencia artificial, dise\u00f1ado para facilitar el trabajo en R y mantener las decisiones en manos de quien investiga."),
        shiny::p(shiny::strong("Autor"), ": Jos\u00e9 Gamarra-Moncayo"),
        shiny::p(shiny::strong("Versi\u00f3n"), paste0(": ", getNamespaceVersion("rcodeagent"))),
        shiny::p(.tr_ui("Normal trabaja solo en el chat. Auto edita el destino y ejecuta \u00fanicamente por petici\u00f3n expl\u00edcita.", ui_language())),
        footer = shiny::modalButton("Cerrar"), easyClose = TRUE))
    })

    shiny::observeEvent(input$mode, {
      if (!restore_ready()) return()
      if (identical(input$mode, "auto")) set_auto(TRUE) else revoke_auto()
      clear_proposal()
    }, ignoreInit = TRUE)

    set_auto <- function(requested) {
      if (!is.logical(requested) || length(requested) != 1L || is.na(requested)) return()
      activated <- requested && !auto_mode()
      if (requested && (!.editor_allows_r(snap()) || !isTRUE(input$editor_access %||% TRUE))) {
        revoke_auto()
        shiny::updateRadioButtons(session, "mode", selected = "normal")
        shiny::showNotification("Elige un destino de c\u00f3digo R (script .R o documento sin guardar) antes de activar Auto.", type = "warning")
      } else {
        if (requested) {
          if (!auto_mode()) auto_generation(auto_generation() + 1L)
          auto_mode(TRUE)
        } else revoke_auto()
        status(if (requested) "Auto activado: edita el destino elegido; ejecutar requiere una petici\u00f3n expl\u00edcita." else "Normal: c\u00f3digo y consultas solo en el chat.")
        if (activated) shiny::showNotification(.tr_ui("RStudio puede dejar el c\u00f3digo en cola. Stop del chat no retira c\u00f3digo enviado; usa el control de la consola.", ui_language()),
          id = "rcodeagent-auto-notice", type = "message", duration = 5)
        pending_execution(NULL)
      }
    }
    shiny::observeEvent(input$auto_requested, {
      set_auto(input$auto_requested)
      shiny::updateRadioButtons(session, "mode", selected = if (auto_mode()) "auto" else "normal")
    })
    shiny::observeEvent(input$editor_access, {
      if (!isTRUE(input$editor_access)) {
        revoke_auto(); clear_proposal()
        if (identical(input$mode, "auto")) shiny::updateRadioButtons(session, "mode", selected = "normal")
      }
    }, ignoreInit = TRUE)
    revoke_auto <- function() {
      auto_mode(FALSE)
      auto_generation(auto_generation() + 1L)
      pending_execution(NULL)
      if (identical(input$mode, "auto")) shiny::updateRadioButtons(session, "mode", selected = "normal")
    }
    accept_snapshot <- function(s, explicit_capture = FALSE) {
      changed <- !identical(s, snap())
      was_auto <- auto_mode()
      preserve <- changed && was_auto && explicit_capture && .editor_allows_r(s) && isTRUE(input$editor_access %||% TRUE)
      if (changed) {
        if (preserve) { auto_generation(auto_generation() + 1L); pending_execution(NULL) } else revoke_auto()
      }
      snap(s)
      token_usage(list(total_tokens = token_usage()$total_tokens, last = NULL))
      if (changed && was_auto && !preserve) {
        message <- "El destino o el alcance cambi\u00f3. Auto desactivado: vuelve a activarlo para autorizar este contexto."
        status(message)
        shiny::showNotification(.tr_ui(message, ui_language()), type = "message", duration = 7)
      }
      invisible(changed && was_auto && !preserve)
    }
    capture <- function(document = FALSE, choose = FALSE) {
      stop_current()
      tryCatch({
        s <- if (choose) .select_editor_target() else .snapshot_editor()
        if (is.null(s)) return()
        if (document) { s$text <- s$full; s["range"] <- list(NULL); s$scope <- "documento" }
        revoked <- accept_snapshot(s, explicit_capture = TRUE)
        follow_active(document && !choose)
        context_view(if (document || choose) "document" else "selection")
        if (!revoked) {
          status(if (auto_mode()) "Contexto capturado. Auto sigue activado para el destino elegido." else {
            "Destino capturado. Auto permanece apagado hasta que lo actives."
          })
        }
      }, error = function(e) { revoke_auto(); snap(NULL); notify_error(e) })
    }
    shiny::observeEvent(input$capture_document, capture(document = TRUE))
    shiny::observeEvent(input$choose_target, capture(document = TRUE, choose = TRUE))
    shiny::observeEvent(input$project_context, {
      context_view("project") # Display attached context; never change the editing target or permissions.
    })
    shiny::observeEvent(input$context_files, {
      tryCatch({
        uploaded <- input$context_files
        additions <- lapply(seq_len(nrow(uploaded)), function(i) .read_context_file(uploaded$name[[i]], uploaded$datapath[[i]]))
        previous <- Filter(function(x) !(x$name %in% uploaded$name), files())
        combined <- c(previous, additions)
        if (length(combined) > 12L) stop("Se admiten hasta 12 archivos de contexto.")
        .attachment_prompt(combined)
        files(combined)
        token_usage(list(total_tokens = token_usage()$total_tokens, last = NULL))
        tryCatch(persist(), error = notify_error)
      }, error = notify_error)
    })
    shiny::observeEvent(input$remove_context_file, {
      index <- input$remove_context_file
      if (is.numeric(index) && length(index) == 1L && !is.na(index) && index == as.integer(index) && index > 0 && index <= length(files())) {
        files(files()[-index])
        token_usage(list(total_tokens = token_usage()$total_tokens, last = NULL))
        tryCatch(persist(), error = notify_error)
      }
    })
    new_chat <- function() {
      stop_current()
      revoke_auto()
      conversation(.new_conversation())
      shiny::updateRadioButtons(session, "mode", selected = "normal")
      history(list()); files(list()); response("")
      context_view("selection")
      follow_active(FALSE)
      token_usage(list(total_tokens = 0, last = NULL))
      session$sendCustomMessage("rg-conversation-reset", list())
      status("Nueva conversaci\u00f3n. Auto apagado.")
    }
    show_history <- function() {
      tryCatch({
        chats <- .list_conversations()
        body <- if (!length(chats)) shiny::p("Todav\u00eda no hay conversaciones guardadas.") else shiny::tagList(lapply(chats, function(chat) {
          shiny::div(class = "rg-history-row",
            shiny::tags$button(type = "button", class = "btn rg-history-item", `data-chat-id` = chat$id,
              chat$title, shiny::tags$small(chat$updated)),
            shiny::tags$button(type = "button", class = "btn", `data-delete-chat` = chat$id,
              title = "Eliminar conversaci\u00f3n local", `aria-label` = paste("Eliminar", chat$title), shiny::icon("trash")))
        }))
        shiny::showModal(shiny::modalDialog(title = "Historial de conversaciones", body,
          shiny::p("Guardado localmente, incluidos los archivos que has compartido. Auto siempre se retoma apagado."),
          footer = shiny::modalButton("Cerrar"), easyClose = TRUE))
      }, error = notify_error)
    }
    shiny::observeEvent(input$new_chat, new_chat())
    shiny::observeEvent(input$history_open, show_history())
    shiny::observeEvent(input$open_conversation, {
      tryCatch({
        restored <- .load_conversation(input$open_conversation)
        stop_current(); revoke_auto(); snap(NULL); context_view(NULL); follow_active(FALSE)
        shiny::updateRadioButtons(session, "mode", selected = "normal")
        conversation(restored); history(restored$messages); files(restored$attachments)
        token_usage(restored$usage %||% list(total_tokens = 0, last = NULL))
        shiny::updateSelectInput(session, "effort", selected = restored$effort)
        if (restored$model %in% unname(catalog())) shiny::updateSelectInput(session, "model", selected = restored$model)
        session$sendCustomMessage("rg-conversation-reset", list())
        shiny::removeModal()
        status("Conversaci\u00f3n retomada. Elige de nuevo el destino si deseas editar; Auto apagado.")
      }, error = notify_error)
    })
    shiny::observeEvent(input$delete_conversation, {
      tryCatch({
        .delete_conversation(input$delete_conversation)
        if (identical(input$delete_conversation, conversation()$id)) new_chat()
        show_history()
      }, error = notify_error)
    })
    shiny::observeEvent(input$disconnect, {
      stop_current(); revoke_auto()
      shiny::updateRadioButtons(session, "mode", selected = "normal")
      .oauth_stop(oauth()); oauth(NULL)
      tryCatch({
        disconnected <- .oauth_disconnect()
        is_connected(FALSE); catalog(character()); account_name("")
        shiny::updateSelectInput(session, "model", choices = c("Inicia sesi\u00f3n" = ""))
        status(if (isTRUE(disconnected$remote_revoked)) "Cuenta desconectada y sesi\u00f3n OAuth revocada." else
          "Cuenta desconectada localmente. No se confirm\u00f3 la revocaci\u00f3n remota; revisa la configuraci\u00f3n de ChatGPT.")
      }, error = notify_error)
    })

    start_login <- function(new_account = FALSE) {
      if (is_connected()) return()
      current <- oauth()
      if (!is.null(current)) .oauth_stop(current)
      oauth(NULL)
      tryCatch({
        pending <- if (new_account) .oauth_start(new_account = TRUE) else .oauth_start()
        oauth(pending)
        status("Navegador abierto. Autoriza rcodeagent con tu cuenta de ChatGPT.")
      }, error = function(e) shiny::showNotification(.connection_error_message(e, ui_language()), type = "error", duration = NULL))
    }
    shiny::observeEvent(input$connect, start_login())
    shiny::observeEvent(input$connect_other, start_login(new_account = TRUE))

    shiny::observe({
      shiny::invalidateLater(450, session)
      attempt <- oauth()
      if (is.null(attempt)) return()
      if (is.null(attempt$callback)) {
        if (as.numeric(difftime(Sys.time(), attempt$created_at, units = "secs")) > 600) {
          .oauth_stop(attempt)
          oauth(NULL)
          status("La autorizaci\u00f3n caduc\u00f3. Pulsa Conectar de nuevo.")
        }
        return()
      }
      .oauth_stop(attempt)
      oauth(NULL)
      tryCatch({
        cred <- .oauth_finish(attempt)
        account_name(cred$email %||% "")
        is_connected(TRUE)
        status(paste0("Conectado: ", cred$email, ". Cargando modelos..."))
        load_models()
      }, error = function(e) {
        status("No fue posible completar la conexi\u00f3n OAuth.")
        shiny::showNotification(.tr_ui(.connection_error_message(e, ui_language()), ui_language()), type = "error",
          duration = if (inherits(e, "rcodeagent_auth_cancelled")) 5 else NULL)
      })
    })

    shiny::observeEvent(input$check, {
      load_models()
    })
    shiny::observeEvent(input$refresh, {
      capture()
    })
    shiny::observeEvent(input$submit_request, {
      submission <- input$submit_request
      instruction <- if (is.list(submission)) submission$text else NULL
      if (!is.character(instruction) || length(instruction) != 1L || is.na(instruction) ||
          !nzchar(trimws(instruction)) || nchar(instruction) > 16000L) {
        session$sendCustomMessage("rg-request-complete", list(success = FALSE,
          text = if (is.character(instruction) && length(instruction) == 1L && !is.na(instruction)) instruction else ""))
        return()
      }
      request_id <- submission$id %||% ""
      if (!is.character(request_id) || length(request_id) != 1L || is.na(request_id) || nchar(request_id) > 80L) {
        session$sendCustomMessage("rg-request-complete", list(success = FALSE, text = instruction))
        return()
      }
      if (!restore_ready() || session$isClosed()) {
        session$sendCustomMessage("rg-request-complete", list(success = FALSE, text = instruction, id = request_id))
        return()
      }
      if (!is.null(active_job())) return()
      if (nzchar(request_id)) {
        if (request_id %in% seen_request_ids) {
          session$sendCustomMessage("rg-request-complete", list(success = FALSE, text = instruction, id = request_id))
          return()
        }
        seen_request_ids <<- utils::tail(c(seen_request_ids, request_id), 1000L)
        if (!is.null(viewer_state)) viewer_state$seen_request_ids <- seen_request_ids
      }
      response("")
      clear_proposal()
      tryCatch({
        if (!length(catalog())) refresh_models()
        model <- .validate_model(input$model %||% "")
        if (!nzchar(model)) model <- unname(catalog()[[1L]])
        if (!(model %in% unname(catalog()))) stop("Selecciona un modelo de tu cuenta.")
        if (follow_active()) {
          fresh <- tryCatch(.snapshot_editor(), error = function(e) {
            revoke_auto(); snap(NULL); stop(e)
          })
          fresh$text <- fresh$full
          fresh["range"] <- list(NULL)
          fresh$scope <- "documento"
          accept_snapshot(fresh)
        }
        s <- snap()
        intent <- .execution_intent(instruction, s)
        if (auto_mode() && isTRUE(intent$direct)) {
          code <- .execution_code(intent, s)
          prepare_execution(code, s, request_id, instruction)
          perform_execution(write_library = isTRUE(intent$write))
          return()
        }
        context <- s %||% list(path = "", text = "", scope = "sin documento")
        prompt <- .construct_prompt("auto", instruction, context, history(), mode = mode())
        if (isTRUE(input$file_access %||% TRUE)) prompt <- paste0(prompt, .attachment_prompt(files()))
        prompt <- paste0(prompt, "\nEl \u00fanico destino de edici\u00f3n es el contexto enviado. Los archivos adjuntos son solo lectura.")
        maximum <- .model_context_limit(model, catalog())
        if (length(maximum) == 1L && !is.na(maximum) && .estimate_tokens(prompt) > maximum - 8000) {
          stop("El contexto est\u00e1 cerca del m\u00e1ximo del modelo. Inicia una conversaci\u00f3n nueva o quita archivos.")
        }
        process <- .start_request(prompt, model, auto_mode() && .editor_has_target(s) && isTRUE(input$editor_access %||% TRUE),
          mode(), .validate_effort(input$effort %||% "medium"))
        active_job(list(process = process, instruction = instruction, snapshot = s, model = model,
          auto = auto_mode(), auto_generation = auto_generation(), conversation_id = conversation()$id, id = request_id, execution_intent = intent))
        status("Consultando al asistente...")
        finish_job()
      }, error = function(e) {
        notify_error(e)
        session$sendCustomMessage("rg-request-complete", list(success = FALSE, text = instruction, id = request_id))
      })
    })
    shiny::observeEvent(input$cancel_request, {
      current <- active_job()
      if (is.null(current)) return()
      if (nzchar(current$id) && !identical(input$cancel_request, current$id)) return()
      stop_current()
    })
    session$onSessionEnded(function() {
      current <- shiny::isolate(active_job())
      shiny::isolate(active_job(NULL)) # Invalidate before killing: never replay a detached request.
      if (!is.null(current)) .cancel_request(current$process)
      attempt <- shiny::isolate(oauth())
      .oauth_stop(attempt)
      if (!is.null(viewer_state) && !isTRUE(viewer_state$closed) && identical(viewer_state$owner, lease)) {
        viewer_state$checkpoint <- shiny::isolate({
          draft <- if (restore_ready()) input$request %||% "" else restored$draft
          if (!nzchar(draft) && !is.null(current)) draft <- current$instruction
          list(snapshot = snap(), history = history(), response = response(), proposal = proposal(),
            pending_snap = pending_snap(), pending_task = pending_task(), context_view = context_view(),
            follow_active = follow_active(), auto = auto_mode(), mode = mode(), files = files(),
            conversation = conversation(), usage = token_usage(), catalog = catalog(), connected = is_connected(),
            account_name = account_name(), status = if (is.null(current)) status() else "Consulta cancelada. Tu mensaje se conserva.",
            model = if (restore_ready()) input$model %||% "" else restored$model,
            effort = if (restore_ready()) input$effort %||% "medium" else restored$effort,
            draft = draft, editor_access = if (restore_ready()) isTRUE(input$editor_access %||% TRUE) else restored$editor_access,
            file_access = if (restore_ready()) isTRUE(input$file_access %||% TRUE) else restored$file_access)
        })
        viewer_state$owner <- NULL
      }
    })
    shiny::observeEvent(input$done, {
      if (!is.null(viewer_state)) { viewer_state$closed <- TRUE; viewer_state$checkpoint <- NULL; viewer_state$owner <- NULL }
      stop_current()
      .oauth_stop(oauth())
      shiny::stopApp()
    })
}

