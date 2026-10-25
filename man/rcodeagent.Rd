\name{rcodeagent}
\alias{rcodeagent}
\alias{rcodeagent_login}
\alias{rcodeagent_status}
\title{Open the rcodeagent Gadget or Inspect Local Authentication Status}
\usage{
rcodeagent()
rcodeagent_login()
rcodeagent_status()
}
\description{
Starts the RStudio coding assistant in a native Background Job,
displays it in the Viewer, and returns control to the R console.
The status function inspects saved local credentials without returning tokens.
}
\details{
The gadget and login alias require an interactive RStudio Desktop session.
Authentication requires a web browser, Internet access, and an available
operating system credential store. Model requests require Internet access and
an eligible ChatGPT Plus or Pro account under the service's current terms;
see \url{https://developers.openai.com/siwc/quickstart}.
Signing in alone does not grant permission to use models. Available models,
limits, and service availability depend on the authorized account and provider.
Normal generates and revises code only in chat. Auto permits edits to the
selected target and submits code to the main R console only on explicit request.
Explicitly requested ordinary code and package installation do not require a
second confirmation. Classified administrative operations require an exact
preview and one-use confirmation; RStudio may queue submissions.
Stopping the chat does not withdraw submitted code. Saving remains manual.
The background process does not import or export the user's global environment.
Editor operations use RStudio's native interprocess API with a restricted
client which waits for request completion and never resends a write.
A busy main R session may delay these operations or cause a timeout.
An uncertain operation disables further channel access and revokes Auto;
inspect the target and restart the assistant before trying again.
Reopening reuses the live job. When other output replaces the Viewer page, the
job retains its recoverable chat state in memory for 30 minutes. Reopen the addin
to restore the conversation, attachments, model, effort, draft and editing target.
Auto retains its previous state only in this temporary return to the same job,
after revalidating the saved document ID, path and full contents. Conflicts or
an unavailable target revoke Auto. Permissions are never saved in chat history.
In-flight requests are cancelled on disconnect and their draft can be resubmitted;
no editor writes occur while the page is absent. Explicit Close stops the server
and pending workers. A Viewer which never connects stops the job after 60 seconds.
Connect using the gadget's login button. The available models and permissions
depend on the authorized account. No API key or Codex CLI is required.
Auto edits only the selected target. Administrative calls in function defaults
are included in the additional review. Changes are not saved to disk automatically.
Console output is not automatically collected or shared with the model.
Closing the gadget does not remove saved OAuth credentials.
Local status is not a connectivity test.
}
\value{
\code{rcodeagent()} and \code{rcodeagent_login()} invisibly return the native job ID.
\code{rcodeagent_status()} returns a character string describing local status.
}
\examples{
if (interactive() && rstudioapi::isAvailable()) {
  rcodeagent()
  rcodeagent_status()
  # The login alias reopens the same live assistant job.
  rcodeagent_login()
}
}
