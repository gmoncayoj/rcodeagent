# Manual de uso

rcodeagent 0.1.0 | Paquete R 0.1.0

José Gamarra-Moncayo

Asistencia para programación, análisis e investigación dentro de RStudio.

Este manual acompaña la distribución local 0.1.0. La interfaz del chat se ejecuta en Viewer; el navegador se usa para el inicio de sesión OAuth. No requiere Codex CLI ni API key. No sustituye la revisión metodológica ni la validación del código.

Ruta de lectura: 1 Instalación · 2 Cuenta e interfaz · 3 Contexto y permisos · 4 Edición y ejecución · 5 Análisis y APA · 6 Continuidad y exportación · 7 Problemas frecuentes · 8 Privacidad y referencias.

Inicio rápido: instala el paquete, abre Addins > rcodeagent, inicia sesión, elige un modelo, captura el contexto y empieza en Normal. Autoriza Auto únicamente cuando desees cambios directos en el destino señalado.

Contacto del mantenedor: gamarramoncayoj@gmail.com

Licencia del proyecto: GPL (>= 3), versión 3 o posterior de GNU GPL. Texto completo en LICENSE.md.

## 1. Instalación y primera apertura

### Requisitos

- R 4.2.0 o posterior y RStudio Desktop. Las comprobaciones nativas disponibles corresponden a Windows; no se garantiza el mismo comportamiento en todas las plataformas.
- Internet para instalar dependencias e iniciar sesión/consultar. El funcionamiento requiere acceso efectivo de la cuenta al servicio y a modelos compatibles.
- Una ubicación de usuario donde R pueda instalar paquetes y conservar preferencias, historial y credenciales cifradas.

### Instalar la distribución

Cierra el addin y usa Session > Restart R si reemplazas una versión anterior. En la consola ejecuta:

```r
install.packages("remotes") # solo la primera vez
remotes::install_local(file.choose(), upgrade = "never")
# En el selector, elige rcodeagent_0.1.0.tar.gz
rcodeagent::rcodeagent()
```

remotes resuelve las dependencias declaradas. Si trabajas con la carpeta fuente descargada, abre esa carpeta como directorio de trabajo y sustituye file.choose() por ".". Si una dependencia necesita compilarse, sigue los requisitos de compilación que indique R para tu sistema.

### Comprobar y abrir

```r
packageVersion("rcodeagent") # debe indicar 0.1.0
rcodeagent::rcodeagent()
```

También puedes usar Addins > rcodeagent. En Tools > Modify Keyboard Shortcuts busca rcodeagent y asigna una combinación disponible. La función debe iniciarse desde RStudio; Rscript o una consola externa no ofrecen el contexto del editor.

La distribución está preparada para GitHub, pero este manual no presupone que exista una publicación remota. No uses una dirección de repositorio inventada ni install.packages("rcodeagent") como si estuviera disponible en CRAN.

Si usabas el paquete anterior, ciérralo y reinicia R. Instala y comprueba rcodeagent antes de retirar el anterior desde Packages, evitando dos entradas en Addins. No elimines sus datos de usuario: cuando no existe un perfil nuevo, se reutiliza el anterior para conservar historial, idioma e identidad/credencial OAuth. Si ambos perfiles existen, se elige el nuevo y no se mezclan; no hay copia automática de secretos.

## 2. Cuenta, modelo e interfaz

### Conectar la cuenta

Las consultas a modelos requieren una suscripción ChatGPT Plus o Pro elegible según la guía de Sign in with ChatGPT de OpenAI. rcodeagent no admite cuentas Free para usar modelos. Iniciar sesión por sí solo no concede permiso de inferencia.

Pulsa Iniciar sesión con ChatGPT en el panel lateral. Completa la autorización en el navegador del sistema y vuelve a RStudio. El retorno utiliza una dirección local de loopback. El panel cambia a Conectado cuando puede recuperar el catálogo autorizado; una credencial guardada no demuestra por sí sola que exista conectividad.

Después de desconectar, usa Iniciar sesión con ChatGPT para reconectar la última cuenta o Usar otra cuenta para registrar una diferente sin las pistas de identidad anteriores. Desconectar el complemento no cierra la sesión de ChatGPT en el navegador; comprueba la identidad que muestra OpenAI antes de autorizar. El aviso de inicio de sesión cancelado se cierra a los cinco segundos.

No pegues tokens ni claves en el chat. El servicio determina los modelos disponibles. Desconectar intenta revocar la sesión en OpenAI y retira los tokens locales. Si no confirma la revocación remota, lo indica: desconecta también la app desde la configuración de ChatGPT. Cerrar termina el complemento y conserva la credencial. Una renovación inválida exige iniciar sesión de nuevo; un fallo temporal de red conserva la sesión cifrada.

### Reconocer los controles

- Parte superior: nueva conversación, historial, mostrar/ocultar panel lateral y Cerrar.
- Conversación: mensajes, respuesta, estado de espera y propuesta de código cuando corresponda.
- Contexto: Selección actual, Archivo activo y Proyecto completo, más las fichas de adjuntos.
- Compositor: clip para adjuntar, mensaje, Auto, menú de modo, modelo/esfuerzo y envío o Detener.
- Panel lateral: cuenta, destino de edición, exportación, About, idioma y estado/consumo.

### Elegir modelo y esfuerzo

Abre el nombre del modelo junto al envío. Elige Modelo y Esfuerzo: Bajo, Medio, Alto o Muy alto; Medio es el inicial. Actualizar modelos consulta el catálogo de la cuenta. Un esfuerzo no admitido produce un error; no se rebaja silenciosamente. La latencia y los resultados dependen del modelo y del servicio.

Enter envía y Shift+Enter inserta una línea. Detener termina la consulta pendiente e invalida resultados tardíos. Si falla una consulta se recupera el borrador cuando no sobrescribe texto nuevo.

El inglés es el idioma predeterminado de la interfaz. Idioma permite cambiar entre inglés y español, y conserva la elección guardada al volver a abrir el complemento. No traduce tus mensajes ni obliga al modelo a responder en ese idioma. Indica el idioma deseado en tu solicitud. About muestra el autor y la versión del paquete instalado.

## 3. Compartir contexto y elegir permisos

### Destino y adjuntos son cosas diferentes

Selección actual captura el rango elegido en el editor. Archivo activo captura el documento y vuelve a consultar la pestaña activa al enviar: si cambió, se revoca Auto. Elegir script .R fija un destino por su ID. Una selección capturada también queda fijada hasta que la cambies; no sigue al cursor automáticamente.

Un documento nuevo vacío y sin guardar es un destino válido por su ID; aparece como Documento sin guardar [ID]. No se presume el nombre Untitled ni se detecta su lenguaje a partir de esa etiqueta. Para Auto, los documentos guardados deben ser scripts .R. Comprueba siempre la etiqueta del destino antes de editar.

Los adjuntos se usan como lectura, no conceden autorización de escritura. Se admiten .R, .md, .qmd y .Rmd en UTF-8: hasta 512 KB por archivo, 2 MB y 12 archivos en total. Proyecto completo muestra los adjuntos compartidos; no explora el proyecto ni accede a todos sus archivos. Las bases CSV, Excel o SPSS no son adjuntos admitidos en esta versión.

### Modos

- Normal: lee el contexto autorizado, explica, planifica y genera o modifica código únicamente en el chat. Puedes pedir sucesivas revisiones y copiar el resultado. Si pides implementarlo o ejecutarlo en RStudio, indicará que actives Auto o lo hagas manualmente.
- Auto: activación explícita desde el escudo o el menú. Edita únicamente el destino elegido según tu petición. Editar no implica ejecutar: solo se envía código a la consola cuando lo pides expresamente.

Auto comienza apagado en un Job nuevo, chat nuevo o retomado del historial. Elegir explícitamente otra selección, archivo activo o script R conserva Auto y cancela la consulta anterior; Proyecto completo y los adjuntos no cambian el destino de edición. Una captura fallida, un destino incompatible, un conflicto no recapturado o un fallo de IPC revocan Auto. Antes de cada efecto se comprueban ID, ruta y contenido completo. Un documento R vacío sin guardar sigue siendo válido.

En Auto, una orden explícita de ejecución se envía sin otra revisión ni confirmación, también para código nuevo. «Ejecuta» usa el contexto capturado; «Instala el paquete lavaan» envía install.packages("lavaan") sin editar el script ni cargarlo automáticamente. Consultas, citas, negaciones y órdenes condicionadas no conceden ejecución. Borrar archivos, comandos del sistema y otras operaciones administrativas identificadas requieren revisar el código exacto y pulsar Ejecutar este código; esa confirmación vale una sola vez. Cada autorización vale para una sola solicitud y no se recupera desde el historial ni al volver a Viewer.

RStudio puede dejar el código enviado en cola hasta quedar libre. Stop del chat cancela consultas o preparaciones pendientes; no retira código ya enviado. Usa los controles de la consola para una ejecución en curso. El addin bloquea el envío si detecta texto pendiente en la entrada de consola; esta comprobación no certifica que R esté libre ni elimina carreras con cambios posteriores.

La ejecución tiene los permisos de tu sesión R y puede modificar objetos y archivos; no es un entorno aislado. No hay instalación implícita de paquetes ni lectura automática del Environment o de resultados hacia el modelo. El guardado sigue siendo manual. La sintaxis válida no garantiza seguridad ni corrección estadística.

## 4. Ejemplos: conversar, editar y ejecutar

### A. Revisar código dentro del chat

Abre un script sintético, captura el contexto y deja Normal:

```r
puntajes <- c(12, 15, NA, 18, 20)
promedio <- mean(puntajes)
```

Pide: «Explica por qué promedio devuelve NA y dame una versión corregida». Después: «Agrega el número de observaciones válidas a tu propuesta». Las dos respuestas permanecen en el chat y el script no cambia. Puedes copiar el código o activar Auto para aplicarlo.

### B. Editar sin ejecutar

Comprueba el destino, activa Auto y pide: «Modifica el cálculo para omitir los valores perdidos y agrega el número de observaciones válidas. Conserva el resto». Un resultado razonable es:

```r
puntajes <- c(12, 15, NA, 18, 20)
promedio <- mean(puntajes, na.rm = TRUE)
n_validos <- sum(!is.na(puntajes))
```

Auto escribe en el destino, sin ejecutar ni guardar. Inspecciona el cambio. Para volver al trabajo solo en chat, selecciona Normal o apaga el escudo.

### C. Cargar una librería o ejecutar un rango

Con Auto y un destino elegido, «Carga la librería lavaan» añade library(lavaan) si no existe como llamada independiente y envía esa llamada a la consola principal. El paquete debe estar instalado. «Escribe library(lavaan) en el script» solo escribe; «Ejecuta library(lavaan), sin agregarlo al script» solo ejecuta.

«Ejecuta la línea 32», «Ejecuta las líneas 32 a 40» o «Ejecuta la selección» usan el destino capturado. La numeración comienza en 1 sobre el documento completo. Una línea vacía, fuera de rango o parte de una expresión multilínea incompleta se rechaza; el addin no amplía el rango silenciosamente.

«Corrige este bloque y ejecútalo» edita el destino, verifica el resultado y envía el bloque sin una segunda confirmación. Después del envío, consulta Console, Plots o Viewer: el acuse no demuestra que el cálculo terminó correctamente. No hay reejecución automática de errores. En el ejemplo, verifica promedio = 16.25 y n_validos = 4.

## 5. Ejemplos: planificación y tabla APA

### Planificar un análisis antes de programarlo

En Normal: «Diseña un plan para comparar dos mediciones pareadas. Distingue calidad de datos, supuestos, análisis principal, tamaño del efecto, intervalo de confianza y reporte. No presupongas resultados». Comparte el diseño, la escala y la estructura de datos necesarios. El addin no conoce automáticamente tus objetos ni puede confirmar que un supuesto se cumpla sin evidencia.

### Ejemplo reproducible con datos sintéticos

Copia el código de la respuesta en Normal o pide a Auto que lo inserte en el destino elegido:

```r
pre  <- c(10, 12, 11, 13,  9, 14)
post <- c(12, 13, 11, 15, 10, 16)
pares <- complete.cases(pre, post)
dif <- post[pares] - pre[pares]
resultado <- t.test(post[pares], pre[pares], paired = TRUE)
resumen <- data.frame(
  n = sum(pares),
  media_pre = mean(pre[pares]),
  media_post = mean(post[pares]),
  diferencia = mean(dif)
)
```

Mensaje sugerido: «Prepara código para una tabla con formato APA 7 a partir de este ejemplo. Incluye n, medias, desviaciones estándar, diferencia post menos pre, t, grados de libertad, p e intervalo de confianza. Explica el criterio de pares completos y las dependencias. No inventes resultados ni referencias».

El modelo puede proponer flextable u otra dependencia: revisa e instala lo necesario de forma explícita. Ejecuta el script manualmente o solicita a Auto un rango concreto. Si necesitas que el asistente interprete resultados, comparte una salida pertinente y anonimizada mediante texto o un archivo admitido; no puede leer resultado desde el Environment.

Revisa dirección de la diferencia, denominadores, redondeo, etiquetas, intervalo, notas, cursivas y ausencia de líneas verticales. Esta petición ilustra un flujo de trabajo; no certifica conformidad APA ni validez inferencial. Cuando print(tabla_apa) sustituya el chat en Viewer, sigue el procedimiento de la página siguiente.

## 6. Recuperación, historial y exportación

### Una tabla reemplazó el chat

1. Conserva R y el Background Job en ejecución. Viewer seguirá mostrando la tabla mientras la consultes.
2. Dentro de los 30 minutos desde la última desconexión, abre Addins > rcodeagent o usa tu atajo. No reinicies el Job desde Background Jobs.
3. El mismo Job recupera conversación hasta el último mensaje, adjuntos, modelo, esfuerzo, borrador sincronizado, propuesta y destino, y vuelve al final del chat.
4. Auto regresa ON u OFF según estaba si el documento supera la validación de ID, ruta y contenido completo. Un conflicto o imposibilidad de verificarlo revoca Auto y muestra un aviso. El rango de selección anterior se conserva.

Una autorización de ejecución pendiente nunca se recupera ni se repite. El código ya enviado puede seguir ejecutándose o en cola en RStudio; volver al chat o cerrar el addin no lo retira.

El Viewer alterna entre tabla y chat. Si había una consulta pendiente, se cancela; su instrucción vuelve como borrador si no existe otro más reciente. No se reenvía ni escribe desconectado. El texto todavía no sincronizado con el servidor no puede garantizarse. Cerrar termina el complemento inmediatamente. Reiniciar R, vencer la espera o iniciar un Job nuevo pierde la recuperación temporal.

### Historial local

La conversación y sus adjuntos se guardan localmente. Nueva conversación inicia un chat separado. Historial permite retomar o eliminar conversaciones. Al retomar desde Historial, vuelve a elegir destino y autoriza Auto solo si lo deseas: los permisos no se guardan. Eliminar o exportar un chat no equivale a cerrar sesión en la cuenta.

### Exportar y entender los contadores

En el panel lateral, Exportar ofrece HTML, JSON, Markdown y PDF cuando existen mensajes. Selecciona el formato y destino local. Revisa el contenido antes de compartirlo. No se exportan credenciales ni concesiones Auto; el texto de la conversación puede contener información que tú hayas incluido. Los adjuntos permanecen en el historial; el exportador toma los campos validados que corresponden a cada formato.

El contador junto al compositor informa uso/máximo de contexto. El símbolo ≈ indica estimación; ? significa límite desconocido. Cuando existe usage del proveedor se conserva por separado. El consumo acumulado no es una factura ni representa necesariamente el límite o saldo de tu suscripción.

## 7. Resolver problemas frecuentes

### El Addin no aparece o muestra otra versión

Reinicia RStudio después de instalar y comprueba packageVersion("rcodeagent") y About. Revisa .libPaths() si existen instalaciones en varias bibliotecas. Instala la distribución correcta; no extraigas una versión antigua sobre los fuentes actuales.

### No hay modelos o no conecta

Usa Actualizar modelos. Si persiste, Desconectar e Iniciar sesión con ChatGPT renuevan la autorización por el flujo interactivo. Comprueba internet, permisos de la cuenta y restricciones de proxy/firewall. No abras el servidor a la red ni publiques tokens para diagnosticar. rcodeagent_status() solo informa estado local; no es una prueba de conectividad.

### Auto se apagó o la edición fue rechazada

Confirma el destino y recaptura el contexto tras revisar el documento. Elegir explícitamente selección o archivo conserva Auto si el destino es válido; un cambio no recapturado, fallo de captura o conflicto puede revocarlo. Si aparece un error IPC, inspecciona el documento y cierra/reabre el complemento para iniciar un Job nuevo; no fuerces escrituras con un canal incierto. Una consola ocupada puede demorar las operaciones del editor.

### La tabla ocupó Viewer y el chat no vuelve

Abre el Addin dentro del plazo. Si pulsaste Cerrar, reiniciaste R o pasaron más de 30 minutos, se inicia un Job nuevo; usa Historial para los mensajes guardados y recaptura el destino. No se recupera Auto desde disco.

### Archivo rechazado, error de modelo o respuesta interrumpida

Comprueba extensión, UTF-8 y límites de adjuntos. Reduce el contexto si supera el límite del modelo. Prueba un esfuerzo admitido explícitamente si el proveedor lo rechaza; la aplicación no lo reduce sola. Ante un error, revisa el borrador y reenvíalo conscientemente. Para reportar un problema, comparte versión de R/RStudio/paquete, pasos, estado de Auto y un ejemplo sintético, sin datos personales.

## 8. Privacidad, límites y fuentes

### Qué compartes

Al enviar una consulta, el servicio recibe la instrucción, historial de contexto, captura del editor y adjuntos habilitados. Los historiales locales contienen mensajes y contenido adjunto. No utilices datos identificables de participantes, pacientes o estudiantes sin la base de autorización y las medidas de protección que correspondan a tu institución. Prefiere ejemplos sintéticos o datos anonimizados.

Las credenciales OAuth se cifran en el almacenamiento local; la clave de cifrado se conserva en el almacén de credenciales del sistema. El chat no necesita conocer los tokens. La red local de loopback no constituye protección frente a otros programas ejecutados con tu mismo usuario. Exportaciones e historiales requieren las precauciones habituales de tus archivos de investigación.

### Alcance de esta entrega

La versión 0.1.0 es la numeración vigente de esta distribución. Conserva la implementación documentada en el historial de validación; la renumeración no constituye una nueva validación nativa. Las pruebas sintéticas de navegador y las unitarias no sustituyen OAuth, inferencia, renovación ni compatibilidad nativa en cada equipo. La satisfacción del usuario no se interpreta como una certificación de todos esos recorridos. No hay inspección automática del Environment ni acceso general a carpetas. La ejecución solo se solicita explícitamente en Auto; sus efectos ocurren en la sesión R principal y pueden quedar en cola. Los modelos pueden producir errores de programación, estadística y citación.

### Documentación de apoyo

- Posit. RStudio Addins: https://docs.posit.co/ide/user/ide/guide/productivity/add-ins.html
- Posit. Send code to the R console: https://rstudio.github.io/rstudioapi/reference/sendToConsole.html
- r-lib. Install a package from a local file: https://remotes.r-lib.org/reference/install_local.html
- OpenAI. Registration and sign-in: https://developers.openai.com/siwc/token-sharing-open-source/sign-in

Fuentes oficiales consultadas para los mecanismos de Addins, instalación local y OAuth. El comportamiento particular de rcodeagent se documenta a partir de las fuentes 0.1.0. Las rutas y menús pueden variar entre versiones del IDE. Consulta README.md y SECURITY.md para el estado técnico vigente; docs/validation/1.0.0.md conserva evidencia histórica de la numeración anterior.

Autor y mantenedor: José Gamarra-Moncayo · gamarramoncayoj@gmail.com
