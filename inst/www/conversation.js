(function () {
  let busy = false;
  let registered = false;
  let connected = false;
  let conversationObserver = null;
  let currentRequestId = null;
  const menus = new Map();
  function setMenuOpen(menu, open) {
    const panel = menus.get(menu);
    if (!panel) return;
    menu.open = open;
    if (open) {
      panel.style.visibility = 'hidden';
      panel.classList.add('is-open');
      positionMenu(menu, panel);
      panel.style.visibility = 'visible';
    } else panel.classList.remove('is-open');
  }
  function syncSidebarButton() {
    const sidebar = document.getElementById('assistant_sidebar');
    const button = document.getElementById('sidebar_toggle');
    if (!sidebar || !button) return;
    const visible = window.getComputedStyle(sidebar).display !== 'none';
    const label = visible ? 'Ocultar panel lateral' : 'Mostrar panel lateral';
    button.title = label;
    button.setAttribute('aria-label', label);
    button.setAttribute('aria-expanded', String(visible));
  }
  function positionMenu(menu, panel) {
    const anchor = menu.querySelector('summary').getBoundingClientRect();
    const header = document.querySelector('.gadget-title');
    const minY = Math.max(8, header ? header.getBoundingClientRect().bottom + 8 : 48);
    const maxY = window.innerHeight - 8;
    const above = Math.max(0, anchor.top - minY - 8);
    const below = Math.max(0, maxY - anchor.bottom - 8);
    const openAbove = above >= below;
    const available = Math.max(40, openAbove ? above : below);
    const viewportWidth = Math.floor(document.documentElement.getBoundingClientRect().width || window.innerWidth);
    panel.style.width = Math.min(228, viewportWidth - 16) + 'px';
    panel.style.maxHeight = Math.min(420, available) + 'px';
    panel.style.left = Math.max(8, Math.min(anchor.left, viewportWidth - panel.getBoundingClientRect().width - 15)) + 'px';
    const height = panel.getBoundingClientRect().height;
    const proposed = openAbove ? anchor.top - height - 4 : anchor.bottom + 4;
    panel.style.top = Math.max(minY, Math.min(proposed, maxY - height)) + 'px';
  }
  function initializeMenus() {
    document.querySelectorAll('.rg-menu').forEach(menu => {
      if (menus.has(menu)) return;
      const panel = menu.querySelector('.rg-menu-panel');
      if (!panel) return;
      menus.set(menu, panel);
      panel.dataset.menuId = menu.id;
      // A permanent closed portal never enters the document flow, including the
      // frame before the native <details> toggle event. Bound inputs stay alive.
      panel.classList.add('rg-menu-portal');
      document.body.appendChild(panel);
      menu.addEventListener('toggle', function () {
        if (menu.open !== panel.classList.contains('is-open')) setMenuOpen(menu, menu.open);
      });
    });
  }
  function repositionMenus() {
    menus.forEach((panel, menu) => { if (menu.open) positionMenu(menu, panel); });
  }
  function feedback(text) {
    const element = document.getElementById('client_feedback');
    if (element) element.textContent = text;
  }
  function syncButton() {
    const button = document.getElementById('send');
    const model = document.getElementById('model');
    if (button) {
      button.disabled = !connected || (!busy && (!model || !model.value));
      button.title = busy ? 'Detener consulta' : 'Enviar (Enter)';
      button.setAttribute('aria-label', busy ? 'Detener consulta' : 'Enviar mensaje');
      button.classList.toggle('is-busy', busy);
      const icon = button.querySelector('i');
      if (icon) icon.className = busy ? 'fa-solid fa-stop' : 'fa-solid fa-arrow-up';
    }
  }
  function showPending(text) {
    const log = document.querySelector('.rg-chat');
    if (!log) return;
    const empty = log.querySelector('.rg-empty');
    if (empty) empty.style.display = 'none';
    const question = document.createElement('div');
    question.className = 'rg-msg rg-user rg-pending';
    const role = document.createElement('div');
    role.className = 'rg-role';
    role.textContent = 'Usuario';
    const content = document.createElement('div');
    content.className = 'rg-text';
    content.textContent = text;
    question.append(role, content);
    const waiting = document.createElement('div');
    waiting.className = 'rg-msg rg-thinking rg-pending';
    waiting.setAttribute('role', 'status');
    const spinner = document.createElement('span');
    spinner.className = 'rg-spinner';
    spinner.setAttribute('aria-hidden', 'true');
    const label = document.createElement('span');
    label.textContent = 'Preparando respuesta...';
    waiting.append(spinner, label);
    log.append(question, waiting);
    log.scrollTop = log.scrollHeight;
  }
  function clearPending() {
    document.querySelectorAll('.rg-pending').forEach(element => element.remove());
    const empty = document.querySelector('.rg-empty');
    if (empty) empty.style.display = '';
  }
  function finish(result) {
    if (result.id && currentRequestId && result.id !== currentRequestId) return;
    busy = false;
    currentRequestId = null;
    syncButton();
    feedback(result.success ? '' : result.cancelled ? 'Consulta cancelada. Tu mensaje se conserva.' : 'La consulta no se completó. Tu mensaje se conserva para reintentar.');
    const field = document.getElementById('request');
    if (field) {
      field.removeAttribute('aria-busy');
      if (!result.success && !field.value) {
        field.value = result.text;
        Shiny.setInputValue('request', result.text, {priority: 'event'});
      }
      field.focus();
    }
    clearPending();
    const proposal = document.querySelector('.rg-proposal');
    if (proposal) proposal.hidden = !result.success;
    const log = document.querySelector('.rg-chat');
    if (log) log.scrollTop = log.scrollHeight;
  }
  function initialize() {
    if (!window.Shiny) return;
    if (!registered) {
      // Register immediately: the connected event may already have happened.
      Shiny.addCustomMessageHandler('rg-request-complete', finish);
      Shiny.addCustomMessageHandler('rg-viewer-restore', function (state) {
        const field = document.getElementById('request');
        if (field) field.value = state.draft || '';
        Shiny.setInputValue('request', state.draft || '', {priority:'event'});
        Shiny.setInputValue('editor_access', state.editor_access, {priority:'event'});
        Shiny.setInputValue('file_access', state.file_access, {priority:'event'});
        // Input updates in the same Shiny frame must settle before restoring interaction.
        setTimeout(function () {
          Shiny.setInputValue('viewer_restored', state.lease, {priority:'event'});
          const log = document.querySelector('.rg-chat');
          if (log) log.scrollTop = log.scrollHeight;
        }, 0);
      });
      Shiny.addCustomMessageHandler('rg-language', function (state) {
        window.rcodeagentUI.setLanguage(state.language);
        repositionMenus();
      });
      Shiny.addCustomMessageHandler('rg-session-state', function (state) {
        const contextButtons = {refresh:'selection', capture_document:'document', project_context:'project'};
        Object.entries(contextButtons).forEach(([id, view]) => {
          const button = document.getElementById(id);
          if (button) button.setAttribute('aria-pressed', state.context_view === view ? 'true' : 'false');
        });
        const modeIcon = document.querySelector('#mode_selector_icon use');
        const modeNames = {normal: 'ask', auto: 'auto'};
        if (modeIcon && Object.prototype.hasOwnProperty.call(modeNames, state.mode)) {
          modeIcon.setAttribute('href', 'rcodeagent-assets/icons-original.svg#c-' + modeNames[state.mode]);
        }
        const toggle = document.getElementById('auto_toggle');
        if (toggle) {
          toggle.setAttribute('aria-pressed', state.auto ? 'true' : 'false');
          toggle.setAttribute('aria-label', state.auto ? 'Desactivar Auto mode' : 'Activar Auto mode');
          toggle.title = state.auto ? 'Auto ON: ediciones directas en el destino elegido' : 'Auto OFF: ediciones con aprobación';
        }
        const login = document.getElementById('connect');
        const otherAccount = document.getElementById('connect_other');
        const logout = document.getElementById('disconnect');
        if (login) login.hidden = state.connected;
        if (otherAccount) otherAccount.hidden = state.connected;
        if (logout) logout.hidden = !state.connected;
        document.querySelectorAll('.rg-export-options a').forEach(link => {
          link.classList.toggle('disabled', !state.export_ready);
          link.setAttribute('aria-disabled', String(!state.export_ready));
        });
      });
      Shiny.addCustomMessageHandler('rg-conversation-reset', function (message) {
        busy = false;
        currentRequestId = null;
        clearPending();
        const field = document.getElementById('request');
        if (field) { field.value = ''; Shiny.setInputValue('request', '', {priority:'event'}); }
        feedback('');
        syncButton();
      });
      registered = true;
    }
    const socket = Shiny.shinyapp && Shiny.shinyapp.$socket;
    connected = !!socket && socket.readyState === 1;
    syncButton();
    initializeMenus();
    syncSidebarButton();
    const chat = document.getElementById('chat');
    if (chat && !conversationObserver) {
      conversationObserver = new MutationObserver(function () {
        const log = document.querySelector('.rg-chat');
        if (log && !busy) log.scrollTop = log.querySelector('.rg-msg') ? log.scrollHeight : 0;
      });
      conversationObserver.observe(chat, {childList:true, subtree:true});
    }
  }
  function submit() {
    const field = document.getElementById('request');
    if (busy || !field || !field.value.trim() || !window.Shiny) return;
    initialize();
    const model = document.getElementById('model');
    if (!connected || !model || !model.value) {
      feedback('Inicia sesión o actualiza los modelos antes de enviar.');
      return;
    }
    busy = true;
    currentRequestId = Date.now().toString() + '-' + Math.random().toString(36).slice(2);
    const proposal = document.querySelector('.rg-proposal');
    if (proposal) proposal.hidden = true;
    syncButton();
    const text = field.value;
    feedback('');
    showPending(text);
    field.value = '';
    field.setAttribute('aria-busy', 'true');
    try {
      Shiny.setInputValue('request', '', {priority: 'event'});
      Shiny.setInputValue('submit_request', {text: text, id:currentRequestId}, {priority: 'event'});
    } catch (error) {
      finish({success:false, text:text});
    }
  }
  document.addEventListener('keydown', function (event) {
    if (event.target.id === 'request' && event.key === 'Enter' && !event.shiftKey &&
        !event.ctrlKey && !event.altKey && !event.metaKey && !event.isComposing && event.keyCode !== 229) {
      event.preventDefault();
      if (!event.repeat) submit();
    }
  });
  document.addEventListener('click', function (event) {
    if (event.target.closest('#send')) {
      if (busy) Shiny.setInputValue('cancel_request', currentRequestId, {priority:'event'});
      else submit();
    }
    if (event.target.closest('.rg-upload-trigger')) document.getElementById('context_files').click();
    if (event.target.closest('#auto_toggle')) {
      Shiny.setInputValue('auto_requested', document.getElementById('auto_toggle').getAttribute('aria-pressed') !== 'true', {priority:'event'});
    }
    if (event.target.closest('#sidebar_toggle')) {
      const workspace = document.querySelector('.rg-workspace');
      const visible = window.getComputedStyle(document.getElementById('assistant_sidebar')).display !== 'none';
      workspace.classList.toggle('sidebar-hidden', visible);
      workspace.classList.toggle('sidebar-visible', !visible);
      syncSidebarButton();
    }
    if (event.target.closest('#context_toggle')) {
      const board = document.querySelector('.rg-context-board');
      board.hidden = !board.hidden;
    }
    if (event.target.closest('#project_context')) document.querySelector('.rg-context-board').hidden = false;
    const suggestion = event.target.closest('[data-suggestion]');
    if (suggestion) {
      const field = document.getElementById('request');
      field.value = suggestion.dataset.suggestion;
      Shiny.setInputValue('request', field.value, {priority:'event'});
      field.focus();
    }
    const remove = event.target.closest('[data-remove-file]');
    const execute = event.target.closest('[data-execute-id]');
    if (execute) Shiny.setInputValue('confirm_execution', execute.dataset.executeId, {priority:'event'});
    if (remove) Shiny.setInputValue('remove_context_file', Number(remove.dataset.removeFile), {priority:'event'});
    const chat = event.target.closest('[data-chat-id]');
    if (chat) Shiny.setInputValue('open_conversation', chat.dataset.chatId, {priority:'event'});
    const deletion = event.target.closest('[data-delete-chat]');
    if (deletion) Shiny.setInputValue('delete_conversation', deletion.dataset.deleteChat, {priority:'event'});
    const panel = event.target.closest('.rg-menu-panel');
    const current = panel ? document.getElementById(panel.dataset.menuId) : event.target.closest('.rg-menu');
    if (event.target.closest('.rg-menu > summary') && current) {
      event.preventDefault();
      setMenuOpen(current, !current.open);
    }
    document.querySelectorAll('.rg-menu[open]').forEach(menu => {
      if (menu !== current) setMenuOpen(menu, false);
    });
  });
  document.addEventListener('keydown', function (event) {
    if (event.key === 'Escape') document.querySelectorAll('.rg-menu[open]').forEach(menu => {
      setMenuOpen(menu, false); menu.querySelector('summary').focus();
    });
  });
  window.jQuery(document).on('shiny:connected', initialize);
  window.jQuery(document).on('change', '#model', syncButton);
  window.jQuery(document).on('change', '#ui_language', function (event) {
    // Shiny's initial/updateSelectInput synchronization must not overwrite a saved choice.
    if (event.originalEvent) Shiny.setInputValue('ui_language_choice', event.target.value, {priority:'event'});
  });
  window.jQuery(document).on('shiny:inputchanged', function (event) {
    if (event.name === 'model') syncButton();
    if (event.name === 'mode') {
      const menu = document.getElementById('mode_menu');
      if (menu) setMenuOpen(menu, false);
    }
  });
  window.jQuery(document).on('shiny:disconnected', function () {
    connected = false;
    busy = false;
    const pending = document.querySelector('.rg-pending .rg-text');
    const field = document.getElementById('request');
    if (pending && field && !field.value) field.value = pending.textContent;
    clearPending();
    syncButton();
    feedback('La conexión local se interrumpió. Vuelve a rcodeagent desde Addins.');
  });
  document.addEventListener('DOMContentLoaded', initialize);
  window.addEventListener('resize', function () { repositionMenus(); syncSidebarButton(); });
  document.addEventListener('scroll', repositionMenus, true);
  initialize();
})();
