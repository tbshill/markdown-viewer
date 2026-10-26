(function () {
  'use strict';

  var MAX_HIGHLIGHT_BYTES = 200 * 1024;

  function ready(fn) {
    if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', fn);
    else fn();
  }

  function langOf(codeEl) {
    var cls = codeEl.className || '';
    var m = /(?:^|\s)language-([^\s]+)/.exec(cls);
    return m ? m[1].toLowerCase() : null;
  }

  // GitHub-style heading ids so [text](#heading) links work.
  function assignHeadingIds(root) {
    var seen = Object.create(null);
    var heads = root.querySelectorAll('h1,h2,h3,h4,h5,h6');
    for (var i = 0; i < heads.length; i++) {
      var h = heads[i];
      if (h.id) continue;
      var slug = (h.textContent || '').trim().toLowerCase()
        .replace(/[^\p{L}\p{N}\p{M}\s_-]/gu, '')
        .replace(/\s/g, '-');
      if (!slug) slug = 'section';
      var n = seen[slug];
      if (n === undefined) { seen[slug] = 0; }
      else { n += 1; seen[slug] = n; slug = slug + '-' + n; }
      h.id = slug;
    }
  }

  function installAnchorHandler() {
    document.addEventListener('click', function (ev) {
      if (ev.defaultPrevented || ev.button !== 0) return;
      var a = ev.target && ev.target.closest ? ev.target.closest('a[href]') : null;
      if (!a) return;
      var href = a.getAttribute('href');
      if (!href || href.charAt(0) !== '#') return;
      ev.preventDefault();
      var id = href.slice(1);
      try { id = decodeURIComponent(id); } catch (e) {}
      var target = id ? document.getElementById(id) : null;
      if (target) target.scrollIntoView();
      else if (!id) window.scrollTo(0, 0);
    }, true);
  }

  // ---- Mermaid -----------------------------------------------------------
  function setupMermaid() {
    var blocks = document.querySelectorAll('pre > code.language-mermaid');
    if (!blocks.length) return;

    var hasMermaid = typeof window.mermaid !== 'undefined';
    if (hasMermaid) {
      var dark = window.matchMedia && window.matchMedia('(prefers-color-scheme: dark)').matches;
      try {
        window.mermaid.initialize({
          startOnLoad: false,
          theme: dark ? 'dark' : 'default',
          securityLevel: 'strict'
        });
      } catch (e) { hasMermaid = false; }
    }

    var nodes = [];
    for (var i = 0; i < blocks.length; i++) {
      var code = blocks[i];
      var pre = code.parentNode;
      var div = document.createElement('div');
      div.className = 'mermaid';
      var src = code.textContent || '';
      div.textContent = src;
      div._src = src;
      pre.parentNode.replaceChild(div, pre);
      nodes.push(div);
    }
    if (!hasMermaid) return;

    var chain = Promise.resolve();
    function renderOne(el) {
      chain = chain.then(function () {
        if (el._done) return;
        el._done = true;
        return window.mermaid.run({ nodes: [el], suppressErrors: false }).catch(function (err) {
          showMermaidError(el, err);
        });
      });
    }

    function showMermaidError(el, err) {
      el.removeAttribute('data-processed');
      el.className = 'mermaid mermaid-error';
      el.textContent = '';
      var note = document.createElement('div');
      note.className = 'note';
      var msg = err && err.message ? err.message : String(err || 'unknown error');
      note.textContent = 'Mermaid diagram could not be rendered: ' + msg.split('\n')[0];
      var pre = document.createElement('pre');
      var c = document.createElement('code');
      c.textContent = el._src || '';
      pre.appendChild(c);
      el.appendChild(note);
      el.appendChild(pre);
      // mermaid may leave a stray error container in <body>
      var stray = document.querySelectorAll('body > div[id^="dmermaid"], body > svg[id^="mermaid"]');
      for (var k = 0; k < stray.length; k++) stray[k].remove();
    }

    if ('IntersectionObserver' in window) {
      var io = new IntersectionObserver(function (entries) {
        for (var j = 0; j < entries.length; j++) {
          if (entries[j].isIntersecting) {
            io.unobserve(entries[j].target);
            renderOne(entries[j].target);
          }
        }
      }, { rootMargin: '800px 0px' });
      nodes.forEach(function (n) { io.observe(n); });
    } else {
      nodes.forEach(renderOne);
    }
  }

  // ---- Syntax highlighting ----------------------------------------------
  function setupHighlight() {
    if (typeof window.hljs === 'undefined') return;
    var hljs = window.hljs;
    try { hljs.configure({ ignoreUnescapedHTML: true }); } catch (e) {}

    var codes = document.querySelectorAll('pre > code[class*="language-"]');
    if (!codes.length) return;

    var queue = [];
    var scheduled = false;

    function highlight(el) {
      if (el.dataset.hl) return;
      el.dataset.hl = '1';
      var lang = langOf(el);
      if (!lang || lang === 'mermaid' || lang === 'text' || lang === 'plain' || lang === 'plaintext') return;
      if (!hljs.getLanguage(lang)) return;            // no auto-detection: too slow
      if ((el.textContent || '').length > MAX_HIGHLIGHT_BYTES) return;
      try { hljs.highlightElement(el); } catch (e) {}
    }

    function drain() {
      scheduled = false;
      var start = performance.now();
      while (queue.length && performance.now() - start < 10) highlight(queue.shift());
      if (queue.length) schedule();
    }
    function schedule() {
      if (scheduled) return;
      scheduled = true;
      requestAnimationFrame(drain);
    }

    if ('IntersectionObserver' in window) {
      var io = new IntersectionObserver(function (entries) {
        for (var i = 0; i < entries.length; i++) {
          if (entries[i].isIntersecting) {
            io.unobserve(entries[i].target);
            queue.push(entries[i].target);
          }
        }
        if (queue.length) schedule();
      }, { rootMargin: '1000px 0px' });
      for (var i = 0; i < codes.length; i++) {
        if (langOf(codes[i]) !== 'mermaid') io.observe(codes[i]);
      }
    } else {
      for (var j = 0; j < codes.length; j++) queue.push(codes[j]);
      schedule();
    }
  }

  window.__restoreScroll = function (y) {
    window.scrollTo(0, Number(y) || 0);
  };

  ready(function () {
    var root = document.querySelector('.markdown-body') || document.body;
    assignHeadingIds(root);
    installAnchorHandler();
    setupMermaid();   // must run before highlight so mermaid blocks are gone
    setupHighlight();
  });
})();
