.original_icon <- function(name, id = NULL) {
  stopifnot(length(name) == 1L, name %in% c("new", "history", "editor", "plan", "auto", "ask"))
  shiny::tags$svg(id = id, class = "rg-original-icon", viewBox = "0 0 24 24",
    `aria-hidden` = "true", focusable = "false",
    shiny::tags$use(href = paste0("rcodeagent-assets/icons-original.svg#c-", name)))
}

.icon_button <- function(id, label, icon, class = "") {
  shiny::actionButton(id, label = .original_icon(icon),
    class = paste("rg-icon-button", class), title = label, `aria-label` = label)
}

.mode_choice <- function(icon, title, description) {
  shiny::div(.original_icon(icon), shiny::div(shiny::strong(title), shiny::p(description)),
    shiny::icon("check", class = "rg-mode-check"))
}

.work_mode_menu <- function() shiny::tags$details(class = "rg-menu rg-work-menu", id = "mode_menu",
  shiny::tags$summary(title = "Modo de trabajo", .original_icon("editor", "mode_selector_icon"),
    shiny::textOutput("mode_label", inline = TRUE), shiny::icon("chevron-down", class = "rg-chevron")),
  shiny::div(class = "rg-menu-panel", shiny::radioButtons("mode", NULL,
    choiceNames = list(
      .mode_choice("ask", "Normal", "Solo lecturas y consultas, sin modificar ni ejecutar c\u00f3digo en RStudio."),
      .mode_choice("auto", "Auto", "Modifica el c\u00f3digo en el destino elegido. Ejecuta c\u00f3digo solo si se lo pides expl\u00edcitamente.")),
    choiceValues = c("normal", "auto"), selected = "normal")))

.welcome_view <- function() {
  card <- function(icon, title, copy, color, suggestion) shiny::tags$button(type = "button",
    class = paste("rg-feature", color), `data-suggestion` = suggestion,
    shiny::icon(icon), shiny::strong(title), shiny::span(shiny::tagList(lapply(seq_along(copy), function(i) {
      shiny::tagList(if (i > 1L) shiny::tags$br(), copy[[i]])
    }))))
  suggestions <- c("Revisa este script y sugiere mejoras", "Explica este resultado", "Corrige este error",
    "Genera una funci\u00f3n para...", "Analiza todos los scripts del proyecto", "Compara estas dos versiones")
  shiny::div(class = "rg-empty",
    shiny::div(class = "rg-brand-row", shiny::div(class = "rg-brand",
      shiny::tags$img(src = "rcodeagent-assets/logo.png", alt = "rcodeagent", width = 110, height = 76)),
      shiny::h1("rcodeagent"), shiny::span(class = "rg-version", as.character(utils::packageVersion("rcodeagent")))),
    shiny::h2("Tu asistente de programaci\u00f3n, an\u00e1lisis e investigaci\u00f3n en R"),
    shiny::p(class = "rg-lead", "Analiza tus datos, lee y modifica tus scripts, genera c\u00f3digo, resuelve errores y mucho m\u00e1s, utilizando tu suscripci\u00f3n de ChatGPT."),
    shiny::div(class = "rg-features",
      card("code", "Analizar c\u00f3digo", c("Explica, revisa y", "mejora tu c\u00f3digo R."), "rg-blue", suggestions[[1L]]),
      card("pen", "Modificar scripts", c("Revisa en el chat", "o edita el destino", "con Auto."), "rg-purple", "Mejora la sintaxis de este script"),
      card("chart-simple", "Analizar datos", c("Explora los archivos", "que compartes y", "sus resultados."), "rg-cyan", "Analiza el contenido de los archivos que he compartido"),
      card("folder-open", "Trabajar con archivos", c("Lee y edita scripts", "de tu proyecto."), "rg-orange", "Compara los archivos que he compartido")),
    shiny::div(class = "rg-suggestions", lapply(suggestions, function(text) shiny::tags$button(
      type = "button", `data-suggestion` = text, text))))
}

.rcodeagent_view <- function() {
  shiny::addResourcePath("rcodeagent-assets", system.file("www", package = "rcodeagent"))
  miniUI::miniPage(
    miniUI::gadgetTitleBar("rcodeagent",
      left = shiny::div(class = "rg-toolbar",
        .icon_button("new_chat", "Nueva conversaci\u00f3n", "new"),
        .icon_button("history_open", "Historial de conversaciones", "history")),
      right = shiny::div(class = "rg-header-controls",
        shiny::tags$button(type = "button", id = "sidebar_toggle", class = "btn rg-icon-button",
          title = "Ocultar panel lateral", `aria-label` = "Ocultar panel lateral", `aria-expanded` = "true",
          `aria-controls` = "assistant_sidebar", shiny::icon("table-columns")),
        miniUI::miniTitleBarButton("done", "Cerrar", primary = FALSE))),
    miniUI::miniContentPanel(
      shiny::tags$head(shiny::tags$title("rcodeagent"), shiny::tags$script(type = "application/json", id = "rg-language-data",
          shiny::HTML(jsonlite::toJSON(list(language = .read_preferences()$language,
            dictionary = as.list(.ui_dictionary())), auto_unbox = TRUE))),
        shiny::includeCSS(system.file("www", "rcodeagent.css", package = "rcodeagent")),
        shiny::includeScript(system.file("www", "localization.js", package = "rcodeagent")),
        shiny::includeScript(system.file("www", "conversation.js", package = "rcodeagent"))),
      shiny::div(class = "rg-workspace",
        shiny::div(class = "rg-main",
          shiny::div(class = "rg-chat", role = "log", `aria-label` = "Conversaci\u00f3n", shiny::uiOutput("chat")),
          shiny::conditionalPanel("output.has_proposal === 'true'",
            shiny::div(class = "rg-proposal",
              shiny::tags$details(shiny::tags$summary("Revisar c\u00f3digo propuesto"), shiny::verbatimTextOutput("result")),
              shiny::uiOutput("execution_review"))),
          shiny::div(class = "rg-context-board",
            shiny::div(class = "rg-context-heading", shiny::icon("clipboard"), "Contexto", shiny::textOutput("target_label", inline = TRUE)),
            shiny::div(class = "rg-context-actions",
              shiny::actionButton("refresh", "Selecci\u00f3n actual", icon = shiny::icon("code"), `aria-pressed` = "true"),
              shiny::actionButton("capture_document", "Archivo activo", icon = shiny::icon("file"), `aria-pressed` = "false"),
              shiny::actionButton("project_context", "Proyecto completo", icon = shiny::icon("file-lines"),
                title = "Ver archivos a\u00f1adidos", `aria-pressed` = "false")),
            shiny::uiOutput("attachments")),
          shiny::div(class = "rg-composer",
            shiny::div(class = "rg-input-row", shiny::tags$button(type = "button", class = "rg-upload-trigger rg-attach",
              `aria-label` = "Cargar archivos de contexto", title = "Cargar .R, .md, .qmd o .Rmd", shiny::icon("paperclip")),
              shiny::textAreaInput("request", "Mensaje", placeholder = "Escribe un mensaje a rcodeagent...", rows = 1L, width = "100%")),
            shiny::div(class = "rg-compose-actions",
              shiny::div(class = "rg-composer-menus",
                shiny::tags$button(type = "button", id = "auto_toggle", class = "rg-auto-switch", `aria-pressed` = "false",
                  title = "Auto mode apagado: activar permite editar el destino elegido sin confirmaci\u00f3n", `aria-label` = "Activar Auto mode",
                  shiny::icon("shield-halved")),
                shiny::tags$button(type = "button", class = "rg-icon-button", id = "context_toggle", title = "Ver contexto compartido",
                  `aria-label` = "Ver contexto compartido", shiny::icon("globe")),
                .work_mode_menu()),
              shiny::div(class = "rg-composer-right",
                shiny::span(class = "rg-token-counter", title = "Ventana de contexto; \u2248 indica estimaci\u00f3n. Consumo real en Historial.",
                  shiny::textOutput("context_tokens", inline = TRUE)),
                shiny::tags$details(class = "rg-menu rg-model-menu", id = "model_menu",
                  shiny::tags$summary(id = "model_focus", class = "rg-model-trigger", title = "Elegir modelo y esfuerzo",
                    shiny::icon("r-project"), shiny::textOutput("model_label", inline = TRUE),
                    shiny::textOutput("effort_label", inline = TRUE), shiny::icon("chevron-down")),
                  shiny::div(class = "rg-menu-panel rg-model-panel",
                    shiny::selectInput("model", "Modelo", c("Cargando..." = ""), selectize = FALSE),
                    shiny::selectInput("effort", "Esfuerzo", c("Bajo" = "low", "Medio" = "medium", "Alto" = "high", "Muy alto" = "xhigh"),
                      selected = "medium", selectize = FALSE),
                    shiny::actionButton("check", "Actualizar modelos", icon = shiny::icon("arrows-rotate")))),
                shiny::tags$button(id = "send", type = "button", class = "rg-send", title = "Enviar (Enter)",
                  `aria-label` = "Enviar mensaje", disabled = "disabled", shiny::icon("arrow-up"))))),
          shiny::div(id = "client_feedback", class = "rg-client-feedback", role = "status", `aria-live` = "polite"),
          shiny::div(class = "rg-upload-input", shiny::fileInput("context_files", "Archivos de contexto", multiple = TRUE,
            accept = c(".R", ".md", ".qmd", ".Rmd"), buttonLabel = "Elegir", placeholder = "Sin archivos"))),
        shiny::tags$aside(class = "rg-sidebar", id = "assistant_sidebar", `aria-label` = "Configuraci\u00f3n del asistente",
          shiny::div(class = "rg-sidebar-section",
            shiny::h3("Cuenta"),
            shiny::textOutput("account_name"),
            shiny::div(class = "rg-controls", shiny::actionButton("connect", "Iniciar sesi\u00f3n con ChatGPT"),
              shiny::actionButton("connect_other", "Usar otra cuenta"), shiny::actionButton("disconnect", "Desconectar"))),
          shiny::div(class = "rg-sidebar-section", shiny::h3("Destino de edici\u00f3n"),
            shiny::textOutput("scope"), shiny::actionButton("choose_target", "Elegir script .R", icon = shiny::icon("file-code")),
            shiny::p("Solo se comparte el contexto elegido y los adjuntos. Auto edita el destino elegido; la ejecuci\u00f3n requiere una petici\u00f3n expl\u00edcita.")),
          shiny::div(class = "rg-sidebar-section", shiny::tags$details(class = "rg-export-menu",
            shiny::tags$summary(shiny::icon("file-export"), "Exportar", shiny::icon("chevron-down")),
            shiny::div(class = "rg-export-options",
              shiny::downloadButton("export_html", "HTML", class = "disabled", `aria-disabled` = "true"),
              shiny::downloadButton("export_json", "JSON", class = "disabled", `aria-disabled` = "true"),
              shiny::downloadButton("export_md", "Markdown", class = "disabled", `aria-disabled` = "true"),
              shiny::downloadButton("export_pdf", "PDF", class = "disabled", `aria-disabled` = "true")),
            shiny::p("Exporta los mensajes de la conversaci\u00f3n actual. Los archivos se guardan localmente."))),
          shiny::div(class = "rg-sidebar-section", shiny::actionButton("about", "About", icon = shiny::icon("circle-info"))),
          shiny::div(class = "rg-sidebar-section", shiny::selectInput("ui_language", "Idioma",
            c("Espa\u00f1ol" = "es", "English" = "en"), selected = .read_preferences()$language, selectize = FALSE),
            shiny::p("Esta preferencia solo cambia la interfaz. El idioma de las respuestas depende de tu instrucci\u00f3n al modelo.")),
          shiny::div(class = "rg-sidebar-section rg-status", shiny::textOutput("status"), shiny::textOutput("session_tokens")))
      )))
}
