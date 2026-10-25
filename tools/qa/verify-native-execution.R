# Opt-in RStudio probe. Source this file in the main RStudio console.
# Uses only fixed synthetic code and the public rstudioapi, not model/OAuth data.
rcodeagent_native_execution_probe <- function(phase = c("idle", "busy", "incomplete", "readline")) {
  phase <- match.arg(phase)
  if (!rstudioapi::isAvailable() || rstudioapi::isBackgroundJob()) {
    stop("Ejecuta esta prueba desde la consola principal de RStudio.")
  }
  code <- sprintf("rcodeagent_qa_execution <- %s", deparse(phase))
  script <- tempfile("rcodeagent-native-execution-", fileext = ".R")
  lines <- c("Sys.sleep(5)",
    sprintf("rstudioapi::sendToConsole(%s, execute = TRUE, echo = TRUE, focus = FALSE, animate = FALSE)", deparse(code)),
    "cat('Solicitud de envío aceptada por la API; esto no confirma el resultado del cálculo.\\n')")
  # The temporary script contains only the phase and a fixed synthetic assignment.
  writeLines(lines, script, useBytes = TRUE)
  job <- rstudioapi::jobRunScript(script, name = paste("rcodeagent execution probe", phase),
    importEnv = FALSE, exportEnv = "")
  cat("Prueba:", phase, "— el Job intentará enviar una asignación sintética dentro de 5 segundos.\n")
  cat(switch(phase,
    idle = "Mantén la consola libre. Después de 8 segundos consulta rcodeagent_qa_execution.\n",
    busy = "Ahora ejecuta Sys.sleep(12). Observa si la asignación queda en cola hasta terminar.\n",
    incomplete = "Ahora escribe { y pulsa Enter. Observa si la asignación se mezcla con la entrada incompleta; cancela con Esc.\n",
    readline = "Ahora ejecuta readline('Prueba: '). Observa si el envío se usa como respuesta o queda en cola; cancela con Esc.\n"))
  cat("Registra el comportamiento, no solo el acuse del Job. No habilita permisos de ejecución del addin.\n")
  invisible(list(job = job, script = script, phase = phase))
}
