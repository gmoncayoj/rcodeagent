(function () {
  const config = JSON.parse(document.getElementById('rg-language-data').textContent);
  const dictionary = config.dictionary;
  const reverse = Object.fromEntries(Object.entries(dictionary).map(([es, en]) => [en, es]));
  const originals = new WeakMap();
  let language = config.language;
  let pending = false;
  const prefixes = {
    'Destino: ': 'Target: ', 'Contexto: ': 'Context: ', 'Consumo de sesión: ': 'Session usage: ',
    'Confirmar modificación de ': 'Confirm changes to ', 'Eliminar ': 'Delete ', 'Quitar ': 'Remove ',
    'Conectado: ': 'Connected: '
  };
  function translate(value) {
    const whitespace = value.match(/^(\s*)([\s\S]*?)(\s*)$/);
    const text = whitespace[2];
    let source = Object.prototype.hasOwnProperty.call(dictionary, text) ? text : reverse[text] || text;
    let result = language === 'en' ? dictionary[source] || source : source;
    for (const [es, en] of Object.entries(prefixes)) {
      if (source.startsWith(es)) result = (language === 'en' ? en : es) + source.slice(es.length);
      else if (source.startsWith(en)) result = (language === 'en' ? en : es) + source.slice(en.length);
    }
    if (/^·\s+/.test(source)) result = '· ' + translate(source.replace(/^·\s+/, ''));
    if (/^(Contexto:|Context:) /.test(source)) {
      result = language === 'en' ? result.replace(/\bdocumento\b/g, 'document').replace(/\bselección\b/g, 'selection').replace(/\bcaracteres\b/g, 'characters') : result;
    }
    return whitespace[1] + result + whitespace[3];
  }
  function permitted(element) {
    if (!element || element.closest('script,style,textarea,input,pre,code,.rg-text,.rg-markdown,[data-chat-id],#model_label,#account_name,.rg-file-chip')) return false;
    return !element.closest('.rg-msg') || !!element.closest('.rg-role,.rg-thinking,.rg-app-note');
  }
  function apply() {
    pending = false;
    if (!document.body) return;
    document.documentElement.lang = language;
    const walker = document.createTreeWalker(document.body, NodeFilter.SHOW_TEXT);
    let node;
    while ((node = walker.nextNode())) {
      if (!permitted(node.parentElement)) continue;
      let record = originals.get(node);
      if (!record || node.nodeValue !== record.output) record = {source: node.nodeValue};
      record.output = translate(record.source);
      if (node.nodeValue !== record.output) node.nodeValue = record.output;
      originals.set(node, record);
    }
    document.querySelectorAll('[title],[aria-label],[placeholder],[data-suggestion]').forEach(element => {
      if (element.closest('.rg-text,.rg-markdown,pre,code,[data-chat-id]')) return;
      let record = originals.get(element) || {};
      for (const name of ['title', 'aria-label', 'placeholder', 'data-suggestion']) {
        if (!element.hasAttribute(name)) continue;
        const current = element.getAttribute(name);
        if (!record[name] || current !== record[name].output) record[name] = {source: current};
        record[name].output = translate(record[name].source);
        if (current !== record[name].output) element.setAttribute(name, record[name].output);
      }
      originals.set(element, record);
    });
  }
  function schedule() {
    if (!pending) { pending = true; queueMicrotask(apply); }
  }
  window.rcodeagentUI = {
    translate,
    setLanguage(value) { if (['es', 'en'].includes(value)) { language = value; apply(); } }
  };
  document.addEventListener('DOMContentLoaded', function () {
    apply();
    new MutationObserver(schedule).observe(document.body, {childList: true, subtree: true, characterData: true,
      attributes: true, attributeFilter: ['title', 'aria-label', 'placeholder', 'data-suggestion']});
  });
})();
